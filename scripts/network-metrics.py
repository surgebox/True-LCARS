#!/usr/bin/env python3
"""Stream connection details for the LCARS network panel.

Uses Omarchy's richer probe when available and NetworkManager/sysfs elsewhere.
Runs only while the menu is open. Byte-counter deltas report transfer rates.
"""
import json
from pathlib import Path
import subprocess
import time


def read_details():
    try:
        result = subprocess.run(['omarchy-network-status', '--verbose'],
                                capture_output=True, text=True, timeout=5, check=False)
        if result.returncode == 0:
            return dict(line.split('\t', 1) for line in result.stdout.splitlines() if '\t' in line)
    except (OSError, subprocess.TimeoutExpired):
        pass
    try:
        status = subprocess.run(['nmcli', '-t', '-f', 'DEVICE,TYPE,STATE', 'device', 'status'],
                                capture_output=True, text=True, timeout=5, check=False)
        if status.returncode:
            return {}
        for line in status.stdout.splitlines():
            fields = line.split(':', 2)
            if len(fields) != 3 or fields[1] not in ('wifi', 'ethernet') or not fields[2].startswith('connected'):
                continue
            iface = fields[0]
            base = Path('/sys/class/net') / iface / 'statistics'
            return {'iface': iface,
                    'rx_bytes': (base / 'rx_bytes').read_text().strip(),
                    'tx_bytes': (base / 'tx_bytes').read_text().strip()}
    except (OSError, subprocess.TimeoutExpired):
        pass
    return {}


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
