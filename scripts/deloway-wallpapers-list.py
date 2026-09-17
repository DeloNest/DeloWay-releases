#!/usr/bin/env python3
"""
Deloway Wallpapers Scanner
Scans system and user directories for wallpaper images and prints a JSON list.
"""

import os
import json
import glob
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent

SEARCH_DIRS = [
    (str(PROJECT_ROOT / "assets"), "Deloway Presets"),
    (os.path.expanduser("~/Wallpapers"), "Wallpapers"),
    (os.path.expanduser("~/Pictures/Wallpapers"), "Wallpapers"),
    ("/usr/share/backgrounds", "System Backgrounds"),
    (os.path.expanduser("~/Pictures"), "Pictures"),
    (os.path.expanduser("~/Downloads"), "Downloads"),
]

VALID_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".jxl"}

def scan():
    results = []
    seen_paths = set()

    for dir_path, category in SEARCH_DIRS:
        if not os.path.exists(dir_path):
            continue
        try:
            entries = os.scandir(dir_path)
            for entry in entries:
                if entry.is_file():
                    ext = Path(entry.name).suffix.lower()
                    if ext in VALID_EXTS:
                        full_path = os.path.abspath(entry.path)
                        if full_path in seen_paths:
                            continue
                        seen_paths.add(full_path)
                        
                        try:
                            st = entry.stat()
                            is_wallpaper_dir = "Wallpapers" in dir_path or "Deloway/assets" in full_path
                            min_size = 5 * 1024 if is_wallpaper_dir else 50 * 1024
                            if st.st_size < min_size:
                                continue
                        except Exception:
                            continue

                        raw_name = Path(entry.name).stem.replace("_", " ").replace("-", " ").strip().title()
                        name = raw_name if raw_name else Path(entry.name).name
                        results.append({
                            "name": name,
                            "path": full_path,
                            "category": category,
                            "filename": entry.name
                        })
        except Exception:
            continue

    # Sort Deloway assets first, then by name
    results.sort(key=lambda x: (0 if "Deloway/assets" in x["path"] else 1, x["name"]))
    print(json.dumps(results[:30], ensure_ascii=False))

if __name__ == "__main__":
    scan()
