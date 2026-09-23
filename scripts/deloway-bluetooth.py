#!/usr/bin/env python3
"""
Deloway Bluetooth Helper
Direct integration with system D-Bus (org.bluez) for device management without bluez-utils dependency.
"""
import sys
import re
import json
import subprocess

def get_adapter_path():
    try:
        tree = subprocess.run(["busctl", "tree", "org.bluez"], capture_output=True, text=True, timeout=2).stdout
        m = re.search(r"(/org/bluez/hci[0-9]+)", tree)
        return m.group(1) if m else "/org/bluez/hci0"
    except Exception:
        return "/org/bluez/hci0"

def get_devices():
    try:
        tree = subprocess.run(["busctl", "tree", "org.bluez"], capture_output=True, text=True, timeout=2).stdout
    except Exception:
        return []
    
    dev_paths = re.findall(r"(/org/bluez/hci[0-9]+/dev_[0-9A-Fa-f_]+)", tree)
    devices = []
    for path in dev_paths:
        try:
            info = subprocess.run(["busctl", "introspect", "org.bluez", path, "org.bluez.Device1"], capture_output=True, text=True, timeout=2).stdout
            name = ""
            alias = ""
            connected = False
            paired = False
            icon = "bluetooth-active-symbolic"
            
            for line in info.splitlines():
                if ".Name" in line and "property" in line:
                    m = re.search(r"\"(.*)\"", line)
                    if m: name = m.group(1)
                elif ".Alias" in line and "property" in line:
                    m = re.search(r"\"(.*)\"", line)
                    if m: alias = m.group(1)
                elif ".Connected" in line and "property" in line:
                    connected = "true" in line.lower()
                elif ".Paired" in line and "property" in line:
                    paired = "true" in line.lower()
                elif ".Icon" in line and "property" in line:
                    m = re.search(r"\"(.*)\"", line)
                    if m: icon = m.group(1)
            
            if "gaming" in icon or "gamepad" in icon or "joystick" in icon:
                icon_sym = "input-gaming-symbolic"
            elif "audio" in icon or "headset" in icon or "headphones" in icon:
                icon_sym = "audio-headphones-symbolic"
            elif "keyboard" in icon:
                icon_sym = "input-keyboard-symbolic"
            elif "mouse" in icon:
                icon_sym = "input-mouse-symbolic"
            elif "phone" in icon:
                icon_sym = "phone-symbolic"
            else:
                icon_sym = "bluetooth-active-symbolic"
                
            addr = path.split("dev_")[-1].replace("_", ":")
            devices.append({
                "address": addr,
                "name": alias or name or addr,
                "connected": connected,
                "paired": paired,
                "icon": icon_sym,
                "path": path
            })
        except Exception:
            pass
    return devices

def is_powered():
    adapter = get_adapter_path()
    try:
        res = subprocess.run(["busctl", "get-property", "org.bluez", adapter, "org.bluez.Adapter1", "Powered"], capture_output=True, text=True, timeout=2).stdout
        return "true" in res.lower()
    except Exception:
        return False

def busctl(args, timeout):
    """Run busctl and report the REAL outcome (it exits 1 with 'Call failed: …' on
    e.g. br-connection-page-timeout; ignoring that made every action look successful)."""
    try:
        r = subprocess.run(["busctl"] + args, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return {"success": False, "error": "timeout"}
    except OSError as e:
        return {"success": False, "error": str(e)}
    if r.returncode == 0:
        return {"success": True}
    return {"success": False, "error": (r.stderr or r.stdout).strip() or f"busctl exit {r.returncode}"}

def scan_discovery(adapter, seconds):
    """BlueZ ends a discovery session when the D-Bus client that started it leaves
    the bus; busctl leaves immediately, so discovery used to stop after ~100 ms.
    Hold one connection for the whole scan window, then stop discovery."""
    try:
        from gi.repository import Gio, GLib
    except ImportError:
        return busctl(["call", "org.bluez", adapter, "org.bluez.Adapter1", "StartDiscovery"], 3)
    try:
        bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        call = lambda m: bus.call_sync("org.bluez", adapter, "org.bluez.Adapter1", m,
                                       None, None, Gio.DBusCallFlags.NONE, 5000, None)
        call("StartDiscovery")
        GLib.usleep(int(seconds * 1_000_000))
        try:
            call("StopDiscovery")
        except GLib.Error:
            pass
        return {"success": True}
    except Exception as e:
        return {"success": False, "error": str(getattr(e, "message", e))}

def device_path(adapter, mac):
    return f"{adapter}/dev_{mac.replace(':', '_')}"

def main():
    if len(sys.argv) < 2 or sys.argv[1] == "list":
        print(json.dumps({
            "powered": is_powered(),
            "devices": get_devices()
        }))
        return
    verb = sys.argv[1]
    adapter = get_adapter_path()
    if verb == "toggle":
        curr = is_powered()
        res = busctl(["set-property", "org.bluez", adapter, "org.bluez.Adapter1", "Powered", "b",
                      "false" if curr else "true"], 5)
        res["powered"] = (not curr) if res["success"] else curr
    elif verb == "scan":
        res = scan_discovery(adapter, 12)
    elif verb in ("connect", "disconnect", "pair") and len(sys.argv) > 2:
        method = {"connect": "Connect", "disconnect": "Disconnect", "pair": "Pair"}[verb]
        timeout = {"connect": 10, "disconnect": 5, "pair": 15}[verb]
        res = busctl(["call", "org.bluez", device_path(adapter, sys.argv[2]), "org.bluez.Device1", method], timeout)
    elif verb == "remove" and len(sys.argv) > 2:
        res = busctl(["call", "org.bluez", adapter, "org.bluez.Adapter1", "RemoveDevice", "o",
                      device_path(adapter, sys.argv[2])], 5)
    else:
        res = {"success": False, "error": "usage: list|toggle|scan|connect|disconnect|pair|remove <mac>"}
    res["action"] = verb
    print(json.dumps(res))

if __name__ == "__main__":
    main()
