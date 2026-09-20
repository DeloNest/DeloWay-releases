#!/usr/bin/env python3
import json, glob, subprocess, time, sys, os

def get_cpu():
    with open("/proc/stat") as f:
        fields = [float(x) for x in f.readline().split()[1:]]
    idle = fields[3] + fields[4]
    total = sum(fields)
    return idle, total

# CPU calculation with 0.1s delta
try:
    i1, t1 = get_cpu()
    time.sleep(0.1)
    i2, t2 = get_cpu()
    idle_delta = i2 - i1
    total_delta = t2 - t1
    cpu_pct = round(100.0 * (1.0 - idle_delta / total_delta), 1) if total_delta > 0 else 0.0
except Exception:
    cpu_pct = 0.0

# RAM
try:
    with open("/proc/meminfo") as f:
        m = dict(l.split(":") for l in f if ":" in l)
    mem_total = int(m["MemTotal"].split()[0]) / 1024 / 1024
    mem_avail = int(m["MemAvailable"].split()[0]) / 1024 / 1024
    mem_used = mem_total - mem_avail
    ram_total = round(mem_total, 1)
    ram_used = round(mem_used, 1)
    ram_pct = round((mem_used / mem_total) * 100, 1) if mem_total > 0 else 0.0
except Exception:
    ram_total, ram_used, ram_pct = 0.0, 0.0, 0.0

# Battery
bats = glob.glob("/sys/class/power_supply/BAT*")
has_bat = len(bats) > 0
bat_pct = 100
bat_status = "AC Connected"
if has_bat:
    try:
        with open(bats[0] + "/capacity") as f:
            bat_pct = int(f.read().strip())
        with open(bats[0] + "/status") as f:
            bat_status = f.read().strip()
    except Exception:
        pass

# Network
try:
    net_out = subprocess.check_output(["ip", "-j", "route", "get", "1.1.1.1"], text=True, env=dict(os.environ, LC_ALL="C"))
    net_data = json.loads(net_out)[0]
    dev = net_data.get("dev", "eno1")
    ip = net_data.get("prefsrc", "")
except Exception:
    dev = "eno1"
    ip = "192.168.100.9"

is_wifi = dev.startswith("wl")

# Bluetooth
try:
    rf_out = subprocess.check_output(["rfkill", "list", "bluetooth"], text=True, env=dict(os.environ, LC_ALL="C"))
    bt_blocked = "Soft blocked: yes" in rf_out or "Hard blocked: yes" in rf_out
    bt_on = not bt_blocked
except Exception:
    bt_on = True

res = {
    "cpu": cpu_pct,
    "ramTotal": ram_total,
    "ramUsed": ram_used,
    "ramPercent": ram_pct,
    "hasBattery": has_bat,
    "batteryPercent": bat_pct,
    "batteryStatus": bat_status,
    "netDevice": dev,
    "netIp": ip,
    "isWifi": is_wifi,
    "bluetoothOn": bt_on
}

print(json.dumps(res))
