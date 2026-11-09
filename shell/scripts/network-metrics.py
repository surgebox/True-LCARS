#!/usr/bin/env python3
"""Stream the same connection details as Omarchy's network panel.

Runs only while the menu is open. Byte-counter deltas report actual transfer
rates; link speed is the negotiated physical rate. Ping uses Omarchy's probe.
"""
import json
import subprocess
import time


def read_details():
    try:
        result = subprocess.run(['omarchy-network-status', '--verbose'],
                                capture_output=True, text=True, timeout=5, check=False)
        if result.returncode:
            return {}
        return dict(line.split('\t', 1) for line in result.stdout.splitlines() if '\t' in line)
    except (OSError, subprocess.TimeoutExpired):
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
