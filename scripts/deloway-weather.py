#!/usr/bin/env python3
import json, urllib.request, sys
from deloway_config import ui_language

# The description in the shell's language: wttr.in adds lang_<code> for ?lang=<code>.
lang = ui_language()

try:
    with urllib.request.urlopen(f"https://wttr.in/?format=j1&lang={lang}", timeout=3) as r:
        d = json.loads(r.read().decode())
        c = d["current_condition"][0]
        a = d["nearest_area"][0]
        desc = (c.get(f"lang_{lang}") or c["weatherDesc"])[0]["value"]
        res = {
            "city": a["areaName"][0]["value"],
            "tempC": c["temp_C"],
            "desc": desc,
            "humidity": c["humidity"],
            "wind": c["windspeedKmph"],
            "uv": c.get("uvIndex", "1")
        }
except Exception:
    # Offline / service down: say so instead of printing plausible fake weather.
    res = {"ok": False}

print(json.dumps(res))
