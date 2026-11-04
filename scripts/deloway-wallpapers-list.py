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
    (str(PROJECT_ROOT / "assets" / "wallpapers"), "Deloway Wallpapers"),
    (str(PROJECT_ROOT / "Wallpapers"), "Deloway Wallpapers"),
    (os.path.expanduser("~/Wallpapers"), "Wallpapers"),
    (os.path.expanduser("~/Pictures/Wallpapers"), "Wallpapers"),
    ("/usr/share/backgrounds", "System Backgrounds"),
    (os.path.expanduser("~/Pictures"), "Pictures"),
    (os.path.expanduser("~/Downloads"), "Downloads"),
]

VALID_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".jxl"}

PRESET_TITLES = {
    "01-noir-gradient.jpeg": ("Noir Gradient", "تدرج أسود"),
    "02-monochrome-mesh.jpeg": ("Monochrome Mesh", "شبكة أحادية"),
    "03-silk-flow.jpeg": ("Silk Flow", "تموج الحرير"),
    "04-fluid-dunes.jpeg": ("Fluid Dunes", "كثبان انسيابية"),
    "05-midnight-curve.jpeg": ("Midnight Curve", "منحنى منتصف الليل"),
    "06-night-horizon.jpeg": ("Night Horizon", "أفق ليلي"),
    "_.jpeg": ("Noir Gradient", "تدرج أسود"),
    "_ (1).jpeg": ("Monochrome Mesh", "شبكة أحادية"),
    "_ (2).jpeg": ("Silk Flow", "تموج الحرير"),
    "_ (3).jpeg": ("Fluid Dunes", "كثبان انسيابية"),
    "_ (4).jpeg": ("Midnight Curve", "منحنى منتصف الليل"),
    "_ (5).jpeg": ("Night Horizon", "أفق ليلي"),
}

def scan():
    results = []
    seen_paths = set()
    seen_real_paths = set()

    for dir_path, category in SEARCH_DIRS:
        if not os.path.exists(dir_path):
            continue
        try:
            entries = sorted(os.scandir(dir_path), key=lambda e: e.name)
            for entry in entries:
                if entry.is_file():
                    ext = Path(entry.name).suffix.lower()
                    if ext in VALID_EXTS:
                        # Skip raw download aliases (e.g. _.jpeg) in favor of clean named files
                        if entry.name.startswith("_"):
                            continue

                        full_path = os.path.abspath(entry.path)
                        real_path = os.path.realpath(entry.path)

                        if full_path in seen_paths or real_path in seen_real_paths:
                            continue

                        try:
                            st = entry.stat()
                            is_wallpaper_dir = "Wallpapers" in dir_path or "assets/wallpapers" in full_path
                            min_size = 5 * 1024 if is_wallpaper_dir else 50 * 1024
                            if st.st_size < min_size:
                                continue
                        except Exception:
                            continue

                        seen_paths.add(full_path)
                        seen_real_paths.add(real_path)

                        if entry.name in PRESET_TITLES:
                            name, name_ar = PRESET_TITLES[entry.name]
                        else:
                            raw_stem = Path(entry.name).stem
                            # Clean leading numbers like 01- or 01_
                            if len(raw_stem) > 3 and raw_stem[:2].isdigit() and raw_stem[2] in "-_ ":
                                raw_stem = raw_stem[3:]
                            raw_name = raw_stem.replace("_", " ").replace("-", " ").strip().title()
                            name = raw_name if raw_name else Path(entry.name).name
                            name_ar = ""

                        results.append({
                            "name": name,
                            "name_ar": name_ar,
                            "path": full_path,
                            "category": category,
                            "filename": entry.name
                        })
        except Exception:
            continue

    # Sort Deloway presets first in clean order, then user wallpapers by name
    def sort_key(item):
        is_deloway = 0 if ("Deloway" in item.get("category", "") or "assets/wallpapers" in item["path"]) else 1
        fn = item.get("filename", "")
        return (is_deloway, fn if is_deloway == 0 else item["name"])

    results.sort(key=sort_key)
    print(json.dumps(results[:30], ensure_ascii=False))

if __name__ == "__main__":
    scan()
