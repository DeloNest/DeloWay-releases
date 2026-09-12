#!/usr/bin/env python3
"""
Deloway Keyboard & Language Helper
Queries and manages keyboard layouts and active layout state via Hyprland.
"""
import sys
import json
import subprocess

KNOWN_LAYOUTS = {
    "us": {"id": "us", "name": "English (US)", "native": "English (US)", "code": "EN"},
    "ara": {"id": "ara", "name": "Arabic", "native": "العربية", "code": "AR"},
    "fr": {"id": "fr", "name": "French", "native": "Français", "code": "FR"},
    "de": {"id": "de", "name": "German", "native": "Deutsch", "code": "DE"},
    "es": {"id": "es", "name": "Spanish", "native": "Español", "code": "ES"},
    "tr": {"id": "tr", "name": "Turkish", "native": "Türkçe", "code": "TR"},
    "ru": {"id": "ru", "name": "Russian", "native": "Русский", "code": "RU"},
    "it": {"id": "it", "name": "Italian", "native": "Italiano", "code": "IT"}
}

def get_status():
    try:
        raw = subprocess.run(["hyprctl", "devices", "-j"], capture_output=True, text=True, timeout=2).stdout
        data = json.loads(raw)
        keyboards = data.get("keyboards", [])
        main_kb = next((k for k in keyboards if k.get("main")), None) or (keyboards[0] if keyboards else {})
        active = main_kb.get("active_keymap", "English (US)")
        active_idx = main_kb.get("active_layout_index", 0)
        
        raw_layout_str = main_kb.get("layout", "us,ara")
        current_codes = [c.strip() for c in raw_layout_str.split(",") if c.strip()]
        if not current_codes:
            current_codes = ["us", "ara"]

        installed = []
        for c in current_codes:
            if c in KNOWN_LAYOUTS:
                installed.append(KNOWN_LAYOUTS[c])
            else:
                installed.append({"id": c, "name": c.upper(), "native": c.upper(), "code": c.upper()[:2]})

        available = []
        for c, info in KNOWN_LAYOUTS.items():
            if c not in current_codes:
                available.append(info)

        code = "AR" if ("arab" in active.lower() or "ara" in active.lower()) else ("EN" if "engl" in active.lower() else active[:2].upper())
        if active_idx < len(installed):
            code = installed[active_idx].get("code", code)

        return {
            "active": active,
            "code": code,
            "active_index": active_idx,
            "installed": installed,
            "available": available,
            "layouts": [f"{item['name']} ({item['native']})" if item['name'] != item['native'] else item['name'] for item in installed],
            "shortcut": "Shift + Alt (Windows Standard)",
            "locale": "en_US.UTF-8"
        }
    except Exception as e:
        return {
            "active": "English (US)",
            "code": "EN",
            "active_index": 0,
            "installed": [KNOWN_LAYOUTS["us"], KNOWN_LAYOUTS["ara"]],
            "available": [KNOWN_LAYOUTS["fr"], KNOWN_LAYOUTS["de"], KNOWN_LAYOUTS["es"]],
            "layouts": ["English (US)", "Arabic (العربية)"],
            "shortcut": "Shift + Alt (Windows Standard)",
            "locale": "en_US.UTF-8",
            "error": str(e)
        }

def switch_layout():
    try:
        subprocess.run(["hyprctl", "switchxkblayout", "all", "next"], capture_output=True, text=True, timeout=2)
        return get_status()
    except Exception as e:
        return {"error": str(e)}

def set_layouts(codes):
    try:
        if not codes:
            codes = ["us"]
        layout_str = ",".join(codes)
        subprocess.run(["hyprctl", "keyword", "input:kb_layout", layout_str], capture_output=True, text=True, timeout=2)
        subprocess.run(["hyprctl", "keyword", "input:kb_options", "grp:alt_shift_toggle"], capture_output=True, text=True, timeout=2)
        return get_status()
    except Exception as e:
        return {"error": str(e)}

def add_layout(code):
    st = get_status()
    current_codes = [item["id"] for item in st.get("installed", [])]
    if code and code not in current_codes:
        current_codes.append(code)
    return set_layouts(current_codes)

def remove_layout(code):
    st = get_status()
    current_codes = [item["id"] for item in st.get("installed", [])]
    if code in current_codes and len(current_codes) > 1:
        current_codes.remove(code)
    return set_layouts(current_codes)

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        print(json.dumps(get_status()))
    elif cmd == "switch":
        print(json.dumps(switch_layout()))
    elif cmd == "add" and len(sys.argv) > 2:
        print(json.dumps(add_layout(sys.argv[2])))
    elif cmd == "remove" and len(sys.argv) > 2:
        print(json.dumps(remove_layout(sys.argv[2])))
    elif cmd == "set" and len(sys.argv) > 2:
        codes = [c.strip() for c in sys.argv[2].split(",") if c.strip()]
        print(json.dumps(set_layouts(codes)))
    else:
        print(json.dumps(get_status()))

if __name__ == "__main__":
    main()
