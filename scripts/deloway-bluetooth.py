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

def main():
    if len(sys.argv) < 2 or sys.argv[1] == "list":
        print(json.dumps({
            "powered": is_powered(),
            "devices": get_devices()
        }))
    elif sys.argv[1] == "toggle":
        curr = is_powered()
        adapter = get_adapter_path()
        subprocess.run(["busctl", "set-property", "org.bluez", adapter, "org.bluez.Adapter1", "Powered", "b", "false" if curr else "true"])
        print(json.dumps({"success": True, "powered": not curr}))
    elif sys.argv[1] == "scan":
        adapter = get_adapter_path()
        try:
            subprocess.run(["busctl", "call", "org.bluez", adapter, "org.bluez.Adapter1", "StartDiscovery"], timeout=3)
            print(json.dumps({"success": True}))
        except Exception as e:
            print(json.dumps({"success": False, "error": str(e)}))
    elif sys.argv[1] == "connect" and len(sys.argv) > 2:
        addr = sys.argv[2].replace(":", "_")
        adapter = get_adapter_path()
        dev_path = f"{adapter}/dev_{addr}"
        try:
            subprocess.run(["busctl", "call", "org.bluez", dev_path, "org.bluez.Device1", "Connect"], timeout=10)
            print(json.dumps({"success": True}))
        except Exception as e:
            print(json.dumps({"success": False, "error": str(e)}))
    elif sys.argv[1] == "disconnect" and len(sys.argv) > 2:
        addr = sys.argv[2].replace(":", "_")
        adapter = get_adapter_path()
        dev_path = f"{adapter}/dev_{addr}"
        try:
            subprocess.run(["busctl", "call", "org.bluez", dev_path, "org.bluez.Device1", "Disconnect"], timeout=5)
            print(json.dumps({"success": True}))
        except Exception as e:
            print(json.dumps({"success": False, "error": str(e)}))

if __name__ == "__main__":
    main()
