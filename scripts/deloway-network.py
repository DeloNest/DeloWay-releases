#!/usr/bin/env python3
"""
Deloway Network Helper
Handles Wi-Fi scanning, connection info, and Ethernet status via NetworkManager (nmcli).
"""
import sys
import os
import socket
import json
import subprocess
import time

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
        "wifi": wifi,
        "hotspot": get_hotspot_status()
    }

def get_wifi_device():
    try:
        res = subprocess.run(["nmcli", "-t", "-f", "DEVICE,TYPE", "dev"], capture_output=True, text=True, timeout=2).stdout
        for line in res.strip().splitlines():
            parts = line.split(":")
            if len(parts) >= 2 and parts[1].strip() == "wifi":
                return parts[0].strip()
    except Exception:
        pass
    return None

def hotspot_profile_exists():
    try:
        res = subprocess.run(["nmcli", "-t", "-f", "NAME", "con", "show"], capture_output=True, text=True, timeout=2).stdout
        for line in res.strip().splitlines():
            if line.strip() == "Deloway-Hotspot":
                return True
    except Exception:
        pass
    return False

def is_hotspot_active():
    try:
        res = subprocess.run(["nmcli", "-t", "-f", "NAME,TYPE", "con", "show", "--active"], capture_output=True, text=True, timeout=2).stdout
        for line in res.strip().splitlines():
            parts = line.split(":")
            if len(parts) >= 2 and parts[0].strip() == "Deloway-Hotspot" and parts[1].strip() in ("802-11-wireless", "wifi"):
                return True
    except Exception:
        pass
    return False

def generate_hotspot_password(length=12):
    """Random WPA2 passphrase for a NEW hotspot profile (never a fixed default).
    Unambiguous characters only (no 0/O, 1/l/I) so it can be typed from the screen."""
    import secrets
    alphabet = "abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    return "".join(secrets.choice(alphabet) for _ in range(length))

def get_hotspot_details():
    ssid = socket.gethostname()
    password = ""      # unknown until a profile exists (created with a random passphrase)
    if hotspot_profile_exists():
        try:
            res = subprocess.run(["nmcli", "-s", "-t", "-f", "802-11-wireless.ssid,802-11-wireless-security.psk", "con", "show", "Deloway-Hotspot"], capture_output=True, text=True, timeout=2).stdout
            for line in res.strip().splitlines():
                if line.startswith("802-11-wireless.ssid:"):
                    val = line.split(":", 1)[1].strip()
                    if val:
                        ssid = val
                elif line.startswith("802-11-wireless-security.psk:"):
                    val = line.split(":", 1)[1].strip()
                    if val:
                        password = val
        except Exception:
            pass
    return ssid, password

def get_hotspot_status():
    dev = get_wifi_device()
    active = is_hotspot_active()
    exists = hotspot_profile_exists()
    ssid, password = get_hotspot_details()
    
    wifi_connected = False
    try:
        res = subprocess.run(["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "dev"], capture_output=True, text=True, timeout=2).stdout
        for line in res.strip().splitlines():
            parts = line.split(":")
            if len(parts) >= 2 and parts[0].strip() == "wifi" and parts[1].strip() == "connected":
                conn = parts[2].strip() if len(parts) > 2 else ""
                if conn != "Deloway-Hotspot":
                    wifi_connected = True
    except Exception:
        pass

    return {
        "available": dev is not None,
        "device": dev or "",
        "enabled": active,
        "profile_exists": exists,
        "ssid": ssid,
        "password": password,
        "wifi_connected": wifi_connected,
        "clients": get_hotspot_clients() if active else [],
        "error": "" if dev else ( "لا توجد واجهة واي فاي" )
    }

def hotspot_start():
    dev = get_wifi_device()
    if not dev:
        return {"success": False, "enabled": False, "error": "No Wi-Fi device found"}
    
    try:
        if hotspot_profile_exists():
            res = subprocess.run(["nmcli", "con", "up", "Deloway-Hotspot"], capture_output=True, text=True, timeout=10)
        else:
            ssid = socket.gethostname()
            password = generate_hotspot_password()
            res = subprocess.run([
                "nmcli", "dev", "wifi", "hotspot",
                "ifname", dev,
                "con-name", "Deloway-Hotspot",
                "ssid", ssid,
                "password", password
            ], capture_output=True, text=True, timeout=15)
    except (subprocess.TimeoutExpired, OSError) as e:
        return {"success": False, "enabled": is_hotspot_active(), "error": str(e)}

    success = (res.returncode == 0)
    return {
        "success": success,
        "enabled": is_hotspot_active(),
        "error": "" if success else (res.stderr.strip() or res.stdout.strip())
    }

def hotspot_stop():
    try:
        res = subprocess.run(["nmcli", "con", "down", "Deloway-Hotspot"], capture_output=True, text=True, timeout=10)
    except (subprocess.TimeoutExpired, OSError) as e:
        return {"success": False, "enabled": is_hotspot_active(), "error": str(e)}
    success = (res.returncode == 0)
    return {
        "success": success,
        "enabled": is_hotspot_active(),
        "error": "" if success else (res.stderr.strip() or res.stdout.strip())
    }

def hotspot_configure(ssid, password):
    try:
        return _hotspot_configure(ssid, password)
    except (subprocess.TimeoutExpired, OSError) as e:
        return {"success": False, "enabled": is_hotspot_active(), "error": str(e)}

def _hotspot_configure(ssid, password):
    if not ssid or not ssid.strip():
        return {"success": False, "enabled": is_hotspot_active(), "error": "SSID cannot be empty"}
    ssid = ssid.strip()
    if not password or len(password) < 8:
        return {"success": False, "enabled": is_hotspot_active(), "error": "Password must be at least 8 characters"}
    
    dev = get_wifi_device()
    active = is_hotspot_active()
    
    if hotspot_profile_exists():
        res = subprocess.run([
            "nmcli", "con", "modify", "Deloway-Hotspot",
            "802-11-wireless.ssid", ssid,
            "802-11-wireless-security.psk", password
        ], capture_output=True, text=True, timeout=10)
    else:
        cmd = [
            "nmcli", "con", "add",
            "type", "wifi",
            "con-name", "Deloway-Hotspot",
            "autoconnect", "no",
            "ssid", ssid,
            "802-11-wireless.mode", "ap",
            "802-11-wireless-security.key-mgmt", "wpa-psk",
            "802-11-wireless-security.psk", password,
            "ipv4.method", "shared",
            "ipv6.method", "ignore"
        ]
        if dev:
            cmd.extend(["ifname", dev])
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=10)

    if res.returncode != 0:
        return {
            "success": False,
            "enabled": is_hotspot_active(),
            "error": res.stderr.strip() or res.stdout.strip()
        }

    if active:
        subprocess.run(["nmcli", "con", "down", "Deloway-Hotspot"], capture_output=True, text=True, timeout=10)
        up_res = subprocess.run(["nmcli", "con", "up", "Deloway-Hotspot"], capture_output=True, text=True, timeout=10)
        if up_res.returncode != 0:
            return {
                "success": False,
                "enabled": is_hotspot_active(),
                "error": up_res.stderr.strip() or up_res.stdout.strip()
            }

    return {
        "success": True,
        "enabled": is_hotspot_active(),
        "ssid": ssid,
        "password": password,
        "error": ""
    }

def get_hotspot_clients():
    clients = []
    dev = get_wifi_device()
    if not dev:
        return clients

    stations = {}

    # 1. Query station dump via iw
    try:
        iw_res = subprocess.run(["iw", "dev", dev, "station", "dump"], capture_output=True, text=True, timeout=2)
        current_mac = None
        for line in iw_res.stdout.splitlines():
            line = line.strip()
            if line.startswith("Station"):
                parts = line.split()
                if len(parts) >= 2:
                    current_mac = parts[1].lower()
                    stations[current_mac] = {"mac": current_mac, "ip": "", "hostname": "", "signal": ""}
            elif current_mac and "signal:" in line:
                sig = line.split("signal:")[1].strip().split()[0]
                stations[current_mac]["signal"] = sig
    except Exception:
        pass

    # 2. Query /proc/net/arp
    try:
        with open("/proc/net/arp", "r") as f:
            for line in f.readlines()[1:]:
                parts = line.split()
                if len(parts) >= 6:
                    ip, flags, mac, device = parts[0], parts[2], parts[3].lower(), parts[5]
                    if device == dev and flags != "0x0" and mac != "00:00:00:00:00:00":
                        if mac not in stations:
                            stations[mac] = {"mac": mac, "ip": ip, "hostname": "", "signal": ""}
                        else:
                            stations[mac]["ip"] = ip
    except Exception:
        pass

    # 3. Query ip neigh show dev <dev>
    try:
        neigh_res = subprocess.run(["ip", "neigh", "show", "dev", dev], capture_output=True, text=True, timeout=2)
        for line in neigh_res.stdout.splitlines():
            parts = line.strip().split()
            if len(parts) >= 4 and "lladdr" in parts:
                ip = parts[0]
                idx = parts.index("lladdr")
                if idx + 1 < len(parts):
                    mac = parts[idx + 1].lower()
                    if mac not in stations:
                        stations[mac] = {"mac": mac, "ip": ip, "hostname": "", "signal": ""}
                    elif not stations[mac].get("ip"):
                        stations[mac]["ip"] = ip
    except Exception:
        pass

    # 4. Resolve hostnames where possible
    for mac, info in stations.items():
        if info["ip"]:
            try:
                host = socket.gethostbyaddr(info["ip"])[0]
                info["hostname"] = host
            except Exception:
                info["hostname"] = info["ip"]
        else:
            info["hostname"] = info["mac"]
        clients.append(info)

    return clients

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        print(json.dumps(get_network_info()))
    elif cmd == "hotspot-status":
        print(json.dumps(get_hotspot_status()))
    elif cmd == "hotspot-clients":
        print(json.dumps(get_hotspot_clients()))
    elif cmd == "hotspot-start":
        print(json.dumps(hotspot_start()))
    elif cmd == "hotspot-stop":
        print(json.dumps(hotspot_stop()))
    elif cmd == "hotspot-configure":
        new_ssid = sys.argv[2] if len(sys.argv) > 2 else ""
        new_pwd = sys.argv[3] if len(sys.argv) > 3 else ""
        print(json.dumps(hotspot_configure(new_ssid, new_pwd)))
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
            time.sleep(1.2)
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
            res = subprocess.run(c_cmd, capture_output=True, text=True, timeout=25)
            out = (res.stdout + res.stderr).strip()
            low = out.lower()
            needs_pw = res.returncode != 0 and any(k in low for k in (
                "secrets were required", "password", "psk", "802-1x", "no secrets", "802-11-wireless-security"))
            err = out.splitlines()[-1].replace("Error: ", "") if (res.returncode != 0 and out) else ""
            print(json.dumps({"success": res.returncode == 0, "needsPassword": needs_pw, "error": err, "output": out}))
        except Exception as e:
            print(json.dumps({"success": False, "error": str(e)}))

if __name__ == "__main__":
    main()
