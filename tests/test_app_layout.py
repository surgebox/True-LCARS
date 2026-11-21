import importlib.util
import pathlib
import unittest
from unittest.mock import patch


SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "scripts" / "app_layout.py"
spec = importlib.util.spec_from_file_location("app_layout", SCRIPT)
app_layout = importlib.util.module_from_spec(spec)
spec.loader.exec_module(app_layout)


class AppLayoutTests(unittest.TestCase):
    def test_split_tree_fills_three_window_layout(self):
        tree = None
        for address in ("a", "b", "c"):
            tree = app_layout.add_leaf(tree, address)
        tiles = app_layout.tree_slots(tree, (0, 0, 1000, 600))
        self.assertEqual(tiles["a"], (0, 0, 496, 600))
        self.assertEqual(tiles["b"], (504, 0, 496, 296))
        self.assertEqual(tiles["c"], (504, 304, 496, 296))

    def test_center_drop_swaps_and_edge_drop_restructures(self):
        tree = ("h", "a", ("v", "b", "c"))
        swapped = app_layout.drop(tree, "a", "c", "center")
        self.assertEqual(app_layout.tree_slots(swapped, (0, 0, 1000, 600))["a"],
                         (504, 304, 496, 296))
        moved = app_layout.drop(tree, "c", "a", "top")
        self.assertEqual(app_layout.leaves(moved), ["c", "a", "b"])
        self.assertLess(app_layout.tree_slots(moved, (0, 0, 1000, 600))["c"][1],
                        app_layout.tree_slots(moved, (0, 0, 1000, 600))["a"][1])

    def test_removing_window_collapses_its_split(self):
        tree = ("h", "a", ("v", "b", "c"))
        self.assertEqual(app_layout.remove_leaf(tree, "b"), ("h", "a", "c", 0.5))

    def test_native_border_resize_updates_shared_split(self):
        tree = ("h", "a", "b")
        rect = (0, 0, 1000, 600)
        changed = app_layout.learn_border_resize(
            tree, "a", (0, 0, 496, 600), (0, 0, 560, 600),
            {"x": 560, "y": 300}, rect)
        tiles = app_layout.tree_slots(changed, rect)
        self.assertAlmostEqual(tiles["a"][2] + 4, 560, delta=1)
        self.assertEqual(tiles["b"][0], tiles["a"][2] + 8)

    def test_native_resize_requires_cursor_at_shared_edge(self):
        tree = ("h", "a", "b")
        expected = (0, 0, 496, 600)
        actual = (0, 0, 560, 600)
        self.assertEqual(app_layout.learn_border_resize(
            tree, "a", expected, actual, {"x": 300, "y": 300},
            (0, 0, 1000, 600)), tree)
        self.assertEqual(app_layout.learn_border_resize(
            tree, "a", expected, (30, 0, 466, 600),
            {"x": 30, "y": 300}, (0, 0, 1000, 600)), tree)

    def test_native_resize_uses_nearest_nested_split(self):
        tree = ("h", "a", ("h", "b", "c"))
        rect = (0, 0, 1000, 600)
        before = app_layout.tree_slots(tree, rect)
        b = before["b"]
        actual = (b[0], b[1], b[2] + 50, b[3])
        changed = app_layout.learn_border_resize(
            tree, "b", b, actual,
            {"x": actual[0] + actual[2], "y": 300}, rect)
        after = app_layout.tree_slots(changed, rect)
        self.assertEqual(after["a"], before["a"])
        self.assertGreater(after["b"][2], before["b"][2])

    def test_native_drag_uses_target_center_or_nearest_edge(self):
        slots = {"a": (0, 0, 496, 600), "b": (504, 0, 496, 600)}
        self.assertEqual(app_layout.drop_at_cursor(
            slots, "a", {"x": 750, "y": 300}), ("b", "center"))
        self.assertEqual(app_layout.drop_at_cursor(
            slots, "a", {"x": 520, "y": 300}), ("b", "left"))
        self.assertIsNone(app_layout.drop_at_cursor(
            slots, "a", {"x": 200, "y": 300}))

    def test_native_drag_workspace_pill_from_global_cursor(self):
        pills = (500, 200, 500, 50)
        self.assertEqual(app_layout.workspace_at_cursor(
            {"x": 650, "y": 220}, pills), 2)
        self.assertEqual(app_layout.workspace_at_cursor(
            {"x": 999, "y": 220}, pills), 5)
        self.assertEqual(app_layout.workspace_at_cursor(
            {"x": 650, "y": 251}, pills), 0)

    def test_arrange_gap_reserves_space_for_window_frames(self):
        tiles = app_layout.tree_slots(("h", "a", "b"), (0, 0, 1000, 600), 18)
        self.assertEqual(tiles["a"], (0, 0, 491, 600))
        self.assertEqual(tiles["b"], (509, 0, 491, 600))
        self.assertEqual(tiles["b"][0] - (tiles["a"][0] + tiles["a"][2]), 18)

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

    def test_visible_authentication_dialog_on_panel_monitor(self):
        clients = [
            {"class": "polkit-mate-authentication-agent-1", "monitor": 0,
             "mapped": True, "hidden": False},
        ]
        self.assertTrue(app_layout.authentication_open(clients, 0))
        self.assertFalse(app_layout.authentication_open(clients, 1))
        clients[0]["hidden"] = True
        self.assertFalse(app_layout.authentication_open(clients, 0))

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

    def test_move_to_workspace_targets_a_specific_window(self):
        sent = []

        def fake_hypr(*args):
            sent.append(args)
            return "ok" if args[-1].startswith("movetoworkspacesilent ") else None

        with patch.object(app_layout, "hypr", fake_hypr):
            dispatcher = app_layout.Dispatcher()
            self.assertTrue(dispatcher.move_to_workspace("0x123", 4))
        self.assertIn(("dispatch", "movetoworkspacesilent 4,address:0x123"), sent)


if __name__ == "__main__":
    unittest.main()
