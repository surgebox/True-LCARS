#!/usr/bin/env python3
"""Stream connection details for the LCARS network panel.

Uses NetworkManager for connection state and Linux for link statistics.
Byte-counter deltas report transfer rates.
"""
import json
import os
from pathlib import Path
import re
import subprocess
import time

from network import NetworkError, fields, nm


def probe(*args):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=2,
                                env={**os.environ, 'LC_ALL': 'C'})
        if result.returncode == 0:
            return result.stdout
    except (OSError, subprocess.TimeoutExpired):
        pass
    return ''


def read_details():
    try:
        status = nm('-t', '-f', 'DEVICE,TYPE,STATE', 'device', 'status', timeout=2)
        device = next(((iface, kind) for iface, kind, state in map(fields, status.splitlines())
                       if kind in ('wifi', 'ethernet') and state.startswith('connected')), None)
    except (OSError, NetworkError, subprocess.TimeoutExpired):
        return {}
    if device is None:
        return {}
    iface, kind = device
    base = Path('/sys/class/net') / iface
    details = {'iface': iface}
    for counter in ('rx_bytes', 'tx_bytes'):
        try:
            details[counter] = (base / 'statistics' / counter).read_text().strip()
        except OSError:
            continue

    try:
        config = nm('-t', '-f', 'IP4.ADDRESS,IP4.GATEWAY', 'device', 'show', iface, timeout=2)
        values = dict(map(fields, config.splitlines()))
        ip, _, prefix = values.get('IP4.ADDRESS[1]', '').partition('/')
        gateway = values.get('IP4.GATEWAY', '')
        details.update(ip=ip, prefix=prefix, gateway=gateway)
        if gateway and gateway != '--':
            ping = probe('ping', '-n', '-c', '1', '-W', '1', '-I', iface, gateway)
            latency = re.search(r'\btime[=<]([\d.]+) ms', ping)
            if latency:
                details['gateway_ping_ms'] = latency.group(1)
    except (OSError, NetworkError, subprocess.TimeoutExpired):
        pass

    if kind == 'wifi':
        link = probe('iw', 'dev', iface, 'link')
        frequency = re.search(r'^\s*freq: (\d+)', link, re.MULTILINE)
        bitrate = re.search(r'^\s*tx bitrate: ([\d.]+ MBit/s)', link, re.MULTILINE)
        if frequency:
            details['freq'] = frequency.group(1)
        if bitrate:
            details['bitrate'] = bitrate.group(1)
    else:
        try:
            speed = int((base / 'speed').read_text())
            if speed > 0:
                details['speed'] = speed
        except (OSError, ValueError):
            pass
    return details


def sample(details, previous=None, now=None):
    now = time.monotonic() if now is None else now
    result = dict(details)
    result.update(downloadBps=None, uploadBps=None)
    if previous and details.get('iface') and details.get('iface') == previous[1].get('iface'):
        elapsed = now - previous[0]
        if elapsed > 0:
            for key, output in [('rx_bytes', 'downloadBps'), ('tx_bytes', 'uploadBps')]:
                try:
                    delta = int(details[key]) - int(previous[1][key])
                    if delta >= 0:
                        result[output] = delta / elapsed
                except (KeyError, TypeError, ValueError):
                    pass
    return result, (now, details)


def main():
    previous = None
    while True:
        started = time.monotonic()
        data, previous = sample(read_details(), previous)
        print(json.dumps(data), flush=True)
        time.sleep(max(0.2, 2 - (time.monotonic() - started)))


if __name__ == '__main__':
    main()
