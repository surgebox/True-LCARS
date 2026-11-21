#!/usr/bin/env python3
"""LCARS app catalog and package search. One JSON request per input line."""

import json
import os
import pty
import re
import secrets
import shutil
import struct
import subprocess
import sys
import termios
import threading
import fcntl
import time
from pathlib import Path

import gi

gi.require_version("Gio", "2.0")
gi.require_version("Gtk", "3.0")
from gi.repository import Gio, Gtk


write_lock = threading.Lock()
search_number = 0
search_lock = threading.Lock()
available = {}
install_lock = threading.Lock()
install_process = None
pending_uninstall = None
state_lock = threading.Lock()
STATE_FILE = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "lcars/launcher.json"
ANSI_ESCAPE = re.compile(r"\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1b\\))")
ICON_THEME = Gtk.IconTheme.new()


def load_state():
    try:
        data = json.loads(STATE_FILE.read_text())
        return {"pinned": [key for key in data.get("pinned", []) if isinstance(key, str)],
                "recent": {key: value for key, value in data.get("recent", {}).items()
                           if isinstance(key, str) and isinstance(value, (int, float))}}
    except (OSError, ValueError, TypeError, AttributeError):
        return {"pinned": [], "recent": {}}


state = load_state()


def save_state():
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    temporary = STATE_FILE.with_name(STATE_FILE.name + ".tmp")
    temporary.write_text(json.dumps(state, ensure_ascii=False))
    os.replace(temporary, STATE_FILE)


def app_info(app_id):
    return next((app for app in Gio.AppInfo.get_all()
                 if app.get_id() == app_id and app.should_show()), None)


def app_icon(info):
    icon = info.get_icon()
    if isinstance(icon, Gio.FileIcon):
        return {"iconUrl": icon.get_file().get_uri()}
    names = icon.get_names() if isinstance(icon, Gio.ThemedIcon) else []
    for name in [*names, "application-x-executable"]:
        match = ICON_THEME.lookup_icon(name, 64, 0)
        if match and match.get_filename():
            return {"iconUrl": Path(match.get_filename()).as_uri()}
    return {"iconUrl": ""}


def emit(message):
    with write_lock:
        print(json.dumps(message, ensure_ascii=False), flush=True)


def installed_apps():
    apps = []
    with state_lock:
        pinned = set(state["pinned"])
        recent = state["recent"].copy()
    for info in Gio.AppInfo.get_all():
        if not info.should_show() or not info.get_id():
            continue
        app_id = info.get_id()
        apps.append({"id": app_id, "name": info.get_display_name() or info.get_name(),
                     "description": info.get_description() or "",
                     "pinned": app_id in pinned, "lastUsed": recent.get(app_id, 0),
                     **app_icon(info)})
    return sorted(apps, key=lambda app: app["name"].casefold())


def run(args, timeout=35):
    return subprocess.run(args, text=True, capture_output=True, timeout=timeout, check=False)


def search(query, number):
    results = []
    errors = []
    installed_flatpaks = set()
    installed_rpms = set()
    if shutil.which("flatpak"):
        installed_flatpaks = set(run(["flatpak", "list", "--app", "--columns=application"], 10).stdout.splitlines())
    if shutil.which("rpm"):
        installed_rpms = set(run(["rpm", "-qa", "--qf", "%{NAME}\\n"], 10).stdout.splitlines())
    if shutil.which("flatpak"):
        try:
            result = run(["flatpak", "search", "--json", query])
            if result.returncode:
                errors.append("Flatpak: " + (result.stderr.strip() or "Search failed."))
            else:
                for item in json.loads(result.stdout)[:80]:
                    app_id = item.get("application_id", "")
                    remotes = [remote.strip() for remote in item.get("remotes", "").split(",")]
                    remote = "flathub" if "flathub" in remotes else "fedora" if "fedora" in remotes else ""
                    if not remote or not app_id:
                        continue
                    results.append({"key": "flatpak:" + remote + ":" + app_id,
                                    "name": item.get("name") or app_id,
                                    "description": item.get("description") or "",
                                    "source": "FLATHUB" if remote == "flathub" else "FEDORA FLATPAK",
                                    "version": item.get("version") or "",
                                    "installed": app_id in installed_flatpaks})
        except (ValueError, subprocess.TimeoutExpired) as exc:
            errors.append("Flatpak search unavailable: " + str(exc))
    if shutil.which("dnf5"):
        try:
            result = run(["dnf5", "--cacheonly", "search", "--name", query])
            if result.returncode and not result.stdout.strip():
                errors.append("Fedora packages: " + (result.stderr.strip() or "Search failed."))
            for line in result.stdout.splitlines():
                match = re.match(r"^\s+([A-Za-z0-9][A-Za-z0-9+_.-]*)\.([A-Za-z0-9_]+)\s+(.+)$", line)
                if match:
                    name, _arch, description = match.groups()
                    results.append({"key": "dnf:" + name, "name": name,
                                    "description": description, "source": "FEDORA RPM", "version": "",
                                    "installed": name in installed_rpms})
                    if sum(item["source"] == "FEDORA RPM" for item in results) >= 30:
                        break
        except subprocess.TimeoutExpired:
            errors.append("Fedora package search timed out.")
    with search_lock:
        if number != search_number:
            return
        available.clear()
        for item in results:
            available[item["key"]] = item
    emit({"op": "search", "results": results[:70], "error": " ".join(errors)})


def start_package_process(command, item, action):
    global install_process
    with install_lock:
        if install_process is not None:
            emit({"op": action, "error": "A package operation is already running."})
            return
        try:
            pid, master = pty.fork()
        except OSError as exc:
            emit({"op": action, "error": str(exc)})
            return
        if pid == 0:
            try:
                os.execvp(command[0], command)
            except OSError as exc:
                os.write(2, (str(exc) + "\n").encode())
                os._exit(127)
        fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 100, 0, 0))
        install_process = (pid, master)
    emit({"op": "install_started", "name": item["name"], "source": item["source"],
          "action": action})

    def stream():
        global install_process
        try:
            while True:
                try:
                    chunk = os.read(master, 4096)
                except OSError:
                    break
                if not chunk:
                    break
                # Keep terminal controls: the QML console uses carriage returns
                # to redraw a progress line instead of adding another line.
                text = ANSI_ESCAPE.sub("", chunk.decode("utf-8", "replace"))
                if text:
                    emit({"op": "install_output", "text": text})
        finally:
            _, status = os.waitpid(pid, 0)
            os.close(master)
            with install_lock:
                install_process = None
            code = os.waitstatus_to_exitcode(status)
            emit({"op": "install_finished", "code": code, "action": action})
            emit({"op": "apps", "apps": installed_apps()})

    threading.Thread(target=stream, daemon=True).start()


def install(key):
    # Only install a result returned by this service, never a typed command.
    with search_lock:
        item = available.get(key)
    if not item:
        emit({"op": "install", "error": "Select an app from the current search results."})
        return
    parts = key.split(":", 2)
    if parts[0] == "flatpak" and len(parts) == 3:
        # One sudo authentication covers the system app and its runtimes.
        command = ["sudo", "flatpak", "install", "--system", parts[1], parts[2]]
    elif parts[0] == "dnf" and len(parts) == 2:
        command = ["sudo", "dnf5", "install", parts[1]]
    else:
        emit({"op": "install", "error": "Unsupported package source."})
        return
    start_package_process(command, item, "install")


def uninstall_target(info):
    """Resolve the installed package from the desktop entry, not user text."""
    app_name = info.get_display_name() or info.get_name()
    filename = info.get_filename() if hasattr(info, "get_filename") else None
    flatpak_id = info.get_string("X-Flatpak") if hasattr(info, "get_string") else None
    if not flatpak_id and filename and "/flatpak/" in filename \
            and "/applications/" in filename and info.get_id().endswith(".desktop"):
        flatpak_id = info.get_id()[:-8]
    if flatpak_id:
        result = run(["flatpak", "list", "--app", "--columns=application,installation"], 10)
        installations = [line.split("\t", 1)[1].strip()
                         for line in result.stdout.splitlines()
                         if line.startswith(flatpak_id + "\t") and "\t" in line]
        if not installations:
            raise ValueError("The Flatpak is no longer installed.")
        scope = "user" if "user" in installations else "system"
        command = (["flatpak"] if scope == "user" else ["sudo", "flatpak"])
        command += ["uninstall", "--" + scope, flatpak_id]
        return {"name": app_name, "source": "FLATPAK " + scope.upper(),
                "package": flatpak_id, "command": command}
    if not filename:
        raise ValueError("No package file was found for this app.")
    result = run(["rpm", "-qf", "--qf", "%{NAME}\n", filename], 10)
    if result.returncode or not result.stdout.strip():
        raise ValueError("This app is not managed by Flatpak or Fedora RPM.")
    package = result.stdout.splitlines()[0].strip()
    return {"name": app_name, "source": "FEDORA RPM", "package": package,
            "command": ["sudo", "dnf5", "remove", package]}


def prepare_uninstall(app_id):
    global pending_uninstall
    with install_lock:
        busy = install_process is not None
    if busy:
        emit({"op": "uninstall_prepared", "error": "Wait for the current package operation to finish."})
        return
    info = app_info(app_id)
    if not info:
        emit({"op": "uninstall_prepared", "error": "This app is no longer available."})
        return
    try:
        target = uninstall_target(info)
    except (ValueError, OSError, subprocess.TimeoutExpired) as exc:
        emit({"op": "uninstall_prepared", "error": str(exc)})
        return
    token = secrets.token_urlsafe(16)
    pending_uninstall = (token, target, time.monotonic())
    emit({"op": "uninstall_prepared", "token": token,
          "name": target["name"], "source": target["source"],
          "package": target["package"]})


def confirm_uninstall(token):
    global pending_uninstall
    pending = pending_uninstall
    pending_uninstall = None
    if not pending or token != pending[0] or time.monotonic() - pending[2] > 300:
        emit({"op": "uninstall", "error": "Uninstall confirmation expired. Select the app again."})
        return
    target = pending[1]
    start_package_process(target["command"], target, "uninstall")


def installer_input(value):
    with install_lock:
        process = install_process
    if process is None:
        emit({"op": "install_input", "error": "No installation is running."})
        return
    os.write(process[1], (str(value)[:256] + "\n").encode())


def handle(message):
    global search_number, pending_uninstall
    op = message.get("op")
    if op == "apps":
        emit({"op": "apps", "apps": installed_apps()})
    elif op == "launch":
        app_id = message.get("id", "")
        info = app_info(app_id)
        if not info:
            emit({"op": "launch", "error": "This app is no longer available."})
            return
        try:
            info.launch([], Gio.AppLaunchContext())
            with state_lock:
                state["recent"][app_id] = time.time()
                save_state()
            emit({"op": "launch", "name": info.get_display_name() or info.get_name()})
            emit({"op": "apps", "apps": installed_apps()})
        except Exception as exc:
            emit({"op": "launch", "error": str(exc)})
    elif op == "toggle_pin":
        app_id = str(message.get("id", ""))
        if not app_info(app_id):
            emit({"op": "toggle_pin", "error": "This app is no longer available."})
            return
        with state_lock:
            if app_id in state["pinned"]:
                state["pinned"].remove(app_id)
            else:
                state["pinned"].append(app_id)
            save_state()
        emit({"op": "apps", "apps": installed_apps()})
    elif op == "search":
        query = str(message.get("query", "")).strip()[:100]
        with search_lock:
            search_number += 1
            number = search_number
            available.clear()
        if len(query) >= 2:
            threading.Thread(target=search, args=(query, number), daemon=True).start()
        else:
            emit({"op": "search", "results": [], "error": ""})
    elif op == "install":
        install(str(message.get("key", "")))
    elif op == "prepare_uninstall":
        prepare_uninstall(str(message.get("id", "")))
    elif op == "confirm_uninstall":
        confirm_uninstall(str(message.get("token", "")))
    elif op == "cancel_uninstall":
        pending_uninstall = None
    elif op == "install_input":
        installer_input(message.get("text", ""))
    elif op == "install_cancel":
        with install_lock:
            process = install_process
        if process is not None:
            os.write(process[1], b"\x03")


if __name__ == "__main__":
    for line in sys.stdin:
        try:
            handle(json.loads(line))
        except Exception as exc:
            emit({"op": "error", "error": str(exc)})
