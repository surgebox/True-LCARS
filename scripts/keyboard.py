#!/usr/bin/env python3
"""Report editable AT-SPI focus and type into the focused Hyprland app."""

import json
import subprocess
import sys
from threading import Thread

import gi

from app_layout import query

gi.require_version("Atspi", "2.0")
from gi.repository import Atspi, GLib


def key_input(key, special, xwayland):
    if special:
        if key not in ("Return", "BackSpace", "Left", "Right"):
            return None
    elif not isinstance(key, str) or len(key) != 1 or not key.isprintable():
        return None
    if xwayland:
        keysym = key if special else f"U{ord(key):04X}"
        return ["xdotool", "-"], f"key --clearmodifiers {keysym}\n"
    if special:
        return ["wtype", "-k", key], ""
    return ["wtype", "-"], key


def send_keys(loop):
    for line in sys.stdin:
        try:
            request = json.loads(line)
            window = query("activewindow")
            if not window or not window.get("acceptsInput", True):
                continue
            keypress = key_input(request["key"], request["special"], window.get("xwayland"))
            if keypress:
                command, data = keypress
                subprocess.run(command, input=data, text=True, stdout=subprocess.DEVNULL,
                               timeout=2, check=True)
        except (ValueError, TypeError, KeyError):
            continue
        except (OSError, subprocess.SubprocessError) as error:
            print(f"LCARS keyboard: {error}", file=sys.stderr)
    GLib.idle_add(loop.quit)


class FocusListener:
    def __init__(self):
        self.pending_blur = 0
        self.field = None

    def report(self, editable):
        self.pending_blur = 0
        print("editable" if editable else "blur", flush=True)
        return GLib.SOURCE_REMOVE

    def changed(self, event, *_):
        if event.detail1:
            try:
                states = event.source.get_state_set()
                window = query("activewindow") if states.contains(Atspi.StateType.EDITABLE) else None
                if window and window.get("pid") == event.source.get_process_id():
                    if self.pending_blur:
                        GLib.source_remove(self.pending_blur)
                    self.field = event.source
                    self.report(True)
            except GLib.Error:
                pass
        elif event.source == self.field:
            self.field = None
            # Moving between input fields emits blur before the next focus.
            self.pending_blur = GLib.timeout_add(120, self.report, False)


def main():
    loop = GLib.MainLoop()
    focus = FocusListener()
    listener = Atspi.EventListener.new(focus.changed)
    listener.register("object:state-changed:focused")
    Thread(target=send_keys, args=(loop,), daemon=True).start()
    loop.run()


if __name__ == "__main__":
    main()
