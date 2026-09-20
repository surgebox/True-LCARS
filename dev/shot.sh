#!/usr/bin/env bash
# shot.sh - grab the layout window to a PNG.
#
#   ./dev/shot.sh                          capture shell.qml -> dev/shots/latest.png
#   ./dev/shot.sh demo/elbow.qml out.png   capture something else
#   LCARS_SHOT_NEW=1 ./dev/shot.sh         force a throwaway instance
#
# If a layout window is already running (the usual case while iterating with
# ./run.sh) this reuses it - it does NOT launch a second one, which would knock
# the running window out of fullscreen and fight it for the screen. It only
# launches its own instance when nothing is running, or when LCARS_SHOT_NEW=1,
# and kills only what it started.
#
# The window is fullscreened through the compositor first, so the capture is the
# layout 1:1 rather than a tiled slice of it, and only its own rect is grabbed.
#
# This Hyprland is configured with Lua: dispatchers are Lua calls, and a bare Qt
# fullscreen request just gets tiled back down.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
qml="${1:-$here/shell.qml}"
out="${2:-$here/dev/shots/latest.png}"
log=/tmp/lcars-shot.log

mkdir -p "$(dirname "$out")"

# Match on the process command line, not just the window class: this machine has
# other quickshell configs (~/quickshell-playground, ~/.config/quickshell/bar)
# and grabbing the wrong one is silent and confusing.
qs_addr() {
    hyprctl clients -j | python3 -c "
import json,os,sys
want = '$qml'
base = os.path.basename(want)
try:
    cs = json.load(sys.stdin)
except Exception:
    sys.exit(0)
best = ''
for c in cs:
    if c.get('class','').lower() not in ('org.quickshell','quickshell'):
        continue
    try:
        cmd = open('/proc/%s/cmdline' % c.get('pid'), 'rb').read().decode(errors='replace')
    except Exception:
        continue
    if want in cmd or base in cmd:
        best = c['address']
print(best)
" 2>/dev/null || true
}

fs_state() {
    hyprctl clients -j | python3 -c "
import json,sys
want = '$1'[2:]
for c in json.load(sys.stdin):
    if c['address'][2:] == want:
        print(c.get('fullscreen', 0))
" 2>/dev/null || echo 0
}

qspid=""
cleanup() { if [[ -n $qspid ]]; then kill "$qspid" 2>/dev/null || true; fi; }
trap cleanup EXIT

addr="$(qs_addr)"
if [[ -n $addr && "${LCARS_SHOT_NEW:-0}" != "1" ]]; then
    echo "shot: reusing the running layout window"
else
    qs -p "$qml" >"$log" 2>&1 &
    qspid=$!
    for _ in $(seq 1 60); do
        sleep 0.25
        addr="$(qs_addr)"
        [[ -n $addr ]] && break
    done
fi

if [[ -z $addr ]]; then
    echo "shot: no LCARS window appeared; log follows" >&2
    tail -20 "$log" >&2
    exit 1
fi

# the dispatcher toggles, so asking for fullscreen on an already-fullscreen
# window would take it *out* of fullscreen - check the state first
if [[ "$(fs_state "$addr")" == "0" ]]; then
    hyprctl dispatch "hl.dsp.window.fullscreen({ mode = 'fullscreen', window = 'address:$addr' })" \
        >/dev/null 2>&1 || true
fi

geo=""
for _ in $(seq 1 25); do
    sleep 0.2
    geo=$(hyprctl clients -j | python3 -c "
import json,sys
want = '$addr'[2:]
for c in json.load(sys.stdin):
    if c['address'][2:] == want:
        print('{},{} {}x{}'.format(c['at'][0], c['at'][1], c['size'][0], c['size'][1]))
")
    [[ $geo == "0,0 2048x1152" ]] && break
done

# Quickshell watches the whole config directory, so editing anything in here
# (even this script) can trigger a reload that momentarily reconstruits the
# window. Let it settle before grabbing, or grim catches whatever is behind it.
sleep 0.8

grim -g "$geo" "$out"

# surface QML errors - spotting them is half the point of the loop
if [[ -n $qspid ]] && grep -qiE 'error' "$log"; then
    filtered=$(grep -iE 'error' "$log" | grep -viE 'dconf|portal' || true)
    if [[ -n $filtered ]]; then
        echo "shot: QML ERRORS" >&2
        printf '%s\n' "$filtered" >&2
    fi
fi
echo "shot: $out  ($geo)"
