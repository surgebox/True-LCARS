#!/usr/bin/env python3
"""Read laptop batteries (not peripheral batteries) without a desktop daemon."""
import json
from pathlib import Path
import sys
import time


def read_battery(base=Path('/sys/class/power_supply')):
    def read(path, default=''):
        try:
            return path.read_text().strip()
        except OSError:
            return default
    batteries = []
    online = False
    for supply in base.iterdir():
        kind = read(supply / 'type')
        if kind != 'Battery':
            online |= read(supply / 'online') == '1'
            continue
        if read(supply / 'scope') == 'Device' or read(supply / 'present', '1') == '0':
            continue
        try:
            capacity = max(0, min(100, int(read(supply / 'capacity'))))
        except ValueError:
            continue
        batteries.append((capacity, read(supply / 'status')))
    if not batteries:
        return {'present': False, 'percent': 0, 'status': 'NO BATTERY', 'plugged': online}
    states = [b[1] for b in batteries]
    status = ('CHARGING' if 'Charging' in states else 'DISCHARGING' if 'Discharging' in states
              else 'FULL' if all(s == 'Full' for s in states) else 'ON AC' if online else 'IDLE')
    return {'present': True, 'percent': round(sum(b[0] for b in batteries) / len(batteries)),
            'status': status, 'plugged': online or status in ('CHARGING', 'FULL')}


if __name__ == '__main__':
    while True:
        try:
            print(json.dumps(read_battery()), flush=True)
        except OSError:
            print(json.dumps({'present': False, 'percent': 0, 'status': 'UNAVAILABLE', 'plugged': False}), flush=True)
        if '--once' in sys.argv:
            break
        time.sleep(5)
