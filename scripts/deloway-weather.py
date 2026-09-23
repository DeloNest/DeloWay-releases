#!/usr/bin/env python3
import json, urllib.request, sys

try:
    with urllib.request.urlopen("https://wttr.in/?format=j1", timeout=3) as r:
        d = json.loads(r.read().decode())
        c = d["current_condition"][0]
        a = d["nearest_area"][0]
        res = {
            "city": a["areaName"][0]["value"],
            "tempC": c["temp_C"],
            "desc": c["weatherDesc"][0]["value"],
            "humidity": c["humidity"],
            "wind": c["windspeedKmph"],
            "uv": c.get("uvIndex", "1")
        }
except Exception:
    # Offline / service down: say so instead of printing plausible fake weather.
    res = {"ok": False}

print(json.dumps(res))
