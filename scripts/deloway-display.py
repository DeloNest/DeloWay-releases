#!/usr/bin/env python3
"""
DeloWay Display & Monitor Management Helper
Queries monitor EDID, modes, refresh rates, HDR capability, and Hyprland display state.
Applies resolution, refresh rate, HDR, scaling, orientation, and multi-monitor layout.
"""

import sys
import os
import json
import subprocess
import glob
import math
import argparse
from pathlib import Path

CONFIG_DIR = Path.home() / ".config" / "deloway"
CONFIG_FILE = CONFIG_DIR / "display.json"


def get_edid_hdr(connector_name):
    """
    Parses CTA-861 extension block of the monitor's EDID from sysfs
    to detect hardware HDR10 (SMPTE ST 2084) and HLG capabilities.
    """
    patterns = [
        f"/sys/class/drm/*-{connector_name}/edid",
        f"/sys/class/drm/{connector_name}/edid",
    ]
    for pattern in patterns:
        for path in glob.glob(pattern):
            try:
                with open(path, "rb") as f:
                    data = f.read()
                if len(data) < 256:
                    continue
                # Block 1 is the CTA-861 Extension
                cta = data[128:256]
                if cta[0] != 0x02:
                    continue
                dtd_start = cta[2]
                pos = 4
                while pos < dtd_start:
                    header = cta[pos]
                    tag = (header >> 5) & 0x7
                    length = header & 0x1F
                    if tag == 7 and length >= 2:  # Extended tag
                        ext_tag = cta[pos + 1]
                        if ext_tag == 6:  # HDR Static Metadata Data Block
                            eotf = cta[pos + 2]
                            has_hdr10 = bool(eotf & 0x04)  # SMPTE ST 2084
                            has_hlg = bool(eotf & 0x08)    # HLG
                            return {
                                "supported": has_hdr10 or has_hlg,
                                "hdr10": has_hdr10,
                                "hlg": has_hlg,
                                "eotf": eotf
                            }
                    pos += 1 + length
            except Exception:
                continue
    return {"supported": False, "hdr10": False, "hlg": False, "eotf": 0}


def get_hypr_option(name):
    try:
        res = subprocess.run(["hyprctl", "getoption", name, "-j"], capture_output=True, text=True, timeout=2)
        if res.returncode == 0:
            return json.loads(res.stdout)
    except Exception:
        pass
    return {}


def format_aspect_ratio(w, h):
    gcd = math.gcd(w, h)
    if gcd > 0:
        rw, rh = w // gcd, h // gcd
        ratio_map = {
            (16, 9): "16:9",
            (16, 10): "16:10",
            (4, 3): "4:3",
            (5, 4): "5:4",
            (21, 9): "21:9",
            (32, 9): "32:9",
            (64, 27): "21:9",
            (43, 18): "21:9",
        }
        if (rw, rh) in ratio_map:
            return ratio_map[(rw, rh)]
        return f"{rw}:{rh}"
    return f"{w}:{h}"


def get_display_info():
    """
    Queries Hyprland monitors and hardware EDID, returning structured data.
    """
    try:
        res = subprocess.run(["hyprctl", "monitors", "all", "-j"], capture_output=True, text=True, timeout=3)
        monitors_raw = json.loads(res.stdout) if res.returncode == 0 else []
    except Exception:
        monitors_raw = []

    prefer_hdr_opt = get_hypr_option("quirks:prefer_hdr")
    auto_hdr_opt = get_hypr_option("render:cm_auto_hdr")
    vrr_opt = get_hypr_option("misc:vrr")

    hdr_active = bool(prefer_hdr_opt.get("int", 0) == 1 and auto_hdr_opt.get("int", 0) > 0)
    vrr_active = bool(vrr_opt.get("int", 0) > 0)

    saved_cfg = {}
    if CONFIG_FILE.exists():
        try:
            with open(CONFIG_FILE, "r") as f:
                saved_cfg = json.load(f)
        except Exception:
            pass

    display_list = []
    primary_name = saved_cfg.get("__meta__", {}).get("primary", "")
    if not primary_name and monitors_raw:
        # Default to first focused or first monitor
        for m in monitors_raw:
            if m.get("focused", False):
                primary_name = m.get("name", "")
                break
        if not primary_name and monitors_raw:
            primary_name = monitors_raw[0].get("name", "")

    for m in monitors_raw:
        connector = m.get("name", "")
        edid_hdr = get_edid_hdr(connector)

        modes = m.get("availableModes", [])
        res_map = {}
        for mode in modes:
            try:
                parts = mode.replace("Hz", "").split("@")
                res_str = parts[0]
                rate = float(parts[1])
                w, h = [int(x) for x in res_str.split("x")]

                if res_str not in res_map:
                    res_map[res_str] = {
                        "id": res_str,
                        "width": w,
                        "height": h,
                        "rates": [],
                    }
                r_rounded = round(rate, 2)
                if r_rounded not in res_map[res_str]["rates"]:
                    res_map[res_str]["rates"].append(r_rounded)
            except Exception:
                continue

        resolutions = sorted(res_map.values(), key=lambda r: r["width"] * r["height"], reverse=True)
        max_pixels = (resolutions[0]["width"] * resolutions[0]["height"]) if resolutions else 0

        for r in resolutions:
            r["rates"].sort(reverse=True)
            w, h = r["width"], r["height"]
            ratio = format_aspect_ratio(w, h)

            name = ""
            if w >= 3840 and h >= 2160:
                name = "4K UHD"
            elif w == 2560 and h == 1440:
                name = "2K QHD"
            elif w == 1920 and h == 1080:
                name = "FHD"
            elif w == 1280 and h == 720:
                name = "HD"

            label = f"{w} × {h}"
            if name:
                label += f" ({name} · {ratio})"
            else:
                label += f" ({ratio})"

            is_native = bool(w * h == max_pixels)
            r["label"] = label
            r["aspectRatio"] = ratio
            r["isNative"] = is_native

        active_res_id = f"{m.get('width', 0)}x{m.get('height', 0)}"
        is_primary = (connector == primary_name)

        display_list.append({
            "id": m.get("id", 0),
            "name": connector,
            "description": m.get("description", connector),
            "make": m.get("make", ""),
            "model": m.get("model", ""),
            "serial": m.get("serial", ""),
            "width": m.get("width", 0),
            "height": m.get("height", 0),
            "currentResolution": active_res_id,
            "refreshRate": round(m.get("refreshRate", 60.0), 2),
            "scale": m.get("scale", 1.0),
            "transform": m.get("transform", 0),
            "x": m.get("x", 0),
            "y": m.get("y", 0),
            "isPrimary": is_primary,
            "mirrorOf": m.get("mirrorOf", "none"),
            "vrr": bool(m.get("vrr", False) or vrr_active),
            "hdrSupported": edid_hdr["supported"],
            "hdrDetails": edid_hdr,
            "hdrEnabled": hdr_active,
            "currentFormat": m.get("currentFormat", ""),
            "resolutions": resolutions,
            "focused": m.get("focused", False),
            "physicalWidth": m.get("physicalWidth", 0),
            "physicalHeight": m.get("physicalHeight", 0),
        })

    return {
        "monitors": display_list,
        "isMultiMonitor": len(display_list) > 1,
        "primaryMonitor": primary_name,
        "hdrActive": hdr_active,
        "vrrActive": vrr_active,
        "savedConfig": saved_cfg,
    }


def apply_display_settings(args):
    """
    Applies display configuration to Hyprland via hyprctl keyword and saves it.
    """
    output = args.name
    width = int(args.width)
    height = int(args.height)
    rate = float(args.rate)
    scale = float(args.scale)
    transform = int(args.transform)
    hdr = args.hdr
    vrr = args.vrr
    offset = args.offset or "0x0"
    mirror = args.mirror
    make_primary = bool(args.primary)

    # Check EDID HDR capability for this output
    edid = get_edid_hdr(output)
    can_hdr = edid["supported"]
    enable_hdr = bool(hdr == 1 and can_hdr)

    # Build Hyprland monitor command
    bitdepth_part = ",bitdepth,10" if enable_hdr else ""
    transform_part = f",transform,{transform}" if transform > 0 else ""

    if mirror and mirror != "none":
        monitor_spec = f"{output},preferred,auto,{scale},mirror,{mirror}"
    else:
        monitor_spec = f"{output},{width}x{height}@{rate},{offset},{scale}{transform_part}{bitdepth_part}"

    cmd = ["hyprctl", "keyword", "monitor", monitor_spec]
    res = subprocess.run(cmd, capture_output=True, text=True)

    if hdr is not None:
        if enable_hdr:
            subprocess.run(["hyprctl", "keyword", "quirks:prefer_hdr", "1"], capture_output=True)
            subprocess.run(["hyprctl", "keyword", "render:cm_auto_hdr", "2"], capture_output=True)
        else:
            subprocess.run(["hyprctl", "keyword", "quirks:prefer_hdr", "0"], capture_output=True)
            subprocess.run(["hyprctl", "keyword", "render:cm_auto_hdr", "0"], capture_output=True)

    if vrr is not None:
        vrr_val = "1" if vrr == 1 else "0"
        subprocess.run(["hyprctl", "keyword", "misc:vrr", vrr_val], capture_output=True)

    # Persist config
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    saved = {}
    if CONFIG_FILE.exists():
        try:
            with open(CONFIG_FILE, "r") as f:
                saved = json.load(f)
        except Exception:
            pass

    if "__meta__" not in saved:
        saved["__meta__"] = {}

    if make_primary:
        saved["__meta__"]["primary"] = output

    saved[output] = {
        "width": width,
        "height": height,
        "rate": rate,
        "scale": scale,
        "transform": transform,
        "offset": offset,
        "mirror": mirror or "none",
        "hdr": enable_hdr,
        "vrr": bool(vrr == 1) if vrr is not None else saved.get(output, {}).get("vrr", False),
    }

    try:
        with open(CONFIG_FILE, "w") as f:
            json.dump(saved, f, indent=2)
    except Exception:
        pass

    return {
        "status": "ok",
        "monitorSpec": monitor_spec,
        "hyprctlReturn": res.stdout.strip(),
        "hdrEnabled": enable_hdr,
    }


def main():
    parser = argparse.ArgumentParser(description="DeloWay Display Controller")
    subparsers = parser.add_subparsers(dest="action")

    subparsers.add_parser("info", help="Get display info as JSON")

    apply_p = subparsers.add_parser("apply", help="Apply display settings")
    apply_p.add_argument("--name", required=True, help="Monitor output name (e.g. DP-1)")
    apply_p.add_argument("--width", type=int, required=True, help="Resolution width")
    apply_p.add_argument("--height", type=int, required=True, help="Resolution height")
    apply_p.add_argument("--rate", type=float, required=True, help="Refresh rate (Hz)")
    apply_p.add_argument("--scale", type=float, default=1.0, help="Display scale factor")
    apply_p.add_argument("--transform", type=int, default=0, help="Transform rotation (0..3)")
    apply_p.add_argument("--offset", type=str, default="0x0", help="Offset placement (e.g. 0x0, auto-right)")
    apply_p.add_argument("--mirror", type=str, default=None, help="Target monitor name to mirror")
    apply_p.add_argument("--primary", action="store_true", help="Set this display as primary")
    apply_p.add_argument("--hdr", type=int, choices=[0, 1], default=None, help="Enable or disable HDR")
    apply_p.add_argument("--vrr", type=int, choices=[0, 1], default=None, help="Enable or disable VRR")

    args = parser.parse_args()

    if args.action == "apply":
        result = apply_display_settings(args)
    else:
        result = get_display_info()

    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
