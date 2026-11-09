#!/usr/bin/env bash
# check.sh - lint the QML without launching anything.
#
#   ./dev/check.sh
#
# Catches what actually bites here: syntax slips and "Cannot override FINAL
# property". The latter is this Qt's reply to re-declaring a property that Item
# or Repeater already injects - `left`, `right`, `index`, `modelData` - and it
# fails the whole config, so a check that does not need a window on screen is
# worth having.
#
# The remaining "unqualified access" warnings are qmllint wanting
# `pragma ComponentBehavior: Bound`; they are not errors and the config loads
# fine with them.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
lint=/usr/lib/qt6/bin/qmllint
[[ -x $lint ]] || { echo "check: no qmllint at $lint" >&2; exit 1; }

cd "$here"
fail=0
for f in shell.qml tracking-test.qml ui/*.qml theme/*.qml feeds/*.qml demo/*.qml; do
    out=$("$lint" "$f" 2>&1 \
        | grep -E '^(Warning|Error|Critical):' \
        | grep -viE 'Unqualified access' || true)
    if [[ -n $out ]]; then
        echo "== $f"
        printf '%s\n' "$out"
        fail=1
    fi
done

if ((fail)); then
    echo "check: problems found"
    exit 1
fi
echo "check: clean"
