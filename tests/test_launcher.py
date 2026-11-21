"""Focused checks for LAUNCH history and package removal decisions."""

import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/launcher.py"
spec = importlib.util.spec_from_file_location("lcars_launcher", SCRIPT)
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)


class App:
    def __init__(self, app_id, flatpak=None, filename=None):
        self.app_id = app_id
        self.flatpak = flatpak
        self.filename = filename

    def get_id(self):
        return self.app_id

    def get_display_name(self):
        return "Example App"

    def get_name(self):
        return "Example App"

    def get_string(self, key):
        return self.flatpak if key == "X-Flatpak" else None

    def get_filename(self):
        return self.filename

    def launch(self, _files, _context):
        return True


class LauncherTests(unittest.TestCase):
    def test_flatpak_uninstall_uses_installed_scope(self):
        app = App("org.example.App.desktop", "org.example.App")
        for scope, prefix in (("system", ["sudo", "flatpak"]),
                              ("user", ["flatpak"])):
            result = subprocess.CompletedProcess([], 0, f"org.example.App\t{scope}\n", "")
            with self.subTest(scope=scope), mock.patch.object(launcher, "run", return_value=result):
                target = launcher.uninstall_target(app)
                self.assertEqual(target["command"],
                                 prefix + ["uninstall", "--" + scope, "org.example.App"])

    def test_rpm_uninstall_names_owning_package(self):
        app = App("example.desktop", filename="/usr/share/applications/example.desktop")
        result = subprocess.CompletedProcess([], 0, "example-package\n", "")
        with mock.patch.object(launcher, "run", return_value=result):
            target = launcher.uninstall_target(app)
        self.assertEqual(target["package"], "example-package")
        self.assertEqual(target["command"], ["sudo", "dnf5", "remove", "example-package"])

    def test_confirmation_token_is_single_use(self):
        app = App("org.example.App.desktop", "org.example.App")
        result = subprocess.CompletedProcess([], 0, "org.example.App\tsystem\n", "")
        messages = []
        with mock.patch.object(launcher, "app_info", return_value=app), \
             mock.patch.object(launcher, "run", return_value=result), \
             mock.patch.object(launcher, "emit", side_effect=messages.append), \
             mock.patch.object(launcher, "start_package_process") as start:
            launcher.prepare_uninstall(app.get_id())
            token = messages[-1]["token"]
            launcher.confirm_uninstall(token)
            launcher.confirm_uninstall(token)
        start.assert_called_once()
        self.assertIn("expired", messages[-1]["error"].lower())

    def test_launch_and_pin_are_persisted(self):
        app = App("org.example.App.desktop")
        messages = []
        with tempfile.TemporaryDirectory() as directory, \
             mock.patch.object(launcher, "STATE_FILE", Path(directory) / "launcher.json"), \
             mock.patch.object(launcher, "state", {"pinned": [], "recent": {}}), \
             mock.patch.object(launcher, "app_info", return_value=app), \
             mock.patch.object(launcher, "installed_apps", return_value=[]), \
             mock.patch.object(launcher, "emit", side_effect=messages.append):
            launcher.handle({"op": "toggle_pin", "id": app.get_id()})
            launcher.handle({"op": "launch", "id": app.get_id()})
            saved = json.loads(launcher.STATE_FILE.read_text())
        self.assertEqual(saved["pinned"], [app.get_id()])
        self.assertGreater(saved["recent"][app.get_id()], 0)
        self.assertFalse(any(message.get("error") for message in messages))


if __name__ == "__main__":
    unittest.main()
