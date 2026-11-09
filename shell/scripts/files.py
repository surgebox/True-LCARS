#!/usr/bin/env python3
"""Read-only file service for the embedded browser; one JSON request per line."""
import concurrent.futures
import datetime
import json
import mimetypes
import os
from pathlib import Path
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import threading

MAX_ENTRIES = 10000
MAX_TEXT = 65536
output_lock = threading.Lock()
mimetypes.add_type("text/x-qml", ".qml")


def location(value):
    return Path(os.path.abspath(os.path.expanduser(value or "~")))


def listing(path, hidden=False):
    entries = []
    truncated = False
    with os.scandir(path) as scan:
        for item in scan:
            if not hidden and item.name.startswith("."):
                continue
            if len(entries) == MAX_ENTRIES:
                truncated = True
                break
            entries.append({"name": item.name, "path": item.path,
                            "directory": item.is_dir(), "symlink": item.is_symlink()})
    entries.sort(key=lambda entry: (not entry["directory"], entry["name"].casefold()))
    return {"entries": entries, "truncated": truncated}


def run(args, timeout=8):
    result = subprocess.run(args, capture_output=True, timeout=timeout, check=False)
    if result.returncode:
        raise ValueError("Preview could not be generated for this file.")
    return result.stdout


def preview(path, cache, request_id, page=1):
    # Retain a few recent thumbnails so a long browsing session stays bounded.
    cached = sorted(Path(cache).iterdir(), key=lambda item: item.stat().st_mtime)
    for old in cached[:-12]:
        old.unlink(missing_ok=True)
    info = path.stat()
    mime = mimetypes.guess_type(str(path))[0] or "application/octet-stream"
    result = {"name": path.name or "/", "url": path.as_uri(), "mime": mime,
              "size": info.st_size, "modified": datetime.datetime.fromtimestamp(
                  info.st_mtime).strftime("%Y-%m-%d %H:%M"),
              "permissions": stat.filemode(info.st_mode), "kind": "other"}
    if stat.S_ISDIR(info.st_mode):
        result.update(kind="directory", message="Select a folder in the next column to continue.")
        return result
    if not stat.S_ISREG(info.st_mode):
        result["message"] = "This special file has no inline preview."
        return result
    if mime.startswith("image/"):
        result["kind"] = "image"
    elif mime == "application/pdf":
        result.update(kind="pdf", page=max(1, int(page)), pages=1)
        if not shutil.which("pdftoppm") or not shutil.which("pdfinfo"):
            result["message"] = "PDF preview requires pdftoppm and pdfinfo (Poppler)."
            return result
        if info.st_size > 100 * 1024 * 1024:
            result["message"] = "Inline PDF preview is limited to 100 MiB."
            return result
        metadata = run(["pdfinfo", str(path)]).decode("utf-8", "replace")
        for line in metadata.splitlines():
            if line.startswith("Pages:"):
                result["pages"] = int(line.split(":", 1)[1])
        result["page"] = min(result["page"], result["pages"])
        prefix = str(Path(cache) / str(request_id))
        run(["pdftoppm", "-f", str(result["page"]), "-singlefile", "-scale-to", "1200",
             "-png", str(path), prefix])
        result["image"] = Path(prefix + ".png").as_uri()
    elif mime.startswith(("video/", "audio/")):
        result["kind"] = mime.split("/")[0]
        if shutil.which("ffprobe"):
            try:
                data = json.loads(run(["ffprobe", "-v", "error", "-show_format", "-show_streams",
                                       "-of", "json", str(path)]))
                result["duration"] = float(data.get("format", {}).get("duration", 0))
                video = next((s for s in data.get("streams", []) if s["codec_type"] == "video"), {})
                if "width" in video:
                    result["dimensions"] = f'{video["width"]} × {video["height"]}'
            except (ValueError, subprocess.TimeoutExpired):
                pass
        if result["kind"] == "video" and shutil.which("ffmpeg"):
            image = Path(cache) / f"{request_id}.jpg"
            try:
                run(["ffmpeg", "-v", "error", "-nostdin", "-i", str(path), "-frames:v", "1",
                     "-vf", "scale=960:540:force_original_aspect_ratio=decrease", "-y", str(image)])
                result["image"] = image.as_uri()
            except (ValueError, subprocess.TimeoutExpired):
                result["message"] = "Thumbnail unavailable. Use Play to preview this video."
    else:
        # A file may change between stat and open. Nonblocking open plus fstat
        # prevents a replaced FIFO or device from hanging the preview worker.
        descriptor = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
        with os.fdopen(descriptor, "rb") as file:
            if not stat.S_ISREG(os.fstat(file.fileno()).st_mode):
                result["message"] = "This special file has no inline preview."
                return result
            raw = file.read(MAX_TEXT + 1)
        if b"\0" in raw:
            result["message"] = "No inline preview for this binary format."
        else:
            try:
                text = raw[:MAX_TEXT].decode("utf-8")
            except UnicodeDecodeError:
                # A multibyte character can straddle the bounded read.
                text = raw[:MAX_TEXT].decode("utf-8", "replace")
            result.update(kind="markdown" if path.suffix.lower() in (".md", ".markdown") else "text",
                          text=text, truncated=len(raw) > MAX_TEXT)
    return result


def handle(request, cache):
    result = {"id": request.get("id"), "op": request.get("op")}
    try:
        path = location(request.get("path", ""))
        result["path"] = str(path)
        if request["op"] == "list":
            result.update(listing(path, request.get("hidden", False)))
        elif request["op"] == "preview":
            result.update(preview(path, cache, request["id"], request.get("page", 1)))
        else:
            raise ValueError("Unknown file request.")
    except (OSError, ValueError, KeyError, subprocess.TimeoutExpired) as error:
        result["error"] = str(error)
    with output_lock:
        print(json.dumps(result, ensure_ascii=True), flush=True)


def main():
    # Quickshell terminates children when the view closes; unwind the cache too.
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    with tempfile.TemporaryDirectory(prefix="lcars-files-") as cache:
        # Directory reads stay responsive while a separate worker renders previews.
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as directories, \
                concurrent.futures.ThreadPoolExecutor(max_workers=1) as previews:
            pending_preview = None
            for line in sys.stdin:
                try:
                    request = json.loads(line)
                    if not isinstance(request, dict):
                        continue
                except ValueError:
                    continue
                worker = directories if request.get("op") == "list" else previews
                if worker is previews:
                    # Keep only the newest pending selection while a render finishes.
                    if pending_preview is not None:
                        pending_preview.cancel()
                    pending_preview = worker.submit(handle, request, cache)
                else:
                    worker.submit(handle, request, cache)


if __name__ == "__main__":
    main()
