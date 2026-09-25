#!/usr/bin/env python3
"""DeloWay's LocalSend peer: the Notch → Share tab's link to phones and other computers.

A small endpoint of the LocalSend protocol v2 (https://github.com/localsend/protocol), so
the Notch sends and receives on its own instead of keeping the LocalSend app (a Flutter
program) running hidden in the tray. Standard library only. It sleeps in blocking reads
(no polling, no subnet scans) and lives exactly as long as the shell process that started
it (LocalSendService.qml): it exits when its stdin closes.

    deloway-localsend.py serve [--port 53317] [--alias NAME] [--download-dir DIR]
                               [--device-type desktop|mobile|…]

Identity: the LocalSend app's own certificate and name when that app was set up here (so
phones that already know this computer still recognise it), else a new self-signed one in
$XDG_DATA_HOME/deloway/localsend. Discovery is the protocol's own: a multicast
announcement on 224.0.0.167:53317 that other LocalSend devices answer.

The shell talks to it in JSON lines — commands on stdin, events on stdout:

  commands  {"cmd":"scan"}                                announce on every LAN
            {"cmd":"probe","ip":…,"port":…}               reach one device directly
            {"cmd":"send","device":{…},"files":[paths]}
            {"cmd":"cancel-send"}
            {"cmd":"accept"|"decline","sessionId":…}      answer an incoming transfer
            {"cmd":"cancel-receive","sessionId":…}
  events    ready, network, device, probe-failed,
            incoming, receive-progress, received, receive-ended,
            send-status (connecting | sending | sent | failed | cancelled)
"""

import argparse
import errno
import hashlib
import http.client
import json
import mimetypes
import os
import shutil
import socket
import ssl
import subprocess
import sys
import threading
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

PROTOCOL_VERSION = '2.1'
MCAST_GROUP = '224.0.0.167'
MCAST_PORT = 53317
DEFAULT_PORT = 53317
ACCEPT_TIMEOUT = 120          # seconds the user has to accept an incoming transfer
CHUNK = 256 * 1024
PROGRESS_INTERVAL = 0.15      # seconds between progress events

DATA_HOME = os.environ.get('XDG_DATA_HOME') or os.path.expanduser('~/.local/share')
STATE_DIR = os.path.join(DATA_HOME, 'deloway', 'localsend')
APP_PREFS = os.path.join(DATA_HOME, 'org.localsend.localsend_app', 'shared_preferences.json')

# Interfaces that never lead to a phone: loopback, containers, VMs, VPN tunnels.
SKIP_IFACES = ('lo', 'docker', 'veth', 'br-', 'virbr', 'vnet', 'tun', 'tap', 'wg', 'tailscale')

_out_lock = threading.Lock()


def emit(event, **fields):
    fields['event'] = event
    line = json.dumps(fields, ensure_ascii=False)
    with _out_lock:
        try:
            sys.stdout.write(line + '\n')
            sys.stdout.flush()
        except (BrokenPipeError, ValueError):
            os._exit(0)   # the shell is gone


# ── Identity ────────────────────────────────────────────────────────────────

def read_app_prefs():
    try:
        with open(APP_PREFS, encoding='utf-8') as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def _write_private(path, text):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, 'w') as f:
        f.write(text)


def load_identity(prefs):
    """(cert path, key path, fingerprint). The fingerprint is what LocalSend uses: the
    SHA-256 of the certificate's DER bytes, upper-case hex."""
    cert = os.path.join(STATE_DIR, 'cert.pem')
    key = os.path.join(STATE_DIR, 'key.pem')
    if not (os.path.isfile(cert) and os.path.isfile(key)):
        os.makedirs(STATE_DIR, mode=0o700, exist_ok=True)
        sec = None
        try:
            sec = json.loads(prefs.get('flutter.ls_security_context') or 'null')
        except ValueError:
            pass
        if sec and sec.get('certificate') and sec.get('privateKey'):
            _write_private(key, sec['privateKey'])
            _write_private(cert, sec['certificate'])
        else:
            subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
                            '-keyout', key, '-out', cert, '-days', '36500',
                            '-subj', '/CN=LocalSend User'],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            os.chmod(key, 0o600)
    with open(cert, encoding='ascii') as f:
        der = ssl.PEM_cert_to_DER_cert(f.read())
    return cert, key, hashlib.sha256(der).hexdigest().upper()


def app_favorites(prefs):
    """Devices saved as favourites in the LocalSend app — offered once as paired devices."""
    out = []
    for raw in prefs.get('flutter.ls_favorites') or []:
        try:
            fav = json.loads(raw)
        except ValueError:
            continue
        if fav.get('fingerprint') and fav.get('ip'):
            out.append({'fingerprint': fav['fingerprint'], 'alias': fav.get('alias') or fav['ip'],
                        'ip': fav['ip'], 'port': int(fav.get('port') or DEFAULT_PORT),
                        'protocol': 'https', 'deviceType': 'mobile', 'deviceModel': ''})
    return out


def download_dir(explicit):
    if explicit:
        path = explicit
    else:
        path = ''
        if shutil.which('xdg-user-dir'):
            try:
                path = subprocess.run(['xdg-user-dir', 'DOWNLOAD'], capture_output=True,
                                      text=True, timeout=3).stdout.strip()
            except (OSError, subprocess.SubprocessError):
                path = ''
        if not path or os.path.realpath(path) == os.path.realpath(os.path.expanduser('~')):
            path = os.path.expanduser('~/Downloads')
    os.makedirs(path, exist_ok=True)
    return path


# ── Network ─────────────────────────────────────────────────────────────────

def lan_addresses():
    """[(interface, IPv4)] of every connected LAN — Ethernet, Wi-Fi, and this computer's
    own hotspot, where a phone joined to it lives."""
    try:
        out = subprocess.run(['ip', '-j', '-4', 'addr', 'show', 'up'], capture_output=True,
                             text=True, timeout=3).stdout
        links = json.loads(out or '[]')
    except (OSError, ValueError, subprocess.SubprocessError):
        return []
    result = []
    for link in links:
        name = link.get('ifname', '')
        flags = link.get('flags', [])
        if name.startswith(SKIP_IFACES) or 'MULTICAST' not in flags or 'LOWER_UP' not in flags:
            continue
        for addr in link.get('addr_info', []):
            if addr.get('family') == 'inet' and addr.get('local'):
                result.append((name, addr['local']))
    return result


def client_context():
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE   # LocalSend peers use self-signed certificates
    return ctx


def connect(device, timeout):
    ip, port = device['ip'], int(device.get('port') or DEFAULT_PORT)
    if device.get('protocol', 'https') == 'http':
        return http.client.HTTPConnection(ip, port, timeout=timeout)
    return http.client.HTTPSConnection(ip, port, timeout=timeout, context=client_context())


def request_json(device, method, path, payload=None, timeout=5):
    """(status, parsed body or None). Raises OSError / http.client errors on no answer."""
    conn = connect(device, timeout)
    try:
        body = json.dumps(payload).encode() if payload is not None else None
        headers = {'Content-Type': 'application/json'} if body is not None else {}
        conn.request(method, path, body=body, headers=headers)
        resp = conn.getresponse()
        data = resp.read()
        try:
            parsed = json.loads(data) if data else None
        except ValueError:
            parsed = None
        return resp.status, parsed
    finally:
        conn.close()


def device_from(info, ip, via):
    return {
        'fingerprint': str(info.get('fingerprint') or ''),
        'alias': str(info.get('alias') or ip)[:64],
        'deviceType': str(info.get('deviceType') or 'desktop'),
        'deviceModel': str(info.get('deviceModel') or '')[:64],
        'ip': ip,
        'port': int(info.get('port') or DEFAULT_PORT),
        'protocol': 'http' if info.get('protocol') == 'http' else 'https',
        'via': via,
    }


def safe_relative(name):
    """A received file's name as a path inside the download folder: folder transfers send
    "dir/sub/file", which is kept; anything that climbs out is dropped."""
    parts = [p for p in str(name).replace('\\', '/').split('/') if p not in ('', '.', '..')]
    parts = [p.lstrip('.') or '_' for p in parts]   # no hidden files from a stranger
    return os.path.join(*parts) if parts else 'file'


def unique_path(path):
    if not os.path.exists(path):
        return path
    stem, ext = os.path.splitext(path)
    n = 1
    while os.path.exists(f'{stem} ({n}){ext}'):
        n += 1
    return f'{stem} ({n}){ext}'


# ── The peer ────────────────────────────────────────────────────────────────

class Peer:
    def __init__(self, args):
        prefs = read_app_prefs()
        self.cert, self.key, self.fingerprint = load_identity(prefs)
        self.alias = (args.alias or prefs.get('flutter.ls_alias') or socket.gethostname())[:64]
        self.port = args.port
        self.device_type = args.device_type
        self.download_dir = download_dir(args.download_dir)
        self.favorites = app_favorites(prefs)
        self.lock = threading.Lock()
        self.pending = {}         # sessionId → {'event', 'accepted', 'sender', 'files'}
        self.session = None       # the accepted incoming transfer
        self.sender = None        # the outgoing transfer
        self.mcast = None
        self.mcast_lock = threading.Lock()
        self.joined = set()
        self.receiving = False
        self.error = ''

    def info(self, with_endpoint=True):
        info = {'alias': self.alias, 'version': PROTOCOL_VERSION, 'deviceModel': 'Linux',
                'deviceType': self.device_type, 'fingerprint': self.fingerprint, 'download': False}
        if with_endpoint:
            info.update(port=self.port, protocol='https')
        return info

    # Multicast ──────────────────────────────────────────────────────────────
    def open_multicast(self):
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        if hasattr(socket, 'SO_REUSEPORT'):
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
        s.bind(('', MCAST_PORT))
        self.mcast = s
        self.join_groups()
        threading.Thread(target=self.multicast_loop, daemon=True).start()

    def join_groups(self):
        addrs = lan_addresses()
        if self.mcast:
            for _, ip in addrs:
                if ip in self.joined:
                    continue
                mreq = socket.inet_aton(MCAST_GROUP) + socket.inet_aton(ip)
                try:
                    self.mcast.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, mreq)
                except OSError:
                    pass   # already a member through this address
                self.joined.add(ip)
        return addrs

    def multicast_send(self, message):
        if not self.mcast:
            return []
        data = json.dumps(message).encode()
        addrs = self.join_groups()
        with self.mcast_lock:
            for _, ip in addrs:
                try:
                    self.mcast.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_IF, socket.inet_aton(ip))
                    self.mcast.sendto(data, (MCAST_GROUP, MCAST_PORT))
                except OSError:
                    pass
        return addrs

    def announce(self):
        addrs = self.multicast_send(dict(self.info(), announce=True, announcement=True))
        if not self.mcast:
            addrs = lan_addresses()
        emit('network', addresses=[{'interface': n, 'ip': ip} for n, ip in addrs])

    def multicast_loop(self):
        while True:
            try:
                data, (ip, _) = self.mcast.recvfrom(65536)
                msg = json.loads(data)
            except OSError:
                return
            except ValueError:
                continue
            if not isinstance(msg, dict) or msg.get('fingerprint') in (None, '', self.fingerprint):
                continue
            dev = device_from(msg, ip, 'multicast')
            emit('device', device=dev)
            if msg.get('announce') or msg.get('announcement'):
                threading.Thread(target=self.answer_announcement, args=(dev,), daemon=True).start()

    def answer_announcement(self, dev):
        # The protocol's answer to an announcement: register over HTTP, else multicast back.
        try:
            status, _ = request_json(dev, 'POST', '/api/localsend/v2/register', self.info(), timeout=3)
            if status == 200:
                return
        except (OSError, http.client.HTTPException):
            pass
        self.multicast_send(dict(self.info(), announce=False, announcement=False))

    def probe(self, ip, port):
        for protocol in ('https', 'http'):
            dev = {'ip': ip, 'port': port, 'protocol': protocol}
            try:
                status, body = request_json(dev, 'POST', '/api/localsend/v2/register', self.info(), timeout=3)
                if status != 200 or not isinstance(body, dict):
                    status, body = request_json(dev, 'GET', '/api/localsend/v2/info', timeout=3)
                if status == 200 and isinstance(body, dict) and body.get('fingerprint') != self.fingerprint:
                    body.setdefault('port', port)
                    body['protocol'] = protocol
                    emit('device', device=device_from(body, ip, 'probe'))
                    return
            except (OSError, http.client.HTTPException, ValueError):
                continue
        emit('probe-failed', ip=ip, port=port)

    # Receiving ──────────────────────────────────────────────────────────────
    def start_server(self):
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ctx.load_cert_chain(self.cert, self.key)
        peer = self

        class Server(ThreadingHTTPServer):
            daemon_threads = True
            allow_reuse_address = True
            request_queue_size = 16

            def get_request(self):
                sock, addr = super().get_request()
                # The TLS handshake runs in the request's own thread, not in accept().
                return ctx.wrap_socket(sock, server_side=True, do_handshake_on_connect=False), addr

            def handle_error(self, request, client_address):
                pass   # a phone dropping a connection is not worth a traceback

        class Handler(RequestHandler):
            pass
        Handler.peer = peer
        try:
            self.server = Server(('0.0.0.0', self.port), Handler)
        except OSError as exc:
            self.error = 'port_busy' if exc.errno == errno.EADDRINUSE else 'server_failed'
            return
        self.receiving = True
        threading.Thread(target=self.server.serve_forever, daemon=True).start()

    def answer(self, session_id, accepted):
        with self.lock:
            pending = self.pending.get(session_id)
        if pending:
            pending['accepted'] = bool(accepted)
            pending['event'].set()

    def cancel_receive(self, session_id):
        with self.lock:
            sess = self.session
            if sess and sess['id'] == session_id:
                sess['cancelled'] = True
                self.session = None
            else:
                sess = None
        if sess:
            emit('receive-ended', sessionId=session_id, reason='cancelled')
        else:
            self.answer(session_id, False)

    # Sending ────────────────────────────────────────────────────────────────
    def send(self, device, files):
        if self.sender and self.sender.is_alive():
            emit('send-status', status='failed', error='busy')
            return
        self.sender = Sender(self, device, files)
        self.sender.start()

    def cancel_send(self):
        if self.sender and self.sender.is_alive():
            self.sender.cancel()


class RequestHandler(BaseHTTPRequestHandler):
    peer = None
    protocol_version = 'HTTP/1.1'
    server_version = 'LocalSend'
    sys_version = ''
    timeout = 60

    def log_message(self, *args):
        pass

    def reply(self, code, obj=None):
        body = json.dumps(obj).encode() if obj is not None else b''
        self.send_response(code)
        if obj is not None:
            self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        if code >= 400:
            self.send_header('Connection', 'close')
            self.close_connection = True
        self.end_headers()
        self.wfile.write(body)

    def read_json(self, limit=4 << 20):
        try:
            n = int(self.headers.get('Content-Length') or 0)
        except ValueError:
            return None
        if n <= 0 or n > limit:
            return None
        try:
            return json.loads(self.rfile.read(n))
        except ValueError:
            return None

    def body_chunks(self):
        if 'chunked' in (self.headers.get('Transfer-Encoding') or '').lower():
            while True:
                size = int(self.rfile.readline().split(b';')[0].strip() or b'0', 16)
                if size == 0:
                    self.rfile.readline()
                    return
                left = size
                while left:
                    chunk = self.rfile.read(min(CHUNK, left))
                    if not chunk:
                        raise ConnectionError('closed')
                    left -= len(chunk)
                    yield chunk
                self.rfile.readline()
        else:
            left = int(self.headers.get('Content-Length') or 0)
            while left:
                chunk = self.rfile.read(min(CHUNK, left))
                if not chunk:
                    raise ConnectionError('closed')
                left -= len(chunk)
                yield chunk

    def route(self):
        url = urlparse(self.path)
        query = {k: v[0] for k, v in parse_qs(url.query).items()}
        return url.path.rstrip('/'), query

    def do_GET(self):
        path, _ = self.route()
        if path in ('/api/localsend/v2/info', '/api/localsend/v1/info'):
            self.reply(200, self.peer.info(with_endpoint=False))
        else:
            self.reply(404)

    def do_POST(self):
        path, query = self.route()
        handlers = {
            '/api/localsend/v2/register': self.register,
            '/api/localsend/v2/prepare-upload': self.prepare_upload,
            '/api/localsend/v2/upload': self.upload,
            '/api/localsend/v2/cancel': self.cancel,
        }
        handler = handlers.get(path)
        if handler:
            handler(query)
        else:
            self.reply(404)

    def register(self, _query):
        body = self.read_json()
        if not isinstance(body, dict) or body.get('fingerprint') == self.peer.fingerprint:
            self.reply(400)
            return
        emit('device', device=device_from(body, self.client_address[0], 'register'))
        self.reply(200, self.peer.info(with_endpoint=False))

    def prepare_upload(self, _query):
        peer = self.peer
        body = self.read_json()
        if not isinstance(body, dict) or not isinstance(body.get('info'), dict) \
                or not isinstance(body.get('files'), dict):
            self.reply(400)
            return
        files = {}
        for fid, meta in body['files'].items():
            if not isinstance(meta, dict):
                continue
            try:
                size = max(0, int(meta.get('size') or 0))
            except (TypeError, ValueError):
                size = 0
            files[str(fid)] = {'name': safe_relative(meta.get('fileName') or fid), 'size': size,
                               'type': str(meta.get('fileType') or '')}
        if not files:
            self.reply(204)
            return
        sender = device_from(body['info'], self.client_address[0], 'upload')
        sid = uuid.uuid4().hex
        pending = {'event': threading.Event(), 'accepted': False}
        with peer.lock:
            if peer.session or peer.pending:
                self.reply(409)
                return
            peer.pending[sid] = pending
        emit('device', device=sender)
        emit('incoming', sessionId=sid, sender=sender,
             files=[{'name': f['name'], 'size': f['size'], 'type': f['type']} for f in files.values()],
             totalSize=sum(f['size'] for f in files.values()))
        answered = pending['event'].wait(ACCEPT_TIMEOUT)
        with peer.lock:
            peer.pending.pop(sid, None)
            accepted = answered and pending['accepted']
            if accepted:
                for f in files.values():
                    f['token'] = uuid.uuid4().hex
                    f['done'] = False
                peer.session = {'id': sid, 'ip': self.client_address[0], 'sender': sender,
                                'files': files, 'received': 0, 'saved': [], 'cancelled': False,
                                'total': sum(f['size'] for f in files.values()), 'last': 0.0}
        if not accepted:
            reason = 'cancelled' if pending.get('cancelled') else ('declined' if answered else 'expired')
            emit('receive-ended', sessionId=sid, reason=reason)
            self.reply(403)
            return
        self.reply(200, {'sessionId': sid, 'files': {fid: f['token'] for fid, f in files.items()}})

    def upload(self, query):
        peer = self.peer
        with peer.lock:
            sess = peer.session
        fid = query.get('fileId', '')
        if not sess or query.get('sessionId') != sess['id'] or self.client_address[0] != sess['ip']:
            self.reply(403)
            return
        meta = sess['files'].get(fid)
        if not meta or meta['done'] or query.get('token') != meta['token']:
            self.reply(403)
            return
        target = os.path.join(peer.download_dir, meta['name'])
        os.makedirs(os.path.dirname(target), exist_ok=True)
        part = os.path.join(os.path.dirname(target), f".{os.path.basename(target)}.{sess['id'][:8]}.part")
        try:
            with open(part, 'wb') as out:
                for chunk in self.body_chunks():
                    if sess['cancelled']:
                        raise ConnectionError('cancelled')
                    out.write(chunk)
                    sess['received'] += len(chunk)
                    now = time.monotonic()
                    if now - sess['last'] >= PROGRESS_INTERVAL:
                        sess['last'] = now
                        emit('receive-progress', sessionId=sess['id'], received=sess['received'],
                             total=sess['total'], file=os.path.basename(meta['name']))
            final = unique_path(target)
            os.replace(part, final)
        except (OSError, ConnectionError, ValueError):
            try:
                os.unlink(part)
            except OSError:
                pass
            if not sess['cancelled']:
                with peer.lock:
                    if peer.session is sess:
                        peer.session = None
                emit('receive-ended', sessionId=sess['id'], reason='failed')
            self.close_connection = True
            return
        with peer.lock:   # uploads may run in parallel: exactly one of them finishes
            meta['done'] = True
            sess['saved'].append(final)
            finished = all(f['done'] for f in sess['files'].values()) and peer.session is sess
            if finished:
                peer.session = None
        if finished:
            emit('received', sessionId=sess['id'], sender=sess['sender'], files=sess['saved'],
                 total=sess['total'], folder=peer.download_dir)
        self.reply(200)

    def cancel(self, query):
        peer = self.peer
        sid = query.get('sessionId', '')
        with peer.lock:
            sess = peer.session
            pending = next(iter(peer.pending.values()), None) if not sid else peer.pending.get(sid)
            if sess and (not sid or sess['id'] == sid) and self.client_address[0] == sess['ip']:
                sess['cancelled'] = True
                peer.session = None
            else:
                sess = None
        if sess:
            emit('receive-ended', sessionId=sess['id'], reason='cancelled')
        elif pending:
            pending['accepted'] = False
            pending['cancelled'] = True
            pending['event'].set()
        self.reply(200)


class Sender(threading.Thread):
    def __init__(self, peer, device, paths):
        super().__init__(daemon=True)
        self.peer = peer
        self.device = device
        self.paths = [p for p in paths if isinstance(p, str) and os.path.isfile(p)]
        self.cancelled = False
        self.conn = None

    def cancel(self):
        self.cancelled = True
        conn = self.conn
        if conn is not None and conn.sock is not None:
            try:   # wakes the thread blocked waiting for the receiver to accept
                conn.sock.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass

    def status(self, status, **fields):
        emit('send-status', status=status, device=self.device.get('alias') or self.device.get('ip'), **fields)

    def run(self):
        if not self.paths:
            self.status('failed', error='no_files')
            return
        files = {}
        for path in self.paths:
            fid = uuid.uuid4().hex[:12]
            files[fid] = {'path': path, 'id': fid, 'fileName': os.path.basename(path),
                          'size': os.path.getsize(path),
                          'fileType': mimetypes.guess_type(path)[0] or 'application/octet-stream'}
        total = sum(f['size'] for f in files.values())
        payload = {'info': self.peer.info(),
                   'files': {fid: {k: f[k] for k in ('id', 'fileName', 'size', 'fileType')}
                             for fid, f in files.items()}}
        self.status('connecting', total=total)
        # The receiver's user has to accept first: wait as long as they do.
        self.conn = connect(self.device, ACCEPT_TIMEOUT + 10)
        try:
            self.conn.request('POST', '/api/localsend/v2/prepare-upload', body=json.dumps(payload).encode(),
                              headers={'Content-Type': 'application/json'})
            resp = self.conn.getresponse()
            data = resp.read()
            status = resp.status
            try:
                body = json.loads(data) if data else None
            except ValueError:
                body = None
        except TimeoutError:
            if not self.cancelled:
                self.status('failed', error='timeout')
                return
        except (OSError, http.client.HTTPException) as exc:
            if not self.cancelled:   # detail: refused, TLS, no route… (the shell logs it)
                self.status('failed', error='unreachable', detail=f'{type(exc).__name__}: {exc}'[:200])
                return
        finally:
            self.conn.close()
            self.conn = None
        if self.cancelled:
            try:   # no session yet: the receiver drops its pending request
                request_json(self.device, 'POST', '/api/localsend/v2/cancel', timeout=3)
            except (OSError, http.client.HTTPException):
                pass
            self.status('cancelled')
            return
        if status == 204:
            self.status('sent', total=total)
            return
        if status != 200 or not isinstance(body, dict) or not isinstance(body.get('files'), dict):
            error = {401: 'pin', 403: 'declined', 409: 'busy', 429: 'busy'}.get(status, 'failed')
            self.status('failed', error=error, detail=f'HTTP {status}')
            return
        session = body.get('sessionId', '')
        sent, last = 0, 0.0
        for fid, token in body['files'].items():
            meta = files.get(fid)
            if not meta:
                continue
            conn = connect(self.device, 60)
            try:
                conn.putrequest('POST', f'/api/localsend/v2/upload?sessionId={session}&fileId={fid}&token={token}')
                conn.putheader('Content-Length', str(meta['size']))
                conn.putheader('Content-Type', 'application/octet-stream')
                conn.endheaders()
                with open(meta['path'], 'rb') as f:
                    while True:
                        if self.cancelled:
                            raise InterruptedError
                        chunk = f.read(CHUNK)
                        if not chunk:
                            break
                        conn.send(chunk)
                        sent += len(chunk)
                        now = time.monotonic()
                        if now - last >= PROGRESS_INTERVAL:
                            last = now
                            self.status('sending', sent=sent, total=total, file=meta['fileName'])
                resp = conn.getresponse()
                resp.read()
                if resp.status != 200:
                    self.status('failed', error='failed')
                    return
            except InterruptedError:
                conn.close()
                try:
                    request_json(self.device, 'POST', f'/api/localsend/v2/cancel?sessionId={session}', timeout=3)
                except (OSError, http.client.HTTPException):
                    pass
                self.status('cancelled')
                return
            except (OSError, http.client.HTTPException) as exc:
                self.status('failed', error='interrupted', detail=f'{type(exc).__name__}: {exc}'[:200])
                return
            finally:
                conn.close()
        self.status('sent', sent=total, total=total)


def serve(args):
    peer = Peer(args)
    peer.start_server()
    try:
        peer.open_multicast()
    except OSError:
        peer.mcast = None
    # Port taken: by the LocalSend app itself, or by something else.
    app_running = bool(peer.error == 'port_busy' and shutil.which('pgrep') and subprocess.run(
        ['pgrep', '-x', 'localsend'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0)
    emit('ready', alias=peer.alias, fingerprint=peer.fingerprint, port=peer.port,
         receiving=peer.receiving, error=peer.error, appRunning=app_running,
         multicast=peer.mcast is not None,
         downloadDir=peer.download_dir, appFavorites=peer.favorites)
    peer.announce()

    for line in sys.stdin:
        try:
            cmd = json.loads(line)
        except ValueError:
            continue
        if not isinstance(cmd, dict):
            continue
        name = cmd.get('cmd')
        if name == 'scan':
            peer.announce()
        elif name == 'probe' and cmd.get('ip'):
            threading.Thread(target=peer.probe, daemon=True,
                             args=(str(cmd['ip']), int(cmd.get('port') or DEFAULT_PORT))).start()
        elif name == 'send' and isinstance(cmd.get('device'), dict):
            peer.send(cmd['device'], cmd.get('files') or [])
        elif name == 'cancel-send':
            peer.cancel_send()
        elif name in ('accept', 'decline'):
            peer.answer(cmd.get('sessionId', ''), name == 'accept')
        elif name == 'cancel-receive':
            peer.cancel_receive(cmd.get('sessionId', ''))
    os._exit(0)   # stdin closed: the shell that owns this peer is gone


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('action', choices=['serve'])
    parser.add_argument('--port', type=int, default=DEFAULT_PORT)
    parser.add_argument('--alias', default='')
    parser.add_argument('--download-dir', default='')
    parser.add_argument('--device-type', default='desktop',
                        choices=['mobile', 'desktop', 'web', 'headless', 'server'])
    serve(parser.parse_args())


if __name__ == '__main__':
    main()
