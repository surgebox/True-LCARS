#!/usr/bin/env bash
# audio.sh - the audio backend behind the volume widget.
#
#   audio.sh status          -> "40 0"          volume% + mute flag (0/1)
#   audio.sh set <0-150>     -> set volume
#   audio.sh toggle-mute     -> flip mute
#   audio.sh sinks           -> one line per output: "default|index|label"
#   audio.sh default <index> -> make that output the default
#
# Everything goes through pactl (PipeWire's PulseAudio compatibility layer),
# whose output is far easier to parse than wpctl's ASCII trees.
#
# While muted `status` still reports the real stored volume, and the widget
# draws at zero. Muting that also zeroes the volume would mean unmuting gives
# you silence, which is not what anyone wants from a mute button.

set -u

pactl_bin=$(command -v pactl) || {
    echo "audio.sh: pactl not found" >&2
    exit 1
}

# Longest prefix shared by every argument - so a list of outputs all reporting
# "Cannon Point-LP High Definition Audio Controller ..." can drop the boilerplate
# and leave only the part that tells them apart.
common_prefix() {
    local prefix=$1 s
    shift
    for s in "$@"; do
        while [[ ${s:0:${#prefix}} != "$prefix" ]]; do
            prefix=${prefix:0:${#prefix}-1}
            [[ -z $prefix ]] && return 0
        done
    done
    printf '%s' "$prefix"
}

case "${1:-status}" in
    status)
        vol=$("$pactl_bin" get-sink-volume @DEFAULT_SINK@ 2>/dev/null |
            awk -F'/' '/Volume:/{gsub(/ /, "", $2); gsub(/%/, "", $2); print $2; exit}')
        mute=$("$pactl_bin" get-sink-mute @DEFAULT_SINK@ 2>/dev/null |
            awk '{print ($2 == "yes") ? 1 : 0; exit}')
        printf '%s %s\n' "${vol:-0}" "${mute:-0}"
        ;;

    set)
        target=${2:-0}
        ((target < 0)) && target=0
        ((target > 150)) && target=150
        "$pactl_bin" set-sink-volume @DEFAULT_SINK@ "${target}%" >/dev/null 2>&1
        ;;

    toggle-mute)
        "$pactl_bin" set-sink-mute @DEFAULT_SINK@ toggle >/dev/null 2>&1
        ;;

    sinks)
        default=$("$pactl_bin" get-default-sink 2>/dev/null)

        # collect index, name and description for every sink
        mapfile -t raw < <("$pactl_bin" list sinks 2>/dev/null | awk '
            /^Sink #/            { idx = $2; sub(/#/, "", idx) }
            /^[ \t]+Name: /      { name = $2 }
            /^[ \t]+Description: / {
                desc = $0
                sub(/^[ \t]+Description: /, "", desc)
                print idx "|" name "|" desc
            }
        ')

        [[ ${#raw[@]} -eq 0 ]] && exit 0

        # strip whatever boilerplate every description shares
        labels=()
        for entry in "${raw[@]}"; do
            labels+=("${entry##*|}")
        done
        prefix=$(common_prefix "${labels[@]}")
        shortest=${labels[0]}
        for l in "${labels[@]}"; do
            ((${#l} < ${#shortest})) && shortest=$l
        done
        # never strip a description bare - if the prefix is the whole string, the
        # sinks are identical anyway and an empty menu helps nobody
        ((${#prefix} >= ${#shortest})) && prefix=""

        for entry in "${raw[@]}"; do
            idx=${entry%%|*}
            rest=${entry#*|}
            name=${rest%%|*}
            label=${rest#*|}
            if [[ -n $prefix ]]; then
                label=${label:${#prefix}}
                label=${label# }
                label=${label#-}
                label=${label# }
            fi
            [[ -z $label ]] && label=$name
            if [[ $name == "$default" ]]; then
                printf '1|%s|%s\n' "$idx" "$label"
            else
                printf '0|%s|%s\n' "$idx" "$label"
            fi
        done
        ;;

    default)
        idx=${2:-}
        [[ -z $idx ]] && exit 1
        name=$("$pactl_bin" list short sinks 2>/dev/null | awk -v i="$idx" '$1 == i {print $2; exit}')
        [[ -z $name ]] && exit 1
        "$pactl_bin" set-default-sink "$name" >/dev/null 2>&1
        ;;

    *)
        echo "audio.sh: unknown command '$1'" >&2
        exit 1
        ;;
esac
