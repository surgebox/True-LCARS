#!/usr/bin/env python3
"""NetworkManager bridge. JSON lines on stdin/stdout; never invoke a shell.

Uses nmcli's escaped terse format. Passwords arrive on stdin and go to nmcli
through a private, short-lived passwd-file, never through argv or logs.
Reference: https://networkmanager.dev/docs/api/latest/nmcli.html
"""
import json
import os
import subprocess
import sys
import tempfile
import uuid


class NetworkError(Exception):
    pass


def nm(*args, timeout=40):
    result = subprocess.run(['nmcli', '--colors', 'no', '--wait', '30', *args],
                            capture_output=True, text=True, timeout=timeout,
                            env={**os.environ, 'LC_ALL': 'C'})
    if result.returncode:
        raise NetworkError(result.stderr.strip() or 'NetworkManager could not complete the request.')
    return result.stdout.strip()


def fields(line):
    result, value, escaped = [], '', False
    for char in line:
        if escaped:
            value += char
            escaped = False
        elif char == '\\':
            escaped = True
        elif char == ':':
            result.append(value)
            value = ''
        else:
            value += char
    result.append(value)
    return result


def rows(columns, *args):
    return [fields(line) for line in nm('-t', '-f', columns, *args).splitlines() if line]


def profiles():
    saved = {}
    for uid, kind in rows('UUID,TYPE', 'connection', 'show'):
        if kind != '802-11-wireless':
            continue
        ssid = nm('-g', '802-11-wireless.ssid', 'connection', 'show', 'uuid', uid)
        # -g still escapes colons and backslashes.
        ssid = fields(ssid)[0]
        saved.setdefault(ssid, uid)
    return saved


def snapshot(scan=False):
    devices = [{'iface': i, 'type': t, 'state': s, 'name': n}
               for i, t, s, n in rows('DEVICE,TYPE,STATE,CONNECTION', 'device', 'status')
               if t in ('wifi', 'ethernet')]
    radio = nm('radio', 'wifi') == 'enabled'
    saved = profiles()
    networks = {}
    if radio and any(d['type'] == 'wifi' for d in devices):
        for active, ssid, bssid, signal, security, iface in rows(
                'IN-USE,SSID,BSSID,SIGNAL,SECURITY,DEVICE', 'device', 'wifi', 'list',
                '--rescan', 'yes' if scan else 'no'):
            if not ssid:
                continue
            item = {'active': active == '*', 'ssid': ssid, 'bssid': bssid,
                    'signal': int(signal), 'security': security, 'iface': iface,
                    'uuid': saved.get(ssid, ''), 'secured': security not in ('', '--'),
                    'enterprise': '802.1X' in security or 'EAP' in security}
            key = (ssid, security)
            old = networks.get(key)
            if old is None or (item['active'], item['signal']) > (old['active'], old['signal']):
                networks[key] = item
    return {'radio': radio, 'devices': devices,
            'connectivity': nm('networking', 'connectivity'),
            'networks': sorted(networks.values(), key=lambda n: (not n['active'], -n['signal'], n['ssid']))}


def connect(request):
    # Re-read AP identity instead of trusting data sent from an old menu row.
    network = next((n for n in snapshot()['networks'] if n['bssid'] == request.get('bssid')
                    and n['iface'] == request.get('iface')), None)
    if network is None:
        raise NetworkError('This network is no longer visible. Scan and select it again.')
    if network['active']:
        return
    password = request.get('password', '')
    if not isinstance(password, str) or '\n' in password or '\r' in password or '\0' in password:
        raise NetworkError('The password contains unsupported characters.')
    uid = network['uuid']
    created = False
    if not uid:
        if network['enterprise']:
            raise NetworkError('Configure this enterprise network in system network settings first.')
        if network['secured'] and not password:
            raise NetworkError('Enter the Wi-Fi password.')
        if network['secured'] and not any(s in network['security'] for s in ('WPA', 'WEP')):
            raise NetworkError('Configure this security type in system network settings first.')
        if 'WEP' in network['security']:
            raise NetworkError('Configure this legacy network in system network settings first.')
        uid = str(uuid.uuid4())
        args = ['connection', 'add', 'type', 'wifi', 'ifname', network['iface'],
                'con-name', network['ssid'], 'ssid', network['ssid'], 'connection.uuid', uid]
        if network['secured']:
            key = 'sae' if 'WPA3' in network['security'] and 'WPA2' not in network['security'] else 'wpa-psk'
            args += ['wifi-sec.key-mgmt', key]
        nm(*args)
        created = True
    try:
        with tempfile.TemporaryDirectory(prefix='lcars-network-') as directory:
            args = ['connection', 'up', 'uuid', uid, 'ifname', network['iface'], 'ap', network['bssid']]
            if password:
                path = os.path.join(directory, 'password')
                fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
                with os.fdopen(fd, 'w') as file:
                    file.write('802-11-wireless-security.psk:' + password + '\n')
                args += ['passwd-file', path]
            nm(*args)
    except Exception:
        if created:
            try:
                nm('connection', 'delete', 'uuid', uid)
            except (NetworkError, subprocess.TimeoutExpired):
                pass
        raise


def handle(request):
    op = request.get('op', 'status')
    if op == 'connect':
        connect(request)
    elif op == 'radio':
        nm('radio', 'wifi', 'on' if request.get('enabled') else 'off')
    elif op == 'disconnect':
        iface = request.get('iface')
        if iface not in [d['iface'] for d in snapshot()['devices']]:
            raise NetworkError('That interface is no longer available.')
        nm('device', 'disconnect', iface)
    elif op not in ('status', 'scan'):
        raise NetworkError('Unknown network action.')
    return snapshot(scan=op == 'scan')


def main():
    for line in sys.stdin:
        request = {}
        try:
            request = json.loads(line)
            data = handle(request)
            result = {'ok': True, 'op': request.get('op'), 'data': data}
        except (NetworkError, OSError, ValueError, subprocess.TimeoutExpired) as error:
            # A command failure must not echo a user-supplied credential.
            message = str(error)
            secret = request.get('password')
            if secret:
                message = message.replace(secret, '[redacted]')
            result = {'ok': False, 'op': request.get('op'), 'error': message}
        print(json.dumps(result), flush=True)


if __name__ == '__main__':
    main()
