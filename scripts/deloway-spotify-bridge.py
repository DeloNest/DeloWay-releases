#!/usr/bin/env python3
"""
DeloWay Spotify Bridge Daemon
Connects Quickshell Smart Notch to Spotify via Spicetify WebSocket.
Uses strictly Python standard library (asyncio, socket, hashlib, base64, json).
Zero external pip/pacman dependencies required.
"""

import sys
import os
import asyncio
import hashlib
import base64
import struct
import json
import secrets
import signal
import re

PORT = 9955
HOST = "127.0.0.1"
PROTOCOL_VERSION = 1
GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
ALLOWED_ORIGINS = {
    "https://xpui.app.spotify.com",
    "http://127.0.0.1",
    "http://localhost",
}

def get_token_path():
    runtime_dir = os.environ.get("XDG_RUNTIME_DIR")
    if runtime_dir and os.path.isdir(runtime_dir):
        deloway_dir = os.path.join(runtime_dir, "deloway")
    else:
        deloway_dir = os.path.expanduser("~/.config/deloway")
    os.makedirs(deloway_dir, mode=0o700, exist_ok=True)
    return os.path.join(deloway_dir, "spotify-token")

def get_or_create_token():
    token_file = get_token_path()
    if os.path.isfile(token_file):
        try:
            with open(token_file, "r") as f:
                token = f.read().strip()
                if token:
                    return token
        except Exception:
            pass
    token = secrets.token_hex(24)
    try:
        flags = os.O_WRONLY | os.O_CREAT | os.O_TRUNC
        mode = 0o600
        fd = os.open(token_file, flags, mode)
        with os.fdopen(fd, "w") as f:
            f.write(token + "\n")
    except Exception as e:
        sys.stderr.write(f"[bridge] Warning: Could not write token file {token_file}: {e}\n")
    return token

class SpotifyBridge:
    def __init__(self, token):
        self.token = token
        self.active_client = None  # (reader, writer)
        self.authenticated = False
        self.server = None
        self.liked = False
        self.queue = []

    def emit_shell(self, payload):
        """Send JSON line to Quickshell via stdout."""
        try:
            line = json.dumps(payload, ensure_ascii=False)
            sys.stdout.write(line + "\n")
            sys.stdout.flush()
        except Exception as e:
            sys.stderr.write(f"[bridge] stdout write error: {e}\n")

    async def send_ws_text(self, writer, text):
        """Send a WebSocket text frame (unmasked from server)."""
        payload = text.encode("utf-8")
        length = len(payload)
        frame = bytearray()
        frame.append(0x81)  # FIN + Text
        if length < 126:
            frame.append(length)
        elif length <= 0xFFFF:
            frame.append(126)
            frame.extend(struct.pack("!H", length))
        else:
            frame.append(127)
            frame.extend(struct.pack("!Q", length))
        frame.extend(payload)
        writer.write(frame)
        await writer.drain()

    async def handle_ws_frame(self, opcode, payload, writer):
        if opcode == 0x8:  # Close
            return False
        elif opcode == 0x9:  # Ping -> Pong
            pong = bytearray([0x8A, 0x00])
            writer.write(pong)
            await writer.drain()
            return True
        elif opcode == 0xA:  # Pong
            return True
        elif opcode == 0x1:  # Text frame
            try:
                msg = json.loads(payload.decode("utf-8"))
            except Exception:
                return True

            t = msg.get("t")
            if t == "hello":
                provided_token = msg.get("token", "")
                if secrets.compare_digest(provided_token, self.token):
                    self.authenticated = True
                    self.emit_shell({"v": PROTOCOL_VERSION, "t": "connected", "value": True})
                    await self.send_ws_text(writer, json.dumps({"v": PROTOCOL_VERSION, "t": "hello_ack", "status": "ok"}))
                else:
                    sys.stderr.write("[bridge] Invalid token in hello message\n")
                    return False
            elif t == "state":
                if not self.authenticated:
                    return False
                self.liked = bool(msg.get("liked", False))
                raw_queue = msg.get("queue", [])
                clean_queue = []
                for item in raw_queue[:5]:
                    if isinstance(item, dict):
                        clean_queue.append({
                            "title": str(item.get("title", "")),
                            "artist": str(item.get("artist", "")),
                            "uri": str(item.get("uri", ""))
                        })
                self.queue = clean_queue
                self.emit_shell({
                    "v": PROTOCOL_VERSION,
                    "t": "state",
                    "liked": self.liked,
                    "queue": self.queue
                })
        return True

    async def handle_client(self, reader, writer):
        """Handles HTTP Upgrade and WebSocket connection."""
        client_addr = writer.get_extra_info("peername")
        headers = {}
        request_line = ""

        try:
            line = await asyncio.wait_for(reader.readline(), timeout=5.0)
            if not line:
                writer.close()
                return
            request_line = line.decode("utf-8", errors="ignore").strip()

            while True:
                line = await asyncio.wait_for(reader.readline(), timeout=5.0)
                if not line or line == b"\r\n" or line == b"\n":
                    break
                header_str = line.decode("utf-8", errors="ignore").strip()
                if ":" in header_str:
                    k, v = header_str.split(":", 1)
                    headers[k.strip().lower()] = v.strip()

        except Exception as e:
            sys.stderr.write(f"[bridge] Handshake read error: {e}\n")
            writer.close()
            return

        # Verify Origin header if supplied
        origin = headers.get("origin", "")
        if origin:
            # Check against allowed list or loopback origins
            origin_base = origin.split(":", 2)
            origin_scheme_host = ":".join(origin_base[:2]) if len(origin_base) >= 2 else origin
            allowed = False
            for ao in ALLOWED_ORIGINS:
                if origin == ao or origin.startswith(ao + ":") or origin_scheme_host == ao:
                    allowed = True
                    break
            if not allowed:
                sys.stderr.write(f"[bridge] Rejected connection from unauthorized Origin: {origin}\n")
                writer.write(b"HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n")
                await writer.drain()
                writer.close()
                return

        # Check WebSocket upgrade headers
        if "websocket" not in headers.get("upgrade", "").lower():
            writer.write(b"HTTP/1.1 400 Bad Request\r\nConnection: close\r\n\r\n")
            await writer.drain()
            writer.close()
            return

        ws_key = headers.get("sec-websocket-key", "")
        if not ws_key:
            writer.write(b"HTTP/1.1 400 Bad Request\r\nConnection: close\r\n\r\n")
            await writer.drain()
            writer.close()
            return

        # Token authentication via query string or header
        token_authenticated = False
        if "?" in request_line:
            query = request_line.split("?", 1)[1].split(" ", 1)[0]
            params = dict(part.split("=", 1) for part in query.split("&") if "=" in part)
            if "token" in params and secrets.compare_digest(params["token"], self.token):
                token_authenticated = True

        auth_hdr = headers.get("authorization", "")
        if auth_hdr.startswith("Bearer "):
            if secrets.compare_digest(auth_hdr[7:].strip(), self.token):
                token_authenticated = True

        sec_proto = headers.get("sec-websocket-protocol", "")
        if sec_proto and secrets.compare_digest(sec_proto.strip(), self.token):
            token_authenticated = True

        # Perform handshake accept
        accept_raw = hashlib.sha1((ws_key + GUID).encode("utf-8")).digest()
        accept_str = base64.b64encode(accept_raw).decode("utf-8")

        response = (
            "HTTP/1.1 101 Switching Protocols\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Accept: {accept_str}\r\n"
        )
        if sec_proto and token_authenticated:
            response += f"Sec-WebSocket-Protocol: {sec_proto}\r\n"
        response += "\r\n"

        writer.write(response.encode("utf-8"))
        await writer.drain()

        # If previous client was connected, close it
        if self.active_client and self.active_client[1] != writer:
            try:
                self.active_client[1].close()
            except Exception:
                pass

        self.active_client = (reader, writer)
        self.authenticated = token_authenticated
        if self.authenticated:
            self.emit_shell({"v": PROTOCOL_VERSION, "t": "connected", "value": True})

        # Frame reading loop
        try:
            while True:
                hdr = await reader.readexactly(2)
                byte1, byte2 = hdr[0], hdr[1]
                fin = (byte1 & 0x80) != 0
                opcode = byte1 & 0x0F
                masked = (byte2 & 0x80) != 0
                payload_len = byte2 & 0x7F

                if payload_len == 126:
                    ext = await reader.readexactly(2)
                    payload_len = struct.unpack("!H", ext)[0]
                elif payload_len == 127:
                    ext = await reader.readexactly(8)
                    payload_len = struct.unpack("!Q", ext)[0]

                if payload_len > 65536:
                    # Exceeded max frame size
                    break

                mask_key = b""
                if masked:
                    mask_key = await reader.readexactly(4)

                payload = await reader.readexactly(payload_len)
                if masked:
                    payload = bytes(b ^ mask_key[i % 4] for i, b in enumerate(payload))

                keep_going = await self.handle_ws_frame(opcode, payload, writer)
                if not keep_going:
                    break

        except (asyncio.IncompleteReadError, ConnectionResetError, BrokenPipeError):
            pass
        except Exception as e:
            sys.stderr.write(f"[bridge] Client connection error: {e}\n")
        finally:
            if self.active_client and self.active_client[1] == writer:
                self.active_client = None
                self.authenticated = False
                self.emit_shell({"v": PROTOCOL_VERSION, "t": "connected", "value": False})
            try:
                writer.close()
                await writer.wait_closed()
            except Exception:
                pass

    async def handle_stdin(self):
        """Reads JSON commands from Quickshell over stdin."""
        loop = asyncio.get_running_loop()
        reader = asyncio.StreamReader()
        protocol = asyncio.StreamReaderProtocol(reader)
        await loop.connect_read_pipe(lambda: protocol, sys.stdin)

        while True:
            line = await reader.readline()
            if not line:
                # Pipe closed (Quickshell exited)
                break
            try:
                msg = json.loads(line.decode("utf-8").strip())
            except Exception:
                continue

            t = msg.get("t")
            if t == "cmd" and self.active_client and self.authenticated:
                writer = self.active_client[1]
                await self.send_ws_text(writer, json.dumps(msg))
            elif t == "ping":
                self.emit_shell({"v": PROTOCOL_VERSION, "t": "pong"})

    async def start(self):
        self.server = await asyncio.start_server(self.handle_client, HOST, PORT, reuse_address=True)
        # Notify shell initial status (waiting for client)
        self.emit_shell({"v": PROTOCOL_VERSION, "t": "ready", "port": PORT})
        self.emit_shell({"v": PROTOCOL_VERSION, "t": "connected", "value": False})

        stdin_task = asyncio.create_task(self.handle_stdin())
        async with self.server:
            done, pending = await asyncio.wait(
                [stdin_task, asyncio.create_task(self.server.serve_forever())],
                return_when=asyncio.FIRST_COMPLETED
            )
            for task in pending:
                task.cancel()

def main():
    token = get_or_create_token()
    bridge = SpotifyBridge(token)

    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)

    def sig_handler():
        for task in asyncio.all_tasks(loop):
            task.cancel()

    for s in (signal.SIGTERM, signal.SIGINT):
        try:
            loop.add_signal_handler(s, sig_handler)
        except NotImplementedError:
            pass

    try:
        loop.run_until_complete(bridge.start())
    except (asyncio.CancelledError, KeyboardInterrupt):
        pass
    finally:
        loop.close()

if __name__ == "__main__":
    main()
