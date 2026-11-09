#!/usr/bin/env bash
# stats.sh - one line of live stats per second, for the header capsules.
#
#     cpu%  memUsedKB  memTotalKB  netname  netKB/s  dskUsedKB  dskTotalKB  vol%  mute
#
# `netname` is the wifi SSID when the default route is wireless (that is the
# network you are actually on), and the interface name otherwise. Spaces in an
# SSID become underscores so the line stays space-separated.
#
# Sizes are raw KiB so the shell decides the units; only the CPU percentage and
# the network rate arrive pre-computed, because both need a previous sample to
# diff against.
#
# Everything comes straight out of /proc, /sys and df, so there is nothing to
# install and no polling daemon: this script *is* the poller, and the shell reads
# its stdout a line at a time through a Quickshell SplitParser.
#
# Run it by hand to check the numbers:
#     ./scripts/stats.sh
#
# The very first line reports 0 for CPU and NET, since neither can be known
# without a prior sample. That is one line, one second.

interval=1

# Quickshell carries a Process across config reloads on purpose, so this child is
# not restarted when the shell reloads - and bash has already read this whole
# loop into memory. Watch our own file and re-exec when it changes, so editing
# the poller takes effect within a second without restarting the shell.
self=$(readlink -f "${BASH_SOURCE[0]}")
self_stamp=$(stat -c %Y "$self" 2>/dev/null)

prev_total=0
prev_idle=0
prev_net=0
cpu=0
rate=0

while :; do
    stamp=$(stat -c %Y "$self" 2>/dev/null)
    if [[ -n $stamp && $stamp != "$self_stamp" ]]; then
        exec "$self"
    fi

    # ---- CPU: /proc/stat delta; idle + iowait count as not-busy -----------
    if read -r _ u n s i w irq sirq steal _ _ < /proc/stat; then
        total=$((u + n + s + i + w + irq + sirq + steal))
        idle=$((i + w))
        if ((prev_total > 0)); then
            dt=$((total - prev_total))
            di=$((idle - prev_idle))
            ((dt > 0)) && cpu=$((100 * (dt - di) / dt))
        fi
        prev_total=$total
        prev_idle=$idle
    fi

    # ---- MEM: total, and total minus what the kernel says is available -----
    memtotal=0
    memavail=0
    while read -r key val _; do
        case $key in
            MemTotal:) memtotal=$val ;;
            MemAvailable:) memavail=$val ;;
        esac
    done < /proc/meminfo
    memused=$((memtotal - memavail))

    # ---- NET: the interface carrying the default route, and its rate -------
    iface=$(ip -o route show default 2>/dev/null | awk '{print $5; exit}')
    if [[ -z $iface ]]; then
        # no default route - fall back to the first real interface we find
        for dir in /sys/class/net/*; do
            candidate=$(basename "$dir")
            [[ $candidate == lo ]] && continue
            iface=$candidate
            break
        done
    fi

    # Report the network by name rather than by device: "5g-net" means
    # something to a person, "wlan0" does not. Only wifi has an SSID, so
    # anything else keeps its interface name.
    netname=$iface
    if [[ -n $iface ]] && command -v iw >/dev/null 2>&1; then
        ssid=$(iw dev "$iface" link 2>/dev/null | awk -F': ' '/SSID:/{print $2; exit}')
        [[ -n $ssid ]] && netname=${ssid// /_}
    fi

    # /sys/class/net/*/statistics is one number per file, which beats parsing
    # /proc/net/dev: that file's leading whitespace makes awk's first field
    # empty and silently shifts every byte offset by one.
    if [[ -n $iface && -r /sys/class/net/$iface/statistics/rx_bytes ]]; then
        rx=$(<"/sys/class/net/$iface/statistics/rx_bytes")
        tx=$(<"/sys/class/net/$iface/statistics/tx_bytes")
        net=$((rx + tx))
        if ((prev_net > 0)); then
            rate=$(((net - prev_net) / interval / 1024))
            ((rate < 0)) && rate=0
        fi
        prev_net=$net
    else
        netname=""
        rate=0
        prev_net=0
    fi

    # ---- AUDIO: one wpctl call yields both the level and the mute flag -----
    read -r vol mute < <(
        wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null |
            awk '{ v = $2; m = 0 } /MUTED/ { m = 1 } END { printf "%d %d", v * 100, m }'
    )
    : "${vol:=0}"
    : "${mute:=0}"

    # ---- DSK: the root filesystem -----------------------------------------
    read -r dskused dsktotal < <(df -Pk / 2>/dev/null | awk 'NR==2{print $3+0, $2+0}')
    : "${dskused:=0}"
    : "${dsktotal:=0}"

    printf '%s %s %s %s %s %s %s %s %s\n' \
        "$cpu" "$memused" "$memtotal" "$netname" "$rate" "$dskused" "$dsktotal" \
        "$vol" "$mute"
    sleep "$interval"
done
