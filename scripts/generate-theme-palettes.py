#!/usr/bin/env python3
"""
DeloWay Theme Generator & Single Source of Truth Synchronizer
============================================================
Theme.qml is the canonical single source of truth for all three DeloWay themes:
  - deloos-dark  (OLED Dark Monochrome)
  - deloos-light (High-Contrast Neutral Light)
  - deloos-glass (Translucent Dark with Glass tokens)

This script parses Theme.qml, extracts the color and ANSI palettes, and
generates/verifies the corresponding theme JSON files in shell/theme/themes/.

Usage:
  python3 scripts/generate-theme-palettes.py          # Generate / update JSON files
  python3 scripts/generate-theme-palettes.py --check  # Verify zero drift (exit 1 on mismatch)
"""

import sys
import re
import json
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
THEME_QML_PATH = PROJECT_ROOT / "shell" / "theme" / "Theme.qml"
THEMES_DIR = PROJECT_ROOT / "shell" / "theme" / "themes"

SHARED_LAYOUT_TOKENS = {
    "radius": {
        "small": 4,
        "medium": 8,
        "large": 12,
        "xlarge": 16,
        "pill": 9999
    },
    "spacing": {
        "xsmall": 4,
        "small": 8,
        "medium": 12,
        "large": 16,
        "xlarge": 24
    },
    "typography": {
        "fontFamily": "SF Pro Display",
        "terminalFont": "JetBrainsMono Nerd Font",
        "fontSizeSmall": 11,
        "fontSizeRegular": 13,
        "fontSizeMedium": 15,
        "fontSizeLarge": 18,
        "fontSizeTitle": 22
    }
}

def extract_qml_object(qml_content: str, prop_name: str) -> dict:
    """Extract a JavaScript object literal property from QML as a Python dict."""
    pattern = rf"readonly\s+property\s+var\s+{prop_name}:\s*\(\s*(\{{.*?\}})\s*\)"
    match = re.search(pattern, qml_content, re.DOTALL)
    if not match:
        raise ValueError(f"Could not find property '{prop_name}' in {THEME_QML_PATH}")
    raw_js = match.group(1)
    # Strip line comments
    clean_js = re.sub(r"//.*", "", raw_js)
    return json.loads(clean_js)

def parse_theme_qml():
    """Extract all palettes from Theme.qml."""
    content = THEME_QML_PATH.read_text(encoding="utf-8")
    palettes = {
        "dark": {
            "colors": extract_qml_object(content, "darkPalette"),
            "ansi": extract_qml_object(content, "darkAnsi"),
        },
        "light": {
            "colors": extract_qml_object(content, "lightPalette"),
            "ansi": extract_qml_object(content, "lightAnsi"),
        },
        "glass": {
            "colors": extract_qml_object(content, "glassPalette"),
            "ansi": extract_qml_object(content, "glassAnsi"),
        },
    }
    return palettes

def build_theme_dict(theme_name: str, mode: str, colors: dict, ansi: dict) -> dict:
    return {
        "theme": theme_name,
        "mode": mode,
        "colors": colors,
        "ansi": ansi,
        "radius": SHARED_LAYOUT_TOKENS["radius"],
        "spacing": SHARED_LAYOUT_TOKENS["spacing"],
        "typography": SHARED_LAYOUT_TOKENS["typography"]
    }

def generate_palettes(check_only: bool = False) -> int:
    palettes = parse_theme_qml()

    targets = [
        ("deloos-dark", "dark", palettes["dark"], THEMES_DIR / "deloos-dark.json"),
        ("deloos-light", "light", palettes["light"], THEMES_DIR / "deloos-light.json"),
        ("deloos-glass", "glass", palettes["glass"], THEMES_DIR / "deloos-glass.json"),
    ]

    drift_found = False

    for theme_name, mode, data, file_path in targets:
        theme_json_obj = build_theme_dict(theme_name, mode, data["colors"], data["ansi"])
        formatted_json = json.dumps(theme_json_obj, indent=2, ensure_ascii=False) + "\n"

        if check_only:
            if not file_path.exists():
                print(f"❌ Drift Error: {file_path.name} does not exist!")
                drift_found = True
                continue
            existing_content = file_path.read_text(encoding="utf-8")
            try:
                existing_obj = json.loads(existing_content)
                # Compare colors and ansi
                if existing_obj.get("colors") != data["colors"]:
                    print(f"❌ Drift Error in {file_path.name}: 'colors' block does not match Theme.qml!")
                    drift_found = True
                if existing_obj.get("ansi") != data["ansi"]:
                    print(f"❌ Drift Error in {file_path.name}: 'ansi' block does not match Theme.qml!")
                    drift_found = True
            except json.JSONDecodeError as e:
                print(f"❌ Drift Error in {file_path.name}: Invalid JSON ({e})")
                drift_found = True
        else:
            THEMES_DIR.mkdir(parents=True, exist_ok=True)
            file_path.write_text(formatted_json, encoding="utf-8")
            print(f"✔ Generated: {file_path.relative_to(PROJECT_ROOT)}")

    if check_only:
        if drift_found:
            print("✘ Theme drift detected between Theme.qml and theme JSON files.")
            print("  Run 'python3 scripts/generate-theme-palettes.py' to regenerate.")
            return 1
        else:
            print("✔ Theme drift check: 100% synchronized with Theme.qml (Dark, Light, Glass).")
            return 0

    return 0

if __name__ == "__main__":
    check_mode = "--check" in sys.argv
    sys.exit(generate_palettes(check_only=check_mode))
