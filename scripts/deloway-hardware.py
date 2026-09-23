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
            timeout=1,
            env=dict(os.environ, LC_ALL="C")
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


def get_cores():
    """Return list of (idle, total) per logical CPU."""
    cores = []
    try:
        with open("/proc/stat") as f:
            for line in f:
                if line.startswith("cpu") and not line.startswith("cpu "):
                    fields = [float(x) for x in line.split()[1:]]
                    cores.append((fields[3] + fields[4], sum(fields)))
    except Exception:
        pass
    return cores

def core_percents(prev, cur):
    out = []
    for i in range(min(len(prev), len(cur))):
        idle_d = cur[i][0] - prev[i][0]
        tot_d = cur[i][1] - prev[i][1]
        out.append(round(100.0 * (1.0 - idle_d / tot_d), 0) if tot_d > 0 else 0.0)
    return out

def sample_load():
    try:
        with open("/proc/loadavg") as f:
            parts = f.read().split()
        running, total = parts[3].split("/")
        return [float(parts[0]), float(parts[1]), float(parts[2])], int(running), int(total)
    except Exception:
        return [0.0, 0.0, 0.0], 0, 0

def sample_uptime():
    try:
        with open("/proc/uptime") as f:
            return int(float(f.read().split()[0]))
    except Exception:
        return 0

def sample_cpu_freq():
    try:
        vals = []
        for p in glob.glob("/sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq"):
            with open(p) as f:
                vals.append(int(f.read().strip()) / 1000.0)
        if vals:
            return round(sum(vals) / len(vals))
    except Exception:
        pass
    return None

def sample_disk(path="/"):
    try:
        st = os.statvfs(path)
        total = st.f_blocks * st.f_frsize
        free = st.f_bavail * st.f_frsize
        used = total - free
        return round(used / 1e9, 1), round(total / 1e9, 1), round(100.0 * used / total, 1) if total else 0.0
    except Exception:
        return 0.0, 0.0, 0.0

def sample_net():
    """Aggregate rx/tx bytes over physical interfaces (skip lo, docker, bridges, veth)."""
    rx = tx = 0
    iface = ""
    try:
        with open("/proc/net/dev") as f:
            for line in f.readlines()[2:]:
                name, data = line.split(":", 1)
                name = name.strip()
                if name == "lo" or name.startswith(("docker", "br-", "veth", "virbr", "tun", "tap")):
                    continue
                fields = data.split()
                r, t = int(fields[0]), int(fields[8])
                if r + t > 0 and not iface:
                    iface = name
                rx += r
                tx += t
    except Exception:
        pass
    return rx, tx, iface

def find_nvme_temp():
    for p in sorted(glob.glob("/sys/class/hwmon/hwmon*")):
        try:
            with open(os.path.join(p, "name")) as f:
                if f.read().strip().lower() == "nvme":
                    t = os.path.join(p, "temp1_input")
                    if os.path.exists(t):
                        return t
        except Exception:
            pass
    return None

def sample_gpu_extra():
    """Optional NVIDIA power/clock/name; returns (name, watts, mhz) or Nones."""
    try:
        out = subprocess.check_output(
            ["nvidia-smi", "--query-gpu=name,power.draw,clocks.gr", "--format=csv,noheader,nounits"],
            text=True, timeout=1, env=dict(os.environ, LC_ALL="C")).strip()
        parts = [x.strip() for x in out.split(",")]
        name = parts[0].replace("NVIDIA ", "").replace("GeForce ", "")
        return name, round(float(parts[1]), 1), int(float(parts[2]))
    except Exception:
        return None, None, None

_proc_prev = {}
_proc_prev_t = None
_CLK = os.sysconf("SC_CLK_TCK") if hasattr(os, "sysconf") else 100
_NCPU = os.cpu_count() or 1

def sample_top_procs(limit=3):
    """Instantaneous per-process CPU% (share of the whole machine) from /proc deltas."""
    global _proc_prev, _proc_prev_t
    now = time.time()
    cur = {}
    names = {}
    for d in os.listdir("/proc"):
        if not d.isdigit():
            continue
        try:
            with open("/proc/" + d + "/stat") as f:
                raw = f.read()
            lp, rp = raw.index("("), raw.rindex(")")
            name = raw[lp + 1:rp]
            fields = raw[rp + 2:].split()
            cur[d] = int(fields[11]) + int(fields[12])  # utime + stime
            names[d] = name
        except Exception:
            continue
    out = []
    if _proc_prev_t is not None:
        dt = max(0.001, now - _proc_prev_t)
        agg = {}
        for pid, ticks in cur.items():
            prev = _proc_prev.get(pid)
            if prev is None:
                continue
            pct = (ticks - prev) / _CLK / dt * 100.0  # htop convention: 100% = one core
            if pct > 0:
                agg[names[pid]] = agg.get(names[pid], 0.0) + pct
        for name, pct in sorted(agg.items(), key=lambda kv: -kv[1])[:limit]:
            out.append({"name": name[:18], "cpu": round(pct, 1)})
    _proc_prev, _proc_prev_t = cur, now
    return out

def kernel_release():
    try:
        return os.uname().release.split("-")[0]
    except Exception:
        return ""

def main():
    cpu_hwmon_path = find_cpu_hwmon()
    nvme_path = find_nvme_temp()
    kernel = kernel_release()
    gpu_name, _, _ = sample_gpu_extra()
    prev_cores = get_cores()
    prev_rx, prev_tx, _ = sample_net()
    prev_t = time.time()
    core_pcts = [0.0] * len(prev_cores)
    tick = 0
    top_procs = []
    sample_top_procs(3)  # prime the delta baseline

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
        _, gpu_power, gpu_clock = sample_gpu_extra() if has_gpu else (None, None, None)
        load, running, tasks = sample_load()
        disk_used, disk_total, disk_pct = sample_disk("/")
        cur_rx, cur_tx, iface = sample_net()
        now = time.time()
        dt = max(0.001, now - prev_t)
        rx_rate = max(0.0, (cur_rx - prev_rx) / dt) if dt >= 0.5 else 0.0
        tx_rate = max(0.0, (cur_tx - prev_tx) / dt) if dt >= 0.5 else 0.0
        prev_rx, prev_tx, prev_t = cur_rx, cur_tx, now
        top_procs = sample_top_procs(3)
        tick += 1

        payload = {
            "loadAvg": load,
            "running": running,
            "tasks": tasks,
            "uptime": sample_uptime(),
            "kernel": kernel,
            "cpuFreq": sample_cpu_freq(),
            "cores": core_pcts,
            "diskUsed": disk_used,
            "diskTotal": disk_total,
            "diskPercent": disk_pct,
            "netRx": round(rx_rate),
            "netTx": round(tx_rate),
            "netIface": iface,
            "nvmeTemp": sample_cpu_temp(nvme_path),
            "gpuName": gpu_name,
            "gpuPower": gpu_power,
            "gpuClock": gpu_clock,
            "topProcs": top_procs,
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
        try:
            print(json.dumps(payload), flush=True)
        except BrokenPipeError:
            return

        time.sleep(2.0)

        try:
            cur_idle, cur_total = get_cpu()
            idle_d = cur_idle - last_idle
            tot_d = cur_total - last_total
            cpu_pct = round(100.0 * (1.0 - idle_d / tot_d), 1) if tot_d > 0 else 0.0
            last_idle, last_total = cur_idle, cur_total
            cur_cores = get_cores()
            core_pcts = core_percents(prev_cores, cur_cores)
            prev_cores = cur_cores
        except Exception:
            pass

if __name__ == "__main__":
    main()
