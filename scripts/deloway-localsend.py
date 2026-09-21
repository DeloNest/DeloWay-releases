#!/usr/bin/env python3
"""
Deloway LocalSend Integration Helper
Provides status inspection, real network discovery with paired/favorite devices,
and transfer initiation for Quickshell.
"""

import sys
import json
import os
import socket
import ssl
import urllib.request
import urllib.error
import http.client
import uuid
import subprocess
import tempfile
from concurrent.futures import ThreadPoolExecutor

PREFS_FILE = os.path.expanduser('~/.local/share/org.localsend.localsend_app/shared_preferences.json')
LOCALSEND_BIN = os.path.expanduser('~/.local/bin/localsend')
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
    for name in ['localsend', 'localsend_app']:
        try:
            res = subprocess.run(['pgrep', '-x', name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if res.returncode == 0:
                return True
        except Exception:
            pass

    local_ip = get_local_ip()
    for host in ['127.0.0.1', local_ip]:
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(0.12)
            if sock.connect_ex((host, PORT)) == 0:
                sock.close()
                return True
            sock.close()
        except Exception:
            pass
    return False

def get_ssl_context():
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    if os.path.exists(PREFS_FILE):
        try:
            with open(PREFS_FILE, 'r', encoding='utf-8') as f:
                data = json.load(f)
                sec_raw = data.get('flutter.ls_security_context')
                if sec_raw:
                    sec = json.loads(sec_raw)
                    cert_pem = sec.get('certificate')
                    key_pem = sec.get('privateKey')
                    if cert_pem and key_pem:
                        with tempfile.NamedTemporaryFile('w', delete=False) as cf, tempfile.NamedTemporaryFile('w', delete=False) as kf:
                            cf.write(cert_pem)
                            cf.flush()
                            kf.write(key_pem)
                            kf.flush()
                            cf_name = cf.name
                            kf_name = kf.name
                        try:
                            ctx.load_cert_chain(certfile=cf_name, keyfile=kf_name)
                        finally:
                            if os.path.exists(cf_name): os.unlink(cf_name)
                            if os.path.exists(kf_name): os.unlink(kf_name)
        except Exception:
            pass
    return ctx

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
                        fav_obj = json.loads(fav)
                        fav_obj['isFavorite'] = True
                        if 'deviceType' not in fav_obj:
                            fav_obj['deviceType'] = 'mobile'
                        favorites.append(fav_obj)
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
    base = f"{parts[0]}.{parts[1]}.{parts[2]}." if len(parts) == 4 else ""

    devices_dict = {}

    # 1. First add all paired favorites (such as user's phone)
    for fav in info.get('favorites', []):
        fav_id = fav.get('id') or fav.get('ip') or fav.get('alias')
        ip = fav.get('ip')
        is_online = False
        if ip and ip != local_ip:
            # Fast ping probe (1 packet, 0.5s timeout)
            res = subprocess.run(['ping', '-c', '1', '-W', '1', ip], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            is_online = (res.returncode == 0)
        fav['isOnline'] = is_online
        fav['isFavorite'] = True
        devices_dict[fav_id] = fav

    # 2. Parallel scan of local network subnet for port 53317
    if base:
        ctx = get_ssl_context()
        ips_to_scan = [f"{base}{i}" for i in range(1, 255) if f"{base}{i}" != local_ip]

        def probe_ip(ip):
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(0.12)
            try:
                res = sock.connect_ex((ip, PORT))
            except Exception:
                res = -1
            finally:
                sock.close()

            if res == 0:
                # Query device info via API
                for scheme in ['https', 'http']:
                    try:
                        url = f"{scheme}://{ip}:{PORT}/api/localsend/v2/info"
                        req = urllib.request.Request(url, headers={'User-Agent': 'LocalSend'})
                        with urllib.request.urlopen(req, context=ctx, timeout=0.6) as r:
                            d = json.loads(r.read().decode('utf-8'))
                            d['ip'] = ip
                            d['port'] = PORT
                            d['isOnline'] = True
                            return d
                    except Exception:
                        pass
                return {
                    'ip': ip,
                    'alias': f"Device ({ip})",
                    'deviceType': 'mobile',
                    'deviceModel': 'Network Device',
                    'port': PORT,
                    'isOnline': True
                }
            return None

        with ThreadPoolExecutor(max_workers=50) as executor:
            for discovered in executor.map(probe_ip, ips_to_scan):
                if discovered:
                    dev_id = discovered.get('id') or discovered.get('ip')
                    matched = False
                    for fid, existing in list(devices_dict.items()):
                        if (existing.get('id') and existing.get('id') == discovered.get('id')) or \
                           (existing.get('fingerprint') and existing.get('fingerprint') == discovered.get('fingerprint')) or \
                           (existing.get('alias') and existing.get('alias') == discovered.get('alias')):
                            existing.update(discovered)
                            existing['isFavorite'] = True
                            existing['isOnline'] = True
                            matched = True
                            break
                    if not matched:
                        discovered['isFavorite'] = False
                        devices_dict[dev_id] = discovered

    dev_list = list(devices_dict.values())
    dev_list.sort(key=lambda d: (not d.get('isFavorite', False), not d.get('isOnline', False)))
    return dev_list

def launch_localsend():
    if is_localsend_running():
        return True
    try:
        env = os.environ.copy()
        env['GDK_BACKEND'] = 'wayland'
        subprocess.Popen([LOCALSEND_BIN], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        return True
    except Exception:
        return False

def send_files(target_ip, target_port, files, pin=None):
    if not files:
        print(json.dumps({'type': 'failed', 'error': 'No files provided'}))
        sys.stdout.flush()
        return False

    clean_files = [f.replace('file://', '') for f in files if f]
    clean_files = [f for f in clean_files if os.path.isfile(f)]
    if not clean_files:
        print(json.dumps({'type': 'failed', 'error': 'Selected files do not exist'}))
        sys.stdout.flush()
        return False

    # 1. Build file metadata
    files_meta = {}
    total_bytes = 0
    for idx, path in enumerate(clean_files):
        fid = f"delo-{idx}-{uuid.uuid4().hex[:8]}"
        size = os.path.getsize(path)
        name = os.path.basename(path)
        ext = os.path.splitext(name)[1].lower()
        if ext in ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg', '.bmp']:
            ftype = 'image'
        elif ext in ['.mp4', '.mkv', '.webm', '.avi', '.mov']:
            ftype = 'video'
        elif ext in ['.pdf']:
            ftype = 'pdf'
        elif ext in ['.txt', '.md', '.log', '.json', '.xml', '.csv']:
            ftype = 'text'
        elif ext in ['.apk']:
            ftype = 'apk'
        else:
            ftype = 'other'

        files_meta[fid] = {
            'id': fid,
            'fileName': name,
            'size': size,
            'fileType': ftype,
            '_path': path
        }
        total_bytes += size

    local_info = get_local_info()
    ctx = get_ssl_context()

    # 2. Phase 1: prepare-upload
    print(json.dumps({'type': 'connecting', 'message': f'Connecting to {target_ip}...'}))
    sys.stdout.flush()

    session_id = None
    response_files = {}
    active_scheme = 'https'

    info_payload = {
        'info': {
            'alias': local_info.get('alias', 'Deloway'),
            'version': '2.0',
            'deviceModel': 'Linux (DeloOS)',
            'deviceType': 'desktop',
            'fingerprint': 'deloway-desktop-fingerprint',
            'port': PORT,
            'protocol': 'https',
            'download': False
        },
        'files': {
            fid: {
                'id': f['id'],
                'fileName': f['fileName'],
                'size': f['size'],
                'fileType': f['fileType']
            } for fid, f in files_meta.items()
        }
    }

    prepare_success = False
    schemes = ['https', 'http']
    last_error = ''

    for scheme in schemes:
        url = f"{scheme}://{target_ip}:{target_port}/api/localsend/v2/prepare-upload"
        if pin:
            url += f"?pin={pin}"

        req = urllib.request.Request(
            url,
            data=json.dumps(info_payload).encode('utf-8'),
            headers={
                'Content-Type': 'application/json',
                'User-Agent': 'LocalSend/2.0'
            },
            method='POST'
        )
        try:
            # 60s timeout to allow recipient user to click Accept on their screen
            with urllib.request.urlopen(req, context=ctx if scheme == 'https' else None, timeout=60) as resp:
                if resp.status == 200:
                    resp_data = json.loads(resp.read().decode('utf-8'))
                    session_id = resp_data.get('sessionId')
                    response_files = resp_data.get('files', {})
                    active_scheme = scheme
                    prepare_success = True
                    break
        except urllib.error.HTTPError as e:
            if e.code == 403:
                print(json.dumps({'type': 'failed', 'error': 'Recipient declined transfer (403)'}))
                sys.stdout.flush()
                return False
            elif e.code == 401:
                print(json.dumps({'type': 'failed', 'error': 'PIN required by recipient (401)'}))
                sys.stdout.flush()
                return False
            else:
                last_error = f"HTTP {e.code}: {e.reason}"
        except Exception as e:
            last_error = str(e)
            continue

    if not prepare_success or not session_id or not response_files:
        err_msg = last_error or 'Recipient unreachable or declined'
        print(json.dumps({'type': 'failed', 'error': f'Failed to initiate transfer: {err_msg}'}))
        sys.stdout.flush()
        return False

    # 3. Phase 2: upload each accepted file
    uploaded_total = 0
    print(json.dumps({
        'type': 'progress',
        'progress': 0.0,
        'uploaded': 0,
        'total': total_bytes,
        'file': ''
    }))
    sys.stdout.flush()

    for fid, token in response_files.items():
        if fid not in files_meta:
            continue
        file_info = files_meta[fid]
        file_path = file_info['_path']
        file_size = file_info['size']
        file_name = file_info['fileName']

        try:
            if active_scheme == 'https':
                conn = http.client.HTTPSConnection(target_ip, target_port, context=ctx, timeout=60)
            else:
                conn = http.client.HTTPConnection(target_ip, target_port, timeout=60)

            path_query = f"/api/localsend/v2/upload?sessionId={session_id}&fileId={fid}&token={token}"
            conn.putrequest("POST", path_query)
            conn.putheader("Content-Length", str(file_size))
            conn.putheader("Content-Type", "application/octet-stream")
            conn.endheaders()

            with open(file_path, 'rb') as f:
                chunk_size = 65536  # 64 KB
                while True:
                    chunk = f.read(chunk_size)
                    if not chunk:
                        break
                    conn.send(chunk)
                    uploaded_total += len(chunk)
                    pct = min(1.0, uploaded_total / total_bytes) if total_bytes > 0 else 1.0
                    print(json.dumps({
                        'type': 'progress',
                        'progress': round(pct, 3),
                        'uploaded': uploaded_total,
                        'total': total_bytes,
                        'file': file_name
                    }))
                    sys.stdout.flush()

            resp = conn.getresponse()
            if resp.status != 200:
                print(json.dumps({'type': 'failed', 'error': f'Upload failed for {file_name} (HTTP {resp.status})'}))
                sys.stdout.flush()
                conn.close()
                return False
            conn.close()

        except Exception as e:
            print(json.dumps({'type': 'failed', 'error': f'Connection error during upload: {str(e)}'}))
            sys.stdout.flush()
            return False

    print(json.dumps({'type': 'sent', 'message': 'Transfer completed successfully', 'total': total_bytes}))
    sys.stdout.flush()
    return True

if __name__ == '__main__':
    action = sys.argv[1] if len(sys.argv) > 1 else 'status'
    if action == 'status':
        print(json.dumps(get_local_info()))
    elif action == 'discover':
        print(json.dumps(discover_devices()))
    elif action == 'launch':
        print(json.dumps({'success': launch_localsend()}))
    elif action == 'send':
        # Usage: send <target_ip> <target_port> <files...>
        # Or fallback if target_ip is a file: send <files...>
        if len(sys.argv) >= 4 and sys.argv[3].isdigit():
            target_ip = sys.argv[2]
            target_port = int(sys.argv[3])
            files = sys.argv[4:]
            send_files(target_ip, target_port, files)
        else:
            # Fallback to favorite device or localhost
            info = get_local_info()
            favs = info.get('favorites', [])
            if favs and favs[0].get('ip'):
                target_ip = favs[0]['ip']
                target_port = favs[0].get('port', PORT)
                files = sys.argv[2:]
                send_files(target_ip, target_port, files)
            else:
                print(json.dumps({'type': 'failed', 'error': 'No target device specified'}))
                sys.stdout.flush()
    else:
        print(json.dumps({'error': f'Unknown action: {action}'}))
