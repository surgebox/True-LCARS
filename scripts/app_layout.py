#!/usr/bin/env python3
"""Fit windows on the LCARS monitor into the live APP rectangle.

The shell sends one JSON rectangle per line. This process owns only windows on
the monitor's visible workspace and restores their prior state on exit.
"""

import json
import os
import shlex
import select
import signal
import subprocess
import sys
import time

UNMANAGED_CLASSES = {"polkit-mate-authentication-agent-1"}


def hypr(*args):
    try:
        result = subprocess.run(
            ["hyprctl", *args], capture_output=True, text=True, timeout=2
        )
        return result.stdout.strip() if result.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired):
        return None


def query(name):
    try:
        return json.loads(hypr("-j", name) or "null")
    except json.JSONDecodeError:
        return None


class Dispatcher:
    def __init__(self):
        self.mode = None

    def send(self, lua, legacy):
        attempts = [("lua", lua), ("legacy", legacy)]
        if self.mode == "legacy":
            attempts.reverse()
        for mode, command in attempts:
            response = hypr("dispatch", command)
            if response and response.lower() == "ok":
                self.mode = mode
                return True
        return False

    def float(self, address, enabled):
        selector = f"address:{address}"
        action = "enable" if enabled else "disable"
        legacy = "setfloating" if enabled else "settiled"
        return self.send(
            f"hl.dsp.window.float({{ action = '{action}', window = '{selector}' }})",
            f"{legacy} {selector}",
        )

    def place(self, address, x, y, width, height):
        selector = f"address:{address}"
        size = self.send(
            f"hl.dsp.window.resize({{ x = {width}, y = {height}, relative = false, window = '{selector}' }})",
            f"resizewindowpixel exact {width} {height},{selector}",
        )
        move = self.send(
            f"hl.dsp.window.move({{ x = {x}, y = {y}, relative = false, window = '{selector}' }})",
            f"movewindowpixel exact {x} {y},{selector}",
        )
        return size and move

    def move_to_workspace(self, address, workspace):
        selector = f"address:{address}"
        return self.send(
            f"hl.dsp.window.move({{ window = '{selector}', workspace = '{workspace}', follow = false }})",
            f"movetoworkspacesilent {workspace},{selector}",
        )


def slots(rect, count):
    """Split the newest window's space, alternating columns and rows.

    A second window takes the right half; a third takes the lower half of
    that right side. Every rectangle remains occupied as more windows arrive.
    """
    if count < 1:
        return []
    result = [rect]
    for index in range(1, count):
        x, y, width, height = result[-1]
        split_columns = index % 2 == 1
        span = width if split_columns else height
        gap = min(8, max(0, span - 2))
        first = max(1, (span - gap) // 2)
        second = max(1, span - gap - first)
        if split_columns:
            result[-1] = (x, y, first, height)
            result.append((x + first + gap, y, second, height))
        else:
            result[-1] = (x, y, width, first)
            result.append((x, y + first + gap, width, second))
    return result


def leaves(tree):
    if tree is None:
        return []
    if isinstance(tree, str):
        return [tree]
    return leaves(tree[1]) + leaves(tree[2])


def split_parts(tree):
    axis, first, second, *ratio = tree
    return axis, first, second, ratio[0] if ratio else 0.5


def split_node(axis, first, second, ratio=0.5):
    return (axis, first, second, ratio)


def remove_leaf(tree, address):
    if tree is None or tree == address:
        return None
    if isinstance(tree, str):
        return tree
    axis, first, second, ratio = split_parts(tree)
    first = remove_leaf(first, address)
    second = remove_leaf(second, address)
    if first is None:
        return second
    if second is None:
        return first
    return split_node(axis, first, second, ratio)


def replace_leaf(tree, address, replacement):
    if tree == address:
        return replacement
    if tree is None or isinstance(tree, str):
        return tree
    axis, first, second, ratio = split_parts(tree)
    return split_node(axis, replace_leaf(first, address, replacement),
                      replace_leaf(second, address, replacement), ratio)


def add_leaf(tree, address):
    if tree is None:
        return address
    last = leaves(tree)[-1]
    # New windows split the newest window's space: right, then below, etc.
    axis = "h" if len(leaves(tree)) % 2 else "v"
    return replace_leaf(tree, last, split_node(axis, last, address))


def drop(tree, source, target, zone):
    if source == target or source not in leaves(tree) or target not in leaves(tree):
        return tree
    if zone == "center":
        marker = "__lcars_swap__"
        tree = replace_leaf(tree, source, marker)
        tree = replace_leaf(tree, target, source)
        return replace_leaf(tree, marker, target)
    if zone not in ("left", "right", "top", "bottom"):
        return tree
    tree = remove_leaf(tree, source)
    axis = "h" if zone in ("left", "right") else "v"
    split = (split_node(axis, source, target) if zone in ("left", "top")
             else split_node(axis, target, source))
    return replace_leaf(tree, target, split)


def resize_edge(tree, address, axis):
    """Return the leaf edge adjoining its nearest split on the given axis."""
    if tree is None or isinstance(tree, str) or address not in leaves(tree):
        return ""
    branch_axis, first, second, _ = split_parts(tree)
    in_first = address in leaves(first)
    inner = resize_edge(first if in_first else second, address, axis)
    if inner:
        return inner
    if branch_axis != axis:
        return ""
    return ("right" if in_first else "left") if axis == "h" else (
        "bottom" if in_first else "top")


def tree_slots(tree, rect, gap=8):
    if tree is None:
        return {}
    if isinstance(tree, str):
        return {tree: rect}
    axis, first, second, ratio = split_parts(tree)
    first_rect, second_rect = split_rectangles(rect, axis, ratio, gap)
    return {**tree_slots(first, first_rect, gap),
            **tree_slots(second, second_rect, gap)}


def split_rectangles(rect, axis, ratio, gap):
    x, y, width, height = rect
    span = width if axis == "h" else height
    split_gap = min(gap, max(0, span - 2))
    before = max(1, min(span - split_gap - 1, int((span - split_gap) * ratio)))
    after = max(1, span - split_gap - before)
    if axis == "h":
        first_rect = (x, y, before, height)
        second_rect = (x + before + split_gap, y, after, height)
    else:
        first_rect = (x, y, width, before)
        second_rect = (x, y + before + split_gap, width, after)
    return first_rect, second_rect


def resize_at_pointer(tree, address, axis, pointer, rect, gap=8):
    """Move the nearest split of a leaf to the given global pointer position."""
    if tree is None or isinstance(tree, str) or address not in leaves(tree):
        return tree
    branch_axis, first, second, ratio = split_parts(tree)
    first_rect, second_rect = split_rectangles(rect, branch_axis, ratio, gap)
    in_first = address in leaves(first)
    child = first if in_first else second
    if resize_edge(child, address, axis):
        changed = resize_at_pointer(child, address, axis, pointer,
                                    first_rect if in_first else second_rect, gap)
        return split_node(branch_axis, changed, second, ratio) if in_first else (
            split_node(branch_axis, first, changed, ratio))
    if branch_axis != axis:
        return tree
    origin = rect[0] if axis == "h" else rect[1]
    span = rect[2] if axis == "h" else rect[3]
    usable = span - min(gap, max(0, span - 2))
    if usable <= 0:
        return tree
    desired = (pointer - origin - (span - usable) / 2) / usable
    return split_node(branch_axis, first, second,
                      round(min(0.8, max(0.2, desired)), 4))


def learn_border_resize(tree, address, expected, actual, cursor, rect, gap=8):
    """Translate Hyprland's native floating-window drag into LCARS split ratios."""
    if not cursor or address not in leaves(tree):
        return tree
    try:
        cursor_x, cursor_y = cursor["x"], cursor["y"]
        x, y, width, height = actual
        old_x, old_y, old_width, old_height = expected
    except (KeyError, TypeError, ValueError):
        return tree
    for axis, size_change, edges, pointer, cross, cross_start, cross_span in (
        ("h", width - old_width,
         (("left", x - old_x, x),
          ("right", x + width - old_x - old_width, x + width)),
         cursor_x, cursor_y, y, height),
        ("v", height - old_height,
         (("top", y - old_y, y),
          ("bottom", y + height - old_y - old_height, y + height)),
         cursor_y, cursor_x, x, width),
    ):
        if abs(size_change) < 2:
            continue
        edge, movement, coordinate = max(edges, key=lambda item: abs(item[1]))
        if (edge != resize_edge(tree, address, axis) or abs(movement) < 2
                or abs(pointer - coordinate) > 30
                or not cross_start - 30 <= cross <= cross_start + cross_span + 30):
            continue
        tree = resize_at_pointer(tree, address, axis, coordinate, rect, gap)
    return tree


def drop_at_cursor(slots, source, cursor):
    """Find the LCARS drop target and zone under a native window drag."""
    if not cursor:
        return None
    x, y = cursor.get("x"), cursor.get("y")
    if x is None or y is None:
        return None
    for address, (left, top, width, height) in slots.items():
        if address == source or not (left <= x <= left + width
                                     and top <= y <= top + height):
            continue
        distances = ((x - left) / width, (left + width - x) / width,
                     (y - top) / height, (top + height - y) / height)
        smallest = min(range(4), key=distances.__getitem__)
        return address, (("left", "right", "top", "bottom")[smallest]
                         if distances[smallest] < 0.23 else "center")
    return None


def workspace_at_cursor(cursor, pills, count=5):
    """Return a workspace pill number at the global pointer position."""
    if not cursor or not pills:
        return 0
    try:
        x, y = cursor["x"], cursor["y"]
        left, top, width, height = pills
    except (KeyError, TypeError, ValueError):
        return 0
    if width <= 0 or height <= 0 or not (left <= x < left + width
                                         and top <= y < top + height):
        return 0
    return min(count, int(count * (x - left) / width) + 1)


def set_native_drag(enabled, release_file, rect=None):
    """Install or remove a mouse-only Hyprland drag bind for the LCARS toggle."""
    if enabled:
        left, top, width, height = rect
        release_command = "sh -c " + shlex.quote(
            "date +%s%N > " + shlex.quote(release_file))
        code = ("hl.config({ binds = { drag_threshold = 8 } }); "
                "lcars_drag_bind = hl.bind('mouse:272', function() "
                "local p = hl.get_cursor_pos(); "
                f"if p.x < {left} or p.x > {left + width} "
                f"or p.y < {top} or p.y > {top + height} "
                "then return { ok = false } end; "
                "return hl.dispatch(hl.dsp.window.drag()) end, "
                "{ mouse = true, auto_consuming = true }); "
                "lcars_release_bind = hl.bind('mouse:272', "
                f"hl.dsp.exec_cmd({json.dumps(release_command)}), "
                "{ release = true, non_consuming = true })")
    else:
        code = ("if lcars_drag_bind then lcars_drag_bind:remove(); "
                "lcars_drag_bind = nil end; "
                "if lcars_release_bind then lcars_release_bind:remove(); "
                "lcars_release_bind = nil end")
    return hypr("eval", code) == "ok"


def process_stats(pid, previous, now):
    """Return process CPU percent and resident MB; direct process only."""
    try:
        stat = open(f"/proc/{pid}/stat", encoding="utf-8").read()
        fields = stat[stat.rfind(")") + 2:].split()
        ticks = int(fields[11]) + int(fields[12])
        pages = int(fields[21])
        rss = round(pages * os.sysconf("SC_PAGE_SIZE") / 1_000_000)
        old = previous.get(pid)
        cpu = round(100 * (ticks - old[0]) / os.sysconf("SC_CLK_TCK") /
                    (now - old[1])) if old and now > old[1] else 0
        previous[pid] = (ticks, now)
        return max(0, cpu), max(0, rss)
    except (OSError, ValueError, IndexError, TypeError):
        return None, None


def monitor_for(monitors, state):
    name = state.get("monitor", "")
    if name:
        return next((m for m in monitors if m.get("name") == name), None)
    screen = state.get("screen", "")
    matches = [m for m in monitors if
               f"{round(m['width'] / m['scale'])}x{round(m['height'] / m['scale'])}" == screen]
    if len(matches) == 1:
        return matches[0]
    return next((m for m in monitors if m.get("focused")), None)


def authentication_open(clients, monitor_id):
    return any(c.get("class") in UNMANAGED_CLASSES
               and c.get("monitor") == monitor_id
               and c.get("mapped", True)
               and not c.get("hidden", False)
               for c in clients)


def main():
    dispatcher = Dispatcher()
    original = {}
    layouts = {}
    previous_stats = {}
    last_sample = 0
    sampled = {}
    last_output = ""
    last_targets = {}
    last_observed = {}
    last_commanded = {}
    native_resize_until = {}
    release_file = os.path.join(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"),
                                "lcars-drag-release")
    drag_enabled = False
    drag_source = None
    drag_preview = None
    drag_workspace = 0
    last_release = os.stat(release_file).st_mtime_ns if os.path.exists(release_file) else 0
    last_key = None
    last_rect = None
    last_arrange = False
    state = None
    actions = []
    running = True
    pending = b""
    stdin_fd = sys.stdin.fileno()
    os.set_blocking(stdin_fd, False)

    def stop(_signum, _frame):
        nonlocal running
        running = False

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    try:
        while running:
            ready, _, _ = select.select([stdin_fd], [], [], 0.18)
            if ready:
                chunk = os.read(stdin_fd, 65536)
                if not chunk:
                    break
                pending += chunk
                # Consume complete frames and keep only the newest rectangle.
                while b"\n" in pending:
                    line, pending = pending.split(b"\n", 1)
                    try:
                        new_state = json.loads(line)
                        if all(k in new_state for k in ("x", "y", "width", "height")):
                            state = new_state
                        elif new_state.get("action"):
                            actions.append(new_state)
                    except (ValueError, TypeError):
                        pass
            if not state or not running:
                continue

            monitors = query("monitors") or []
            clients = query("clients") or []
            monitor = monitor_for(monitors, state)
            if not monitor:
                continue
            workspace = monitor.get("activeWorkspace", {}).get("id")
            candidates = {
                c["address"]: c for c in clients if c.get("mapped", True)
                 and not c.get("hidden", False)
                 and c.get("monitor") == monitor["id"]
                 and c.get("workspace", {}).get("id") == workspace
                 and not c.get("fullscreen")
                 and c.get("class") not in UNMANAGED_CLASSES
                 and c.get("address")
            }
            key = (monitor["name"], workspace)
            tree = layouts.get(key)
            previous_tree = tree
            for address in leaves(tree):
                if address not in candidates:
                    tree = remove_leaf(tree, address)
            for address in sorted(candidates):
                if address not in leaves(tree):
                    tree = add_leaf(tree, address)
            for action in actions:
                if action.get("action") == "drop":
                    tree = drop(tree, action.get("source"), action.get("target"),
                                action.get("zone"))
                elif action.get("action") == "move_workspace" and action.get("source") in candidates:
                    destination = action.get("workspace")
                    if (type(destination) is int and 1 <= destination <= 5
                            and destination != workspace
                            and dispatcher.move_to_workspace(action["source"], destination)):
                        tree = remove_leaf(tree, action["source"])
                elif action.get("action") == "close" and action.get("source") in candidates:
                    dispatcher.send(
                        f"hl.dsp.window.close({{ window = 'address:{action['source']}' }})",
                        f"closewindow address:{action['source']}",
                    )
            actions.clear()
            current = candidates
            for address in list(original):
                if address not in current:
                    old = original.pop(address)
                    if any(c.get("address") == address for c in clients):
                        if old["floating"]:
                            dispatcher.place(address, *old["rect"])
                        else:
                            dispatcher.float(address, False)

            rect = (
                int(monitor["x"] + round(state["x"])),
                int(monitor["y"] + round(state["y"])),
                max(1, round(state["width"])),
                max(1, round(state["height"])),
            )
            arrange = bool(state.get("arrange"))
            gap = max(8, int(state.get("arrangeGap", 18))) if arrange else 8
            now = time.monotonic()
            want_drag = bool(state.get("dragMode")) and not arrange and not state.get("blocked")
            if want_drag != drag_enabled and set_native_drag(want_drag, release_file, rect):
                drag_enabled = want_drag
                drag_source = None
                drag_preview = None
                drag_workspace = 0
                last_release = (os.stat(release_file).st_mtime_ns
                                if os.path.exists(release_file) else 0)
            if drag_source and (not drag_enabled or key != last_key or rect != last_rect
                                or drag_source not in candidates):
                drag_source = None
                drag_preview = None
                drag_workspace = 0
            released = os.stat(release_file).st_mtime_ns if os.path.exists(release_file) else 0
            release_seen = released != last_release
            last_release = released
            cursor = None
            if drag_enabled:
                focused = next((c for c in candidates.values()
                                if c.get("focusHistoryID") == 0), None)
                if drag_source is None and focused and key == last_key and rect == last_rect:
                    address = focused["address"]
                    actual = (*focused["at"], *focused["size"])
                    baseline = last_targets.get(address)
                    if (baseline and abs(actual[2] - baseline[2]) < 2
                            and abs(actual[3] - baseline[3]) < 2
                            and (abs(actual[0] - baseline[0]) >= 3
                                 or abs(actual[1] - baseline[1]) >= 3)):
                        drag_source = address
                if drag_source:
                    cursor = query("cursorpos")
                    pills = state.get("workspacePills") or {}
                    pill_rect = (monitor["x"] + pills.get("x", 0),
                                 monitor["y"] + pills.get("y", 0),
                                 pills.get("width", 0), pills.get("height", 0))
                    drag_workspace = workspace_at_cursor(cursor, pill_rect)
                    drag_preview = (None if drag_workspace else
                                    drop_at_cursor(tree_slots(tree, rect, gap),
                                                   drag_source, cursor))
                    if release_seen:
                        if (drag_workspace and drag_workspace != workspace
                                and dispatcher.move_to_workspace(drag_source,
                                                                 drag_workspace)):
                            tree = remove_leaf(tree, drag_source)
                        elif drag_preview:
                            tree = drop(tree, drag_source, *drag_preview)
                        drag_source = None
                        drag_preview = None
                        drag_workspace = 0
            if (not arrange and key == last_key and rect == last_rect
                    and not last_arrange and tree == previous_tree and not drag_source):
                focused = next((c for c in candidates.values()
                                if c.get("focusHistoryID") == 0), None)
                if focused:
                    address = focused["address"]
                    actual = (*focused["at"], *focused["size"])
                    native_active = native_resize_until.get(address, 0) > now
                    baseline = (last_observed if native_active else last_targets).get(address)
                    if (baseline and (abs(actual[2] - baseline[2]) >= 2
                                     or abs(actual[3] - baseline[3]) >= 2)
                            and (native_active or now - last_commanded.get(address, 0) > 0.35)):
                        changed = learn_border_resize(tree, address, baseline, actual,
                                                      query("cursorpos"), rect, gap)
                        if changed != tree:
                            tree = changed
                            native_resize_until[address] = now + 0.35
            layouts[key] = tree
            targets = tree_slots(tree, rect, gap)
            bar_height = min(50, max(24, int(state.get("barHeight", 34))))
            frame_width = min(16, max(4, int(state.get("frameWidth", 9))))
            next_targets = {}
            next_observed = {}
            for address, slot in targets.items():
                client = candidates[address]
                target = (slot[0] + frame_width, slot[1] + bar_height,
                          max(1, slot[2] - 2 * frame_width),
                          max(1, slot[3] - bar_height - frame_width)) if arrange else slot
                next_targets[address] = target
                next_observed[address] = (*client["at"], *client["size"])
                if address not in original:
                    original[address] = {
                        "floating": client.get("floating", False),
                        "rect": (*client["at"], *client["size"]),
                    }
                if not client.get("floating", False):
                    if not dispatcher.float(address, True):
                        continue
                if ((native_resize_until.get(address, 0) > now and not arrange)
                        or address == drag_source):
                    continue
                if (*client["at"], *client["size"]) != target or not client.get("floating", False):
                    if dispatcher.place(address, *target):
                        last_commanded[address] = now
                        next_observed[address] = target

            last_targets = next_targets
            last_observed = next_observed
            last_key = key
            last_rect = rect
            last_arrange = arrange

            if arrange and time.monotonic() - last_sample >= 1:
                now = time.monotonic()
                sampled = {address: process_stats(candidates[address].get("pid"),
                                                  previous_stats, now)
                           for address in targets}
                last_sample = now
            if not arrange:
                sampled = {}
                previous_stats.clear()
                last_sample = 0
            output = json.dumps({"authenticationOpen": authentication_open(clients, monitor["id"]),
                                 "nativeDrag": {"source": drag_source,
                                                "target": drag_preview[0] if drag_preview else "",
                                                "zone": drag_preview[1] if drag_preview else "",
                                                "workspace": drag_workspace}
                                 if drag_source else None,
                                 "windows": [
                {"address": address, "title": candidates[address].get("title") or
                 candidates[address].get("class") or "WINDOW",
                 "rect": [slot[0] - monitor["x"], slot[1] - monitor["y"],
                          slot[2], slot[3]],
                 "cpu": sampled.get(address, (None, None))[0],
                 "ram": sampled.get(address, (None, None))[1]}
                for address, slot in targets.items()
            ] if arrange or drag_enabled else []}, separators=(",", ":"))
            if output != last_output:
                print(output, flush=True)
                last_output = output
    finally:
        if drag_enabled:
            set_native_drag(False, release_file)
        clients = query("clients") or []
        live = {c.get("address") for c in clients}
        for address, old in original.items():
            if address not in live:
                continue
            if old["floating"]:
                dispatcher.place(address, *old["rect"])
            else:
                dispatcher.float(address, False)


if __name__ == "__main__":
    main()
