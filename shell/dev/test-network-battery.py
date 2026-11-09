#!/usr/bin/env python3
"""Exercise hardware edge cases and connection/password handling without D-Bus."""
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


def module(name):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).resolve().parents[1] / 'scripts' / (name + '.py'))
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


network = module('network')
battery = module('battery')
metrics = module('network-metrics')


class BatteryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)

    def supply(self, name, **values):
        path = self.base / name
        path.mkdir()
        for key, value in values.items():
            (path / key).write_text(str(value))

    def test_absent_and_peripheral_batteries(self):
        self.supply('mouse', type='Battery', scope='Device', capacity=40)
        self.supply('BAT0', type='Battery', present=0, capacity=50)
        self.assertFalse(battery.read_battery(self.base)['present'])

    def test_charging_and_capacity_clamp(self):
        self.supply('BAT0', type='Battery', capacity=130, status='Charging')
        result = battery.read_battery(self.base)
        self.assertEqual(result['percent'], 100)
        self.assertEqual(result['status'], 'CHARGING')
        self.assertTrue(result['plugged'])

    def test_plugged_at_charge_limit(self):
        self.supply('AC', type='Mains', online=1)
        self.supply('BAT0', type='Battery', capacity=80, status='Not charging')
        self.assertEqual(battery.read_battery(self.base)['status'], 'ON AC')

    def test_discharge_and_invalid_reading(self):
        self.supply('BAT0', type='Battery', capacity=14, status='Discharging')
        self.supply('BAT1', type='Battery', capacity='unknown')
        result = battery.read_battery(self.base)
        self.assertEqual(result['percent'], 14)
        self.assertFalse(result['plugged'])


class NetworkTests(unittest.TestCase):
    def setUp(self):
        self.ap = {'bssid': 'AA:BB:CC:DD:EE:FF', 'ssid': 'Bridge: Wi-Fi \\ 01',
                   'iface': 'wlan0', 'uuid': '', 'active': False,
                   'secured': True, 'enterprise': False, 'security': 'WPA2'}

    def test_escaped_terse_fields(self):
        self.assertEqual(network.fields(r'*:Bridge\: Wi-Fi \\ 01:AA\:BB:80:WPA2:wlan0'),
                         ['*', 'Bridge: Wi-Fi \\ 01', 'AA:BB', '80', 'WPA2', 'wlan0'])

    def test_secret_stays_out_of_argv_and_is_cleaned(self):
        secret = 'private " value $()'
        seen_files = []
        def nm(*args, **kwargs):
            self.assertNotIn(secret, args)
            if 'passwd-file' in args:
                path = Path(args[args.index('passwd-file') + 1])
                self.assertEqual(path.stat().st_mode & 0o777, 0o600)
                self.assertEqual(path.read_text(), '802-11-wireless-security.psk:' + secret + '\n')
                seen_files.append(path)
            return ''
        with patch.object(network, 'snapshot', return_value={'networks': [self.ap]}), patch.object(network, 'nm', side_effect=nm):
            network.connect({**self.ap, 'password': secret})
        self.assertEqual(len(seen_files), 1)
        self.assertFalse(seen_files[0].exists())

    def test_failed_new_profile_is_removed(self):
        def nm(*args, **kwargs):
            if args[:2] == ('connection', 'up'):
                raise network.NetworkError('Wrong password')
            return ''
        with patch.object(network, 'snapshot', return_value={'networks': [self.ap]}), patch.object(network, 'nm', side_effect=nm) as call:
            with self.assertRaises(network.NetworkError):
                network.connect({**self.ap, 'password': 'badpassword'})
        self.assertTrue(any(c.args[:2] == ('connection', 'delete') for c in call.call_args_list))

    def test_existing_profile_is_never_deleted_on_failure(self):
        self.ap['uuid'] = 'saved'
        with patch.object(network, 'snapshot', return_value={'networks': [self.ap]}), patch.object(network, 'nm', side_effect=network.NetworkError('Unavailable')) as call:
            with self.assertRaises(network.NetworkError):
                network.connect(self.ap)
        self.assertEqual(len(call.call_args_list), 1)
        self.assertEqual(call.call_args.args[:4], ('connection', 'up', 'uuid', 'saved'))

    def test_stale_and_enterprise_networks_do_not_create_profiles(self):
        self.ap['enterprise'] = True
        with patch.object(network, 'snapshot', return_value={'networks': [self.ap]}), patch.object(network, 'nm') as call:
            with self.assertRaises(network.NetworkError):
                network.connect(self.ap)
            with self.assertRaises(network.NetworkError):
                network.connect({**self.ap, 'bssid': 'vanished'})
            call.assert_not_called()

    def test_duplicate_access_points_prefer_connected(self):
        def nm(*args, **kwargs):
            if args[:3] == ('-t', '-f', 'DEVICE,TYPE,STATE,CONNECTION'):
                return 'wlan0:wifi:connected:Bridge'
            if args == ('radio', 'wifi'):
                return 'enabled'
            if args[:3] == ('-t', '-f', 'IN-USE,SSID,BSSID,SIGNAL,SECURITY,DEVICE'):
                return '*:Bridge:AA\\:BB:40:WPA2:wlan0\n:Bridge:CC\\:DD:95:WPA2:wlan0'
            return 'full'
        with patch.object(network, 'profiles', return_value={'Bridge': 'saved'}), patch.object(network, 'nm', side_effect=nm):
            result = network.snapshot()
        self.assertEqual(len(result['networks']), 1)
        self.assertEqual(result['networks'][0]['bssid'], 'AA:BB')
        self.assertTrue(result['networks'][0]['active'])


class MetricsTests(unittest.TestCase):
    def test_rates_use_elapsed_time_and_distinct_counters(self):
        first = {'iface': 'wlan0', 'rx_bytes': '1000', 'tx_bytes': '2000'}
        result, previous = metrics.sample(first, now=10)
        self.assertIsNone(result['downloadBps'])
        result, _ = metrics.sample({'iface': 'wlan0', 'rx_bytes': '5000', 'tx_bytes': '3000'}, previous, now=12)
        self.assertEqual(result['downloadBps'], 2000)
        self.assertEqual(result['uploadBps'], 500)

    def test_changed_interface_reset_and_disconnect_do_not_report_spikes(self):
        previous = (10, {'iface': 'wlan0', 'rx_bytes': '10000', 'tx_bytes': '10000'})
        for details in [{}, {'iface': 'eth0', 'rx_bytes': '50000', 'tx_bytes': '40000'},
                        {'iface': 'wlan0', 'rx_bytes': '10', 'tx_bytes': '20'}]:
            result, _ = metrics.sample(details, previous, now=12)
            self.assertIsNone(result['downloadBps'])
            self.assertIsNone(result['uploadBps'])

    def test_helper_unavailable_degrades_to_unknown(self):
        with patch.object(metrics.subprocess, 'run', side_effect=FileNotFoundError):
            self.assertEqual(metrics.read_details(), {})


if __name__ == '__main__':
    unittest.main()
