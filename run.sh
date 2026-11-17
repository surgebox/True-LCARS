#!/usr/bin/env bash
# run.sh - start the layout window.
#
#   ./run.sh              windowed, hot-reloading on every save
#   ./run.sh --desktop    managed desktop with live app windows
#   ./run.sh --fullscreen fullscreen, so proportions can be judged on the real
#                         screen. Ctrl+C quits either way.
#
# Quickshell watches every file that belongs to the config directory, so saving
# any .qml here re-renders the window - no restart needed.
#
# Fullscreen is requested through the compositor, targeted by window address,
# rather than through Qt: this Hyprland is configured with Lua and a plain Qt
# fullscreen request just gets tiled back down.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
want_fullscreen=0
entry="shell.qml"
[[ "${1:-}" == "--fullscreen" ]] && want_fullscreen=1
[[ "${1:-}" == "--desktop" ]] && entry="desktop.qml"

qs -p "$here/$entry" &
pid=$!
trap 'kill "$pid" 2>/dev/null || true' EXIT

if ((want_fullscreen)); then
    for _ in $(seq 1 60); do
        sleep 0.25
        addr=$(hyprctl clients -j | python3 -c "
import json,sys
try:
    cs = json.load(sys.stdin)
except Exception:
    sys.exit(0)
qs = [c for c in cs if c.get('class','').lower() in ('org.quickshell','quickshell')]
print(qs[-1]['address'] if qs else '')
" 2>/dev/null || true)
        if [[ -n $addr ]]; then
            hyprctl dispatch \
                "hl.dsp.window.fullscreen({ mode = 'fullscreen', window = 'address:$addr' })" \
                >/dev/null 2>&1 || true
            break
        fi
    done
fi

printf 'lcars-dev: running %s - Ctrl+C quits\n' "$here/$entry"
wait "$pid"
