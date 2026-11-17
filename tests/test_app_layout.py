import importlib.util
import pathlib
import unittest
from unittest.mock import patch


SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "scripts" / "app_layout.py"
spec = importlib.util.spec_from_file_location("app_layout", SCRIPT)
app_layout = importlib.util.module_from_spec(spec)
spec.loader.exec_module(app_layout)


class AppLayoutTests(unittest.TestCase):
    def test_every_tile_stays_inside_app_rectangle(self):
        rect = (300, 200, 1000, 600)
        for count in range(1, 12):
            tiles = app_layout.slots(rect, count)
            self.assertEqual(len(tiles), count)
            for x, y, width, height in tiles:
                self.assertGreaterEqual(x, rect[0])
                self.assertGreaterEqual(y, rect[1])
                self.assertLessEqual(x + width, rect[0] + rect[2])
                self.assertLessEqual(y + height, rect[1] + rect[3])

    def test_selects_panel_monitor_even_when_another_is_focused(self):
        monitors = [
            {"name": "HDMI-A-1", "focused": True, "width": 1920, "height": 1080, "scale": 1},
            {"name": "eDP-1", "focused": False, "width": 2560, "height": 1440, "scale": 1.25},
        ]
        selected = app_layout.monitor_for(monitors, {"monitor": "eDP-1"})
        self.assertEqual(selected["name"], "eDP-1")

    def test_dispatcher_falls_back_to_legacy_hyprland(self):
        sent = []

        def fake_hypr(*args):
            sent.append(args)
            return "ok" if args[-1].startswith("setfloating ") else None

        with patch.object(app_layout, "hypr", fake_hypr):
            dispatcher = app_layout.Dispatcher()
            self.assertTrue(dispatcher.float("0x123", True))
            self.assertEqual(dispatcher.mode, "legacy")
        self.assertIn(("dispatch", "setfloating address:0x123"), sent)


if __name__ == "__main__":
    unittest.main()
