#!/usr/bin/env python3
"""Fit windows on the LCARS monitor into the live APP rectangle.

The shell sends one JSON rectangle per line. This process owns only windows on
the monitor's visible workspace and restores their prior state on exit.
"""

import json
import math
import os
import select
import signal
import subprocess
import sys


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


def slots(rect, count):
    if count < 1:
        return []
    columns = math.ceil(math.sqrt(count))
    rows = math.ceil(count / columns)
    gap = 8
    x, y, width, height = rect
    usable_width = max(1, width - gap * (columns - 1))
    usable_height = max(1, height - gap * (rows - 1))
    return [
        (
            x + (i % columns) * (usable_width // columns + gap),
            y + (i // columns) * (usable_height // rows + gap),
            max(1, usable_width // columns),
            max(1, usable_height // rows),
        )
        for i in range(count)
    ]


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


def main():
    dispatcher = Dispatcher()
    original = {}
    state = None
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
            candidates = sorted(
                (c for c in clients if c.get("mapped", True)
                 and not c.get("hidden", False)
                 and c.get("monitor") == monitor["id"]
                 and c.get("workspace", {}).get("id") == workspace
                 and not c.get("fullscreen")
                 and c.get("address")),
                key=lambda c: c["address"],
            )
            current = {c["address"]: c for c in candidates}
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
            for client, target in zip(candidates, slots(rect, len(candidates))):
                address = client["address"]
                if address not in original:
                    original[address] = {
                        "floating": client.get("floating", False),
                        "rect": (*client["at"], *client["size"]),
                    }
                if not client.get("floating", False):
                    if not dispatcher.float(address, True):
                        continue
                if (*client["at"], *client["size"]) != target or not client.get("floating", False):
                    dispatcher.place(address, *target)
    finally:
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
