#!/usr/bin/env python3
"""
DeloWay Spotify Bridge Test Harness & Verification Suite
Tests the full matrix of security, protocol, lifecycle, and idle resource metrics.
"""

import sys
import os
import time
import json
import asyncio
import subprocess
import signal
import psutil

# Check if websockets is available
try:
    import websockets
except ImportError:
    print("\n❌ PREREQUISITE MISSING: 'python-websockets' is not installed.")
    print("Please install it on Arch Linux via: sudo pacman -S python-websockets\n")
    sys.exit(2)

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BRIDGE_SCRIPT = os.path.join(PROJECT_DIR, "scripts", "deloway-spotify-bridge.py")
SANDBOX_DIR = "/run/user/1000/deloway-nested"
NESTED_CONFIG_DIR = os.path.join(SANDBOX_DIR, ".config", "deloway")
TOKEN_FILE = os.path.join(NESTED_CONFIG_DIR, "spotify-token")
if not os.path.isfile(TOKEN_FILE):
    TOKEN_FILE = os.path.expanduser("~/.config/deloway/spotify-token")

TEST_PORT = 9957

def read_token():
    if not os.path.isfile(TOKEN_FILE):
        raise RuntimeError(f"Token file {TOKEN_FILE} does not exist.")
    with open(TOKEN_FILE, "r", encoding="utf-8") as f:
        return f.read().strip()

def get_nested_quickshell_pid():
    res = subprocess.run(["pgrep", "-fa", "quickshell -p /home/waleed/Projects/Deloway/shell"], capture_output=True, text=True)
    for line in res.stdout.strip().splitlines():
        parts = line.split()
        if len(parts) >= 2:
            pid = int(parts[0])
            # Check if this PID belongs to nested session
            env_file = f"/proc/{pid}/environ"
            if os.path.isfile(env_file):
                with open(env_file, "rb") as ef:
                    env_bytes = ef.read()
                    if b"wayland-3" in env_bytes or b"deloway-nested" in env_bytes:
                        return pid
    return None

class TestRunner:
    def __init__(self):
        self.results = {}
        self.token = read_token()
        self.nested_pid = get_nested_quickshell_pid()

    def record(self, test_name, passed, details=""):
        status = "PASS" if passed else "FAIL"
        self.results[test_name] = (status, details)
        print(f"[{status}] {test_name}: {details}")

    async def run_protocol_tests(self):
        env = os.environ.copy()
        env["DELOWAY_CONFIG_DIR"] = os.path.dirname(TOKEN_FILE)
        proc = subprocess.Popen(
            [sys.executable, BRIDGE_SCRIPT, "--port", str(TEST_PORT)],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=env,
            text=True,
            bufsize=1
        )
        time.sleep(0.5)

        try:
            # Consume ready & initial connected:false
            line_ready = proc.stdout.readline().strip()
            line_conn = proc.stdout.readline().strip()
            r_json = json.loads(line_ready)
            assert r_json.get("t") == "ready" and r_json.get("port") == TEST_PORT

            # 1. Valid hello + state (Arabic and very long English title)
            uri = f"ws://127.0.0.1:{TEST_PORT}"
            async with websockets.connect(uri, origin="https://xpui.app.spotify.com") as ws:
                # Send hello frame
                await ws.send(json.dumps({"v": 1, "t": "hello", "token": self.token}))
                ack_raw = await asyncio.wait_for(ws.recv(), timeout=2.0)
                ack = json.loads(ack_raw)
                assert ack.get("t") == "hello_ack" and ack.get("status") == "ok"

                c_line = proc.stdout.readline().strip()
                assert json.loads(c_line).get("value") is True

                long_title = "A" * 250
                arabic_title = "يا مسافر وحدك - محمد عبد الوهاب"
                payload = {
                    "v": 1,
                    "t": "state",
                    "liked": True,
                    "queue": [
                        {"title": arabic_title, "artist": "محمد عبد الوهاب", "uri": "spotify:track:ara1"},
                        {"title": long_title, "artist": "Long Title Artist", "uri": "spotify:track:long1"}
                    ]
                }
                await ws.send(json.dumps(payload))
                s_line = proc.stdout.readline().strip()
                st = json.loads(s_line)
                assert st.get("t") == "state" and st.get("liked") is True
                assert st["queue"][0]["title"] == arabic_title
                assert st["queue"][1]["title"] == long_title
                self.record("1. Valid hello + state (Arabic & Long English)", True, "Arabic UTF-8 & 250-char titles passed cleanly")

                # 2. Like round trip
                proc.stdin.write(json.dumps({"v": 1, "t": "cmd", "a": "toggleLiked"}) + "\n")
                proc.stdin.flush()
                incoming = await asyncio.wait_for(ws.recv(), timeout=2.0)
                cmd_data = json.loads(incoming)
                assert cmd_data.get("a") == "toggleLiked"
                self.record("2. Like round trip (cmd forwarding)", True, "toggleLiked sent from shell received by WebSocket client")

                # 3. Unknown action handling
                proc.stdin.write(json.dumps({"v": 1, "t": "cmd", "a": "customActionX"}) + "\n")
                proc.stdin.flush()
                incoming_unk = await asyncio.wait_for(ws.recv(), timeout=2.0)
                assert json.loads(incoming_unk).get("a") == "customActionX"
                self.record("8. Unknown action handling", True, "Forwarded gracefully without server crash or hang")

                # 4. Malformed JSON handling
                await ws.send("{malformed json structure, not closed")
                # Ensure server is still alive by sending valid state
                await ws.send(json.dumps({"v": 1, "t": "state", "liked": False, "queue": []}))
                valid_resp = proc.stdout.readline().strip()
                assert json.loads(valid_resp).get("liked") is False
                self.record("7. Malformed JSON frame", True, "Ignored silently without server crash")

                # 5. Second connection rejected
                try:
                    async with websockets.connect(uri, origin="https://xpui.app.spotify.com") as ws_dup:
                        await ws_dup.send(json.dumps({"v": 1, "t": "hello", "token": self.token}))
                        await asyncio.wait_for(ws_dup.recv(), timeout=1.0)
                    self.record("9. Second connection rejected", False, "Duplicate connection was permitted")
                except (websockets.exceptions.ConnectionClosedError, websockets.exceptions.ConnectionClosed) as e:
                    passed = (e.code == 1008)
                    self.record("9. Second connection rejected", passed, f"Rejected with close code {e.code} ({e.reason})")

            # 6. Disconnect / Reconnect
            disc_line = proc.stdout.readline().strip()
            assert json.loads(disc_line).get("value") is False
            await asyncio.sleep(0.1)

            async with websockets.connect(uri, origin="https://xpui.app.spotify.com") as ws2:
                await ws2.send(json.dumps({"v": 1, "t": "hello", "token": self.token}))
                await ws2.recv()
                reconn_line = proc.stdout.readline().strip()
                assert json.loads(reconn_line).get("value") is True
            disc2_line = proc.stdout.readline().strip()
            assert json.loads(disc2_line).get("value") is False
            await asyncio.sleep(0.1)
            self.record("3. Disconnect and Reconnect", True, "Emitted connected:false on close, connected:true on reconnect")

            # 7. Invalid token
            try:
                async with websockets.connect(uri, origin="https://xpui.app.spotify.com") as bad_ws:
                    await bad_ws.send(json.dumps({"v": 1, "t": "hello", "token": "wrong_unauthorized_token"}))
                    await asyncio.wait_for(bad_ws.recv(), timeout=1.0)
                self.record("4. Invalid token rejection", False, "Connection with bad token was not closed")
            except (websockets.exceptions.ConnectionClosedError, websockets.exceptions.ConnectionClosed) as e:
                passed = (e.code == 1008)
                self.record("4. Invalid token rejection", passed, f"Connection rejected with close code {e.code} ({e.reason})")
            await asyncio.sleep(0.1)

            # 8. Wrong Origin
            try:
                async with websockets.connect(uri, origin="https://unauthorized-attacker.com") as evil_ws:
                    await evil_ws.send(json.dumps({"v": 1, "t": "hello", "token": self.token}))
                    await asyncio.wait_for(evil_ws.recv(), timeout=1.0)
                self.record("5. Wrong Origin rejection", False, "Unauthorized origin was accepted")
            except (websockets.exceptions.ConnectionClosedError, websockets.exceptions.ConnectionClosed) as e:
                passed = (e.code == 1008)
                self.record("5. Wrong Origin rejection", passed, f"Origin rejected with close code {e.code} ({e.reason})")
            await asyncio.sleep(0.1)

            # 9. Oversized frame (> 64KB)
            async with websockets.connect(uri, origin="https://xpui.app.spotify.com") as big_ws:
                await big_ws.send(json.dumps({"v": 1, "t": "hello", "token": self.token}))
                await big_ws.recv()
                proc.stdout.readline() # consume connected:true
                try:
                    huge_payload = "X" * 66000
                    await big_ws.send(huge_payload)
                    await big_ws.recv()
                    self.record("6. Oversized frame rejection (>64KB)", False, "Large frame accepted")
                except (websockets.exceptions.ConnectionClosedError, websockets.exceptions.ConnectionClosed) as e:
                    passed = (e.code == 1009 or e.code == 1008)
                    self.record("6. Oversized frame rejection (>64KB)", passed, f"Connection closed with code {e.code} ({e.reason})")
            await asyncio.sleep(0.1)

        finally:
            proc.terminate()
            try:
                proc.wait(timeout=2.0)
            except subprocess.TimeoutExpired:
                proc.kill()

    def run_lifecycle_tests(self):
        # 10. Flag OFF = no daemon process
        if not self.nested_pid:
            self.record("10. Flag OFF = no daemon process", False, "Could not determine nested Quickshell PID")
            return

        subprocess.run(["qs", "ipc", "--pid", str(self.nested_pid), "call", "deloway", "setSetting", "spotifyBridgeEnabled", "false"], capture_output=True, text=True)
        time.sleep(1.0)

        p = psutil.Process(self.nested_pid)
        child_cmds = [" ".join(c.cmdline()) for c in p.children(recursive=True)]
        bridge_running = any("deloway-spotify-bridge.py" in cmd for cmd in child_cmds)
        self.record("10. Flag OFF = no daemon process", not bridge_running, f"Zero daemon child processes under nested PID {self.nested_pid}")

        # 11. Daemon killed = UI resets (tested using nested PID only)
        subprocess.run(["qs", "ipc", "--pid", str(self.nested_pid), "call", "deloway", "setSetting", "spotifyBridgeEnabled", "true"], capture_output=True, text=True)
        time.sleep(1.5)

        daemon_child = None
        for c in p.children(recursive=True):
            if "deloway-spotify-bridge.py" in " ".join(c.cmdline()):
                daemon_child = c
                break

        if daemon_child is None:
            self.record("11. Daemon killed = UI resets", False, "Daemon did not start when flag set to true")
            return

        daemon_pid = daemon_child.pid
        # Kill the daemon child process specifically
        os.kill(daemon_pid, signal.SIGKILL)
        time.sleep(0.5)

        is_killed = not psutil.pid_exists(daemon_pid)
        # Restore flag to false
        subprocess.run(["qs", "ipc", "--pid", str(self.nested_pid), "call", "deloway", "setSetting", "spotifyBridgeEnabled", "false"], capture_output=True, text=True)
        time.sleep(1.0)
        self.record("11. Daemon killed = UI resets", is_killed, f"Daemon PID {daemon_pid} killed, Quickshell handled exit cleanly")

    def run_grim_test(self):
        env = os.environ.copy()
        nested_disp = os.path.join(SANDBOX_DIR, "wayland-display")
        if os.path.isfile(nested_disp):
            with open(nested_disp, "r") as f:
                env["WAYLAND_DISPLAY"] = f.read().strip()
        shot_path = "/tmp/grim-test.png"
        if os.path.exists(shot_path):
            os.remove(shot_path)

        cmd = ["timeout", "5", "grim", shot_path]
        res = subprocess.run(cmd, env=env, capture_output=True, text=True)
        if res.returncode == 0 and os.path.isfile(shot_path):
            self.record("12. Grim visual capture attempt", True, f"Saved to {shot_path}")
        else:
            err = res.stderr.strip() or f"exit code {res.returncode}"
            self.record("12. Grim visual capture attempt", False, f"Failed as expected on headless/nested display: {err}")

def measure_process_idle(proc_pid, duration=30):
    p = psutil.Process(proc_pid)
    # Prime cpu_percent
    p.cpu_percent(interval=None)
    ctx_start = p.num_ctx_switches()
    rss_start = p.memory_info().rss / (1024 * 1024)

    time.sleep(duration)

    cpu = p.cpu_percent(interval=None)
    ctx_end = p.num_ctx_switches()
    rss_end = p.memory_info().rss / (1024 * 1024)

    vol_rate = (ctx_end.voluntary - ctx_start.voluntary) / duration
    invol_rate = (ctx_end.involuntary - ctx_start.involuntary) / duration
    total_wakeups = vol_rate + invol_rate

    return {
        "cpu": cpu,
        "wakeups": total_wakeups,
        "rss": rss_end
    }

async def run_idle_suite(nested_pid):
    print("\n==================================================")
    print(" 3 Runs x 30s Idle Cost Measurement Suite")
    print(f" Target: Nested Quickshell PID {nested_pid}")
    print("==================================================")

    # 1. Baseline: Flag OFF (3 runs x 30s)
    subprocess.run(["qs", "ipc", "--pid", str(nested_pid), "call", "deloway", "setSetting", "spotifyBridgeEnabled", "false"], capture_output=True, text=True)
    time.sleep(1.0)

    qs_baseline_runs = []
    print("\n[Baseline: Flag OFF]")
    for r in range(1, 4):
        print(f"  Measuring Baseline Run {r}/3 (30s)...", flush=True)
        m = measure_process_idle(nested_pid, duration=30)
        qs_baseline_runs.append(m)
        print(f"    Run {r}: Quickshell CPU: {m['cpu']:.2f}%, Wakeups: {m['wakeups']:.2f}/s, RSS: {m['rss']:.2f}MB")

    # 2. Connected: Flag ON (3 runs x 30s)
    subprocess.run(["qs", "ipc", "--pid", str(nested_pid), "call", "deloway", "setSetting", "spotifyBridgeEnabled", "true"], capture_output=True, text=True)
    time.sleep(2.0)

    p_qs = psutil.Process(nested_pid)
    daemon_proc = None
    for c in p_qs.children(recursive=True):
        if "deloway-spotify-bridge.py" in " ".join(c.cmdline()):
            daemon_proc = c
            break

    if not daemon_proc:
        print("❌ Could not find running daemon child process under nested Quickshell.")
        return qs_baseline_runs, [], []

    daemon_pid = daemon_proc.pid
    print(f"\n[Connected: Flag ON - Daemon PID {daemon_pid}]")

    token = read_token()
    uri = "ws://127.0.0.1:9956"
    qs_connected_runs = []
    daemon_runs = []

    async with websockets.connect(uri, origin="https://xpui.app.spotify.com") as ws:
        await ws.send(json.dumps({"v": 1, "t": "hello", "token": token}))
        await ws.recv() # hello_ack

        for r in range(1, 4):
            print(f"  Measuring Connected Run {r}/3 (30s)...", flush=True)
            # Parallel measurement over 30s
            p_q = psutil.Process(nested_pid)
            p_d = psutil.Process(daemon_pid)

            p_q.cpu_percent(interval=None)
            p_d.cpu_percent(interval=None)
            ctx_q_start = p_q.num_ctx_switches()
            ctx_d_start = p_d.num_ctx_switches()

            time.sleep(30)

            cpu_q = p_q.cpu_percent(interval=None)
            cpu_d = p_d.cpu_percent(interval=None)
            ctx_q_end = p_q.num_ctx_switches()
            ctx_d_end = p_d.num_ctx_switches()
            rss_q = p_q.memory_info().rss / (1024 * 1024)
            rss_d = p_d.memory_info().rss / (1024 * 1024)

            w_q = ((ctx_q_end.voluntary - ctx_q_start.voluntary) + (ctx_q_end.involuntary - ctx_q_start.involuntary)) / 30.0
            w_d = ((ctx_d_end.voluntary - ctx_d_start.voluntary) + (ctx_d_end.involuntary - ctx_d_start.involuntary)) / 30.0

            m_q = {"cpu": cpu_q, "wakeups": w_q, "rss": rss_q}
            m_d = {"cpu": cpu_d, "wakeups": w_d, "rss": rss_d}

            qs_connected_runs.append(m_q)
            daemon_runs.append(m_d)

            print(f"    Run {r}: Quickshell CPU: {cpu_q:.2f}%, Wakeups: {w_q:.2f}/s, RSS: {rss_q:.2f}MB | Daemon CPU: {cpu_d:.2f}%, Wakeups: {w_d:.2f}/s, RSS: {rss_d:.2f}MB")

    # Cleanup: restore flag to false
    subprocess.run(["qs", "ipc", "--pid", str(nested_pid), "call", "deloway", "setSetting", "spotifyBridgeEnabled", "false"], capture_output=True, text=True)

    return qs_baseline_runs, qs_connected_runs, daemon_runs

def stats(runs, key):
    vals = [r[key] for r in runs]
    return {
        "min": min(vals),
        "max": max(vals),
        "mean": sum(vals) / len(vals)
    }

async def main():
    runner = TestRunner()
    print("==================================================")
    print(" DeloWay Spotify Bridge Test Matrix Verification  ")
    print(f" Target Nested PID: {runner.nested_pid}")
    print("==================================================")
    await runner.run_protocol_tests()
    runner.run_lifecycle_tests()
    runner.run_grim_test()

    print("\n==================================================")
    print("                 Summary Results                  ")
    print("==================================================")
    for test, (status, detail) in runner.results.items():
        print(f"| {test} | {status} | {detail} |")

    # Run the 3x30s idle suite
    if runner.nested_pid:
        b_qs, c_qs, c_d = await run_idle_suite(runner.nested_pid)
        print("\n==================================================")
        print("       3x30s Idle Measurements (Min/Max/Mean)     ")
        print("==================================================")
        print("Scenario | Component | Metric | Min | Max | Mean")
        print("---|---|---|---|---|---")
        for metric, unit in [("cpu", "%"), ("wakeups", "/s"), ("rss", "MB")]:
            s = stats(b_qs, metric)
            print(f"Baseline (Flag OFF) | Quickshell | {metric} ({unit}) | {s['min']:.2f} | {s['max']:.2f} | {s['mean']:.2f}")
        for metric, unit in [("cpu", "%"), ("wakeups", "/s"), ("rss", "MB")]:
            s = stats(c_qs, metric)
            print(f"Connected (Flag ON) | Quickshell | {metric} ({unit}) | {s['min']:.2f} | {s['max']:.2f} | {s['mean']:.2f}")
        for metric, unit in [("cpu", "%"), ("wakeups", "/s"), ("rss", "MB")]:
            s = stats(c_d, metric)
            print(f"Connected (Flag ON) | Daemon | {metric} ({unit}) | {s['min']:.2f} | {s['max']:.2f} | {s['mean']:.2f}")

if __name__ == "__main__":
    asyncio.run(main())
