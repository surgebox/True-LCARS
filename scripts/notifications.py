#!/usr/bin/env python3
"""Persist LCARS notification history and DND state over a JSON-lines pipe."""

import json
import os
from pathlib import Path
import sys


def state_path():
    state_home = os.environ.get("XDG_STATE_HOME")
    base = Path(state_home) if state_home else Path.home() / ".local/state"
    return base / "lcars" / "notifications.json"


def normalize(value):
    if not isinstance(value, dict):
        return {"dnd": False, "history": []}
    rows = value.get("history", [])
    if not isinstance(rows, list):
        rows = []
    history = []
    for row in rows[:30]:
        if not isinstance(row, dict):
            continue
        try:
            history.append({
                "key": str(row.get("key", ""))[:80],
                "app": str(row.get("app", ""))[:200],
                "summary": str(row.get("summary", ""))[:500],
                "body": str(row.get("body", ""))[:1200],
                "timestamp": int(row.get("timestamp") or 0),
                "urgency": int(row.get("urgency") or 0),
                "active": False,
            })
        except (ValueError, TypeError, OverflowError):
            continue
    return {"dnd": bool(value.get("dnd", False)), "history": history}


def load(path):
    try:
        return normalize(json.loads(path.read_text()))
    except (OSError, ValueError, TypeError, OverflowError):
        return {"dnd": False, "history": []}


def save(path, state):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(state, ensure_ascii=False, separators=(",", ":")) + "\n")
    temporary.replace(path)


def main():
    path = state_path()
    print(json.dumps({"op": "loaded", **load(path)}, ensure_ascii=False), flush=True)
    for line in sys.stdin:
        try:
            request = json.loads(line)
            if request.get("op") == "save":
                save(path, normalize(request))
        except (ValueError, TypeError, OSError, OverflowError):
            # A malformed write cannot erase the last good on-disk state.
            continue


if __name__ == "__main__":
    main()
