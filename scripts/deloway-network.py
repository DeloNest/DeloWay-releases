#!/usr/bin/env python3
"""
Deloway Network Helper
Handles Wi-Fi scanning, connection info, and Ethernet status via NetworkManager (nmcli).
"""
import sys
import json
import subprocess

def get_network_info():
    # Check Ethernet
    ethernet = {"connected": False, "device": "", "ip": "", "speed": ""}
    wifi = {"available": False, "enabled": False, "connected": False, "ssid": "", "networks": []}
    
    try:
        dev_res = subprocess.run(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "dev"], capture_output=True, text=True, timeout=2).stdout
        for line in dev_res.strip().splitlines():
            parts = line.split(":")
            if len(parts) >= 3:
                d, t, s = parts[0], parts[1], parts[2]
                if t == "ethernet" and "connected" in s:
                    ethernet["connected"] = True
                    ethernet["device"] = d
                elif t == "wifi":
                    wifi["available"] = True
                    if "connected" in s:
                        wifi["connected"] = True
    except Exception:
        pass

    # Get IP details
    try:
        ip_res = subprocess.run(["ip", "-j", "addr"], capture_output=True, text=True, timeout=2).stdout
        data = json.loads(ip_res)
        for iface in data:
            if iface.get("ifname") == ethernet["device"]:
                for addr_info in iface.get("addr_info", []):
                    if addr_info.get("family") == "inet":
                        ethernet["ip"] = addr_info.get("local", "")
    except Exception:
        pass

    # Wi-Fi radio status
    try:
        r_res = subprocess.run(["nmcli", "radio", "wifi"], capture_output=True, text=True, timeout=2).stdout.strip()
        wifi["enabled"] = (r_res == "enabled")
    except Exception:
        pass

    # Wi-Fi networks scan
    if wifi["available"] and wifi["enabled"]:
        try:
            w_res = subprocess.run(["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY,IN-USE", "dev", "wifi", "list"], capture_output=True, text=True, timeout=5).stdout
            seen = set()
            for line in w_res.strip().splitlines():
                parts = line.split(":")
                if len(parts) >= 4:
                    ssid = parts[0].strip()
                    sig = parts[1].strip()
                    sec = parts[2].strip()
                    in_use = parts[3].strip() == "*"
                    if ssid and ssid not in seen:
                        seen.add(ssid)
                        if in_use:
                            wifi["ssid"] = ssid
                        wifi["networks"].append({
                            "ssid": ssid,
                            "signal": int(sig) if sig.isdigit() else 50,
                            "security": sec or "Open",
                            "connected": in_use
                        })
        except Exception:
            pass

    return {
        "ethernet": ethernet,
        "wifi": wifi
    }

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        print(json.dumps(get_network_info()))
    elif cmd == "toggle-wifi":
        try:
            cur = subprocess.run(["nmcli", "radio", "wifi"], capture_output=True, text=True).stdout.strip()
            new_state = "off" if cur == "enabled" else "on"
            subprocess.run(["nmcli", "radio", "wifi", new_state])
            print(json.dumps({"success": True, "state": new_state}))
        except Exception as e:
            print(json.dumps({"success": False, "error": str(e)}))
    elif cmd == "rescan":
        try:
            subprocess.run(["nmcli", "dev", "wifi", "rescan"], timeout=5)
            print(json.dumps({"success": True}))
        except Exception as e:
            print(json.dumps({"success": False, "error": str(e)}))
    elif cmd == "connect" and len(sys.argv) > 2:
        ssid = sys.argv[2]
        pwd = sys.argv[3] if len(sys.argv) > 3 else None
        c_cmd = ["nmcli", "dev", "wifi", "connect", ssid]
        if pwd:
            c_cmd += ["password", pwd]
        try:
            res = subprocess.run(c_cmd, capture_output=True, text=True, timeout=15)
            print(json.dumps({"success": res.returncode == 0, "output": res.stdout + res.stderr}))
        except Exception as e:
            print(json.dumps({"success": False, "error": str(e)}))

if __name__ == "__main__":
    main()
