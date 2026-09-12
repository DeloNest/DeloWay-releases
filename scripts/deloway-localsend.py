#!/usr/bin/env python3
"""
Deloway LocalSend Integration Helper
Provides status inspection, real network discovery, and transfer initiation for Quickshell.
"""

import sys
import json
import os
import socket
import ssl
import urllib.request
import subprocess
from concurrent.futures import ThreadPoolExecutor

PREFS_FILE = os.path.expanduser('~/.local/share/org.localsend.localsend_app/shared_preferences.json')
LOCALSEND_BIN = os.path.expanduser('~/.local/bin/localsend')
LOCALSEND_CLI = os.path.expanduser('~/.local/bin/localsend-cli')
PORT = 53317

def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('10.255.255.255', 1))
        return s.getsockname()[0]
    except Exception:
        return '127.0.0.1'
    finally:
        s.close()

def is_localsend_running():
    # Check if process is running
    try:
        res = subprocess.run(['pgrep', '-f', 'localsend_app'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if res.returncode == 0:
            return True
    except Exception:
        pass

    local_ip = get_local_ip()
    for host in ['127.0.0.1', local_ip]:
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(0.15)
            if sock.connect_ex((host, PORT)) == 0:
                sock.close()
                return True
            sock.close()
        except Exception:
            pass
    return False

def get_local_info():
    alias = 'Deloway'
    favorites = []
    if os.path.exists(PREFS_FILE):
        try:
            with open(PREFS_FILE, 'r', encoding='utf-8') as f:
                data = json.load(f)
                alias = data.get('flutter.ls_alias', alias)
                favs_raw = data.get('flutter.ls_favorites', [])
                for fav in favs_raw:
                    try:
                        favorites.append(json.loads(fav))
                    except Exception:
                        pass
        except Exception:
            pass

    local_ip = get_local_ip()
    running = is_localsend_running()

    return {
        'alias': alias,
        'hostname': socket.gethostname(),
        'ip': local_ip,
        'port': PORT,
        'isRunning': running,
        'deviceType': 'desktop',
        'deviceModel': 'Linux (DeloOS)',
        'favorites': favorites
    }

def discover_devices():
    info = get_local_info()
    local_ip = info['ip']
    parts = local_ip.split('.')
    if len(parts) != 4:
        return []

    base = f"{parts[0]}.{parts[1]}.{parts[2]}."

    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    found = []

    def check_ip(ip):
        if ip == local_ip or ip == '127.0.0.1':
            return None
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(0.15)
        res = sock.connect_ex((ip, PORT))
        sock.close()
        if res == 0:
            for scheme in ['https', 'http']:
                try:
                    url = f"{scheme}://{ip}:{PORT}/api/localsend/v2/info"
                    req = urllib.request.Request(url, headers={'User-Agent': 'LocalSend'})
                    with urllib.request.urlopen(req, context=ctx, timeout=0.8) as r:
                        d = json.loads(r.read().decode('utf-8'))
                        d['ip'] = ip
                        return d
                except Exception:
                    pass
            return {
                'ip': ip,
                'alias': f"Device ({ip})",
                'deviceType': 'mobile',
                'deviceModel': 'Network Device',
                'port': PORT
            }
        return None

    ips_to_check = set()
    for fav in info.get('favorites', []):
        if 'ip' in fav and fav['ip'] != local_ip:
            ips_to_check.add(fav['ip'])

    # Check common DHCP lease pool
    for i in range(1, 40):
        ip = f"{base}{i}"
        if ip != local_ip:
            ips_to_check.add(ip)

    with ThreadPoolExecutor(max_workers=30) as executor:
        for r in executor.map(check_ip, list(ips_to_check)):
            if r:
                found.append(r)

    return found

def launch_localsend():
    if is_localsend_running():
        return True
    try:
        env = os.environ.copy()
        env['GDK_BACKEND'] = 'wayland'
        subprocess.Popen([LOCALSEND_BIN], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        return True
    except Exception as e:
        return False

def send_files(files):
    if not files:
        return False
    try:
        clean_files = [f.replace('file://', '') for f in files]
        env = os.environ.copy()
        if os.path.exists(LOCALSEND_CLI):
            cmd = [LOCALSEND_CLI, '-f'] + clean_files
            subprocess.Popen(cmd, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            return True
        else:
            env['GDK_BACKEND'] = 'wayland'
            cmd = [LOCALSEND_BIN] + clean_files
            subprocess.Popen(cmd, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            return True
    except Exception:
        return False

if __name__ == '__main__':
    action = sys.argv[1] if len(sys.argv) > 1 else 'status'
    if action == 'status':
        print(json.dumps(get_local_info()))
    elif action == 'discover':
        print(json.dumps(discover_devices()))
    elif action == 'launch':
        print(json.dumps({'success': launch_localsend()}))
    elif action == 'send':
        files = sys.argv[2:]
        print(json.dumps({'success': send_files(files)}))
    else:
        print(json.dumps({'error': f'Unknown action: {action}'}))
