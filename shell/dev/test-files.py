#!/usr/bin/env python3
"""Exercise the read-only file service using disposable files only."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "files.py"
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("files", SCRIPT)
files = importlib.util.module_from_spec(spec)
spec.loader.exec_module(files)


class FileServiceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.cache = self.root / "cache"
        self.cache.mkdir()

    def preview(self, name, content):
        path = self.root / name
        path.write_bytes(content)
        return files.preview(path, str(self.cache), 1)

    def test_columns_sort_folders_first_and_hide_dotfiles(self):
        (self.root / "Zulu").mkdir()
        (self.root / "alpha.txt").touch()
        (self.root / ".hidden").touch()
        entries = files.listing(self.root)["entries"]
        self.assertEqual([e["name"] for e in entries], ["cache", "Zulu", "alpha.txt"])
        self.assertIn(".hidden", [e["name"] for e in files.listing(self.root, True)["entries"]])

    def test_unicode_and_shell_characters_are_literal_names(self):
        name = "航海 ' $(false) #?.txt"
        result = self.preview(name, "Hello π".encode())
        self.assertEqual(result["text"], "Hello π")
        self.assertEqual(result["name"], name)
        self.assertIn("%23%3F", result["url"])

    def test_text_and_markdown_are_bounded(self):
        result = self.preview("notes.md", b"# Log\n" + b"a" * files.MAX_TEXT)
        self.assertEqual(result["kind"], "markdown")
        self.assertTrue(result["truncated"])
        self.assertLessEqual(len(result["text"]), files.MAX_TEXT)

    def test_binary_and_special_files_are_not_read_as_text(self):
        self.assertEqual(self.preview("data.bin", b"\0\1\2")["kind"], "other")
        fifo = self.root / "pipe"
        os.mkfifo(fifo)
        self.assertEqual(files.preview(fifo, str(self.cache), 2)["kind"], "other")

    def test_symlink_directory_remains_navigable(self):
        (self.root / "linked").symlink_to(self.cache, target_is_directory=True)
        entry = next(e for e in files.listing(self.root)["entries"] if e["name"] == "linked")
        self.assertTrue(entry["directory"])
        self.assertTrue(entry["symlink"])

    def test_missing_directory_is_reported(self):
        with self.assertRaises(FileNotFoundError):
            files.listing(self.root / "missing")

    def test_large_directory_reports_limit(self):
        original = files.MAX_ENTRIES
        files.MAX_ENTRIES = 2
        self.addCleanup(setattr, files, "MAX_ENTRIES", original)
        for i in range(3):
            (self.root / str(i)).touch()
        result = files.listing(self.root)
        self.assertTrue(result["truncated"])
        self.assertEqual(len(result["entries"]), 2)

    def test_protocol_reports_errors_and_keeps_serving(self):
        requests = [{"id": 1, "op": "list", "path": str(self.root / "missing")},
                    {"id": 2, "op": "list", "path": str(self.root)}]
        result = subprocess.run([sys.executable, str(SCRIPT)],
                                input="\n".join(map(json.dumps, requests)) + "\n",
                                text=True, capture_output=True, timeout=5, check=True)
        replies = {r["id"]: r for r in map(json.loads, result.stdout.splitlines())}
        self.assertIn("error", replies[1])
        self.assertIn("entries", replies[2])

    @unittest.skipUnless(shutil.which("pdftoppm") and shutil.which("pdfinfo"), "Poppler unavailable")
    def test_pdf_page_preview(self):
        # A tiny valid two-page document; test actual rendering and page bounds.
        objects = [b"<< /Type /Catalog /Pages 2 0 R >>",
                   b"<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>",
                   b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] >>",
                   b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] >>"]
        document = b"%PDF-1.4\n"
        offsets = [0]
        for i, obj in enumerate(objects, 1):
            offsets.append(len(document))
            document += f"{i} 0 obj\n".encode() + obj + b"\nendobj\n"
        xref = len(document)
        document += b"xref\n0 5\n0000000000 65535 f \n"
        document += b"".join(f"{offset:010d} 00000 n \n".encode() for offset in offsets[1:])
        document += f"trailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF".encode()
        path = self.root / "pages.pdf"
        path.write_bytes(document)
        result = files.preview(path, str(self.cache), 5, page=99)
        self.assertEqual(result["page"], 2)
        self.assertEqual(result["pages"], 2)
        self.assertTrue((self.cache / "5.png").exists())

    @unittest.skipUnless(shutil.which("ffmpeg") and shutil.which("ffprobe"), "FFmpeg unavailable")
    def test_video_metadata_and_thumbnail(self):
        path = self.root / "clip.mp4"
        subprocess.run(["ffmpeg", "-v", "error", "-f", "lavfi", "-i", "color=c=orange:s=160x90:d=1",
                        "-c:v", "mpeg4", str(path)], check=True, timeout=10)
        result = files.preview(path, str(self.cache), 6)
        self.assertEqual(result["kind"], "video")
        self.assertGreater(result["duration"], 0)
        self.assertEqual(result["dimensions"], "160 × 90")
        self.assertTrue((self.cache / "6.jpg").exists())


if __name__ == "__main__":
    unittest.main()
