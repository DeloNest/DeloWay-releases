#!/usr/bin/env python3
import json
import glob
import os
import subprocess
import time
import sys

def get_cpu():
    with open("/proc/stat") as f:
        fields = [float(x) for x in f.readline().split()[1:]]
    idle = fields[3] + fields[4]
    total = sum(fields)
    return idle, total

def find_cpu_hwmon():
    for p in sorted(glob.glob("/sys/class/hwmon/hwmon*")):
        try:
            with open(os.path.join(p, "name")) as f:
                name = f.read().strip().lower()
            if name in ("coretemp", "k10temp", "zenpower", "cpu_thermal"):
                tpath = os.path.join(p, "temp1_input")
                if os.path.exists(tpath):
                    return tpath
        except Exception:
            pass
    for p in sorted(glob.glob("/sys/class/hwmon/hwmon*")):
        tpath = os.path.join(p, "temp1_input")
        if os.path.exists(tpath):
            return tpath
    return None

def sample_cpu_temp(cpu_hwmon_path):
    if not cpu_hwmon_path or not os.path.exists(cpu_hwmon_path):
        return None
    try:
        with open(cpu_hwmon_path) as f:
            return round(int(f.read().strip()) / 1000.0, 1)
    except Exception:
        return None

def sample_ram():
    try:
        with open("/proc/meminfo") as f:
            m = dict(l.split(":") for l in f if ":" in l)
        mem_total = int(m["MemTotal"].split()[0]) / 1024 / 1024
        mem_avail = int(m["MemAvailable"].split()[0]) / 1024 / 1024
        mem_used = mem_total - mem_avail
        ram_pct = round((mem_used / mem_total) * 100, 1) if mem_total > 0 else 0.0
        return round(mem_used, 1), round(mem_total, 1), ram_pct
    except Exception:
        return 0.0, 0.0, 0.0

def sample_gpu():
    try:
        smi = subprocess.check_output(
            ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total", "--format=csv,noheader,nounits"],
            text=True,
            timeout=1
        ).strip()
        parts = [p.strip() for p in smi.split(",")]
        if len(parts) >= 4:
            gpu_pct = float(parts[0])
            gpu_temp = float(parts[1])
            gpu_vram_used = round(float(parts[2]) / 1024.0, 1)
            gpu_vram_total = round(float(parts[3]) / 1024.0, 1)
            return True, gpu_pct, gpu_temp, gpu_vram_used, gpu_vram_total
    except Exception:
        pass

    for p in glob.glob("/sys/class/drm/card*/device"):
        busy_file = os.path.join(p, "gpu_busy_percent")
        if os.path.exists(busy_file):
            try:
                with open(busy_file) as f:
                    gpu_pct = float(f.read().strip())
                vram_used_file = os.path.join(p, "mem_info_vram_used")
                vram_tot_file = os.path.join(p, "mem_info_vram_total")
                gpu_vram_used = None
                gpu_vram_total = None
                if os.path.exists(vram_used_file) and os.path.exists(vram_tot_file):
                    with open(vram_used_file) as f:
                        gpu_vram_used = round(int(f.read().strip()) / 1024 / 1024 / 1024, 1)
                    with open(vram_tot_file) as f:
                        gpu_vram_total = round(int(f.read().strip()) / 1024 / 1024 / 1024, 1)
                gpu_temp = None
                for hw in glob.glob(os.path.join(p, "hwmon/hwmon*")):
                    tf = os.path.join(hw, "temp1_input")
                    if os.path.exists(tf):
                        with open(tf) as f:
                            gpu_temp = round(int(f.read().strip()) / 1000.0, 1)
                        break
                return True, gpu_pct, gpu_temp, gpu_vram_used, gpu_vram_total
            except Exception:
                pass

    return False, None, None, None, None

def main():
    cpu_hwmon_path = find_cpu_hwmon()

    try:
        last_idle, last_total = get_cpu()
        time.sleep(0.05)
        cur_idle, cur_total = get_cpu()
        idle_d = cur_idle - last_idle
        tot_d = cur_total - last_total
        cpu_pct = round(100.0 * (1.0 - idle_d / tot_d), 1) if tot_d > 0 else 0.0
        last_idle, last_total = cur_idle, cur_total
    except Exception:
        cpu_pct = 0.0
        last_idle, last_total = 0.0, 1.0

    while True:
        cpu_temp = sample_cpu_temp(cpu_hwmon_path)
        ram_used, ram_total, ram_pct = sample_ram()
        has_gpu, gpu_pct, gpu_temp, gpu_vram_used, gpu_vram_total = sample_gpu()

        payload = {
            "cpu": cpu_pct,
            "cpuTemp": cpu_temp,
            "ramUsed": ram_used,
            "ramTotal": ram_total,
            "ramPercent": ram_pct,
            "hasGpu": has_gpu,
            "gpu": gpu_pct,
            "gpuTemp": gpu_temp,
            "gpuVramUsed": gpu_vram_used,
            "gpuVramTotal": gpu_vram_total
        }
        print(json.dumps(payload), flush=True)

        time.sleep(2.0)

        try:
            cur_idle, cur_total = get_cpu()
            idle_d = cur_idle - last_idle
            tot_d = cur_total - last_total
            cpu_pct = round(100.0 * (1.0 - idle_d / tot_d), 1) if tot_d > 0 else 0.0
            last_idle, last_total = cur_idle, cur_total
        except Exception:
            pass

if __name__ == "__main__":
    main()
