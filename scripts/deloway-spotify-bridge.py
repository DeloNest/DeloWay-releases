#!/usr/bin/env python3
"""
DeloWay Spotify Bridge Daemon
Connects Quickshell Smart Notch to Spotify via the Spicetify WebSocket extension.
Uses the official 'websockets' package (RFC 6455).
"""

import sys
import os
import argparse
import asyncio
import json
import secrets
import signal
import stat

try:
    import websockets
    from websockets.server import serve
except ImportError:
    sys.stderr.write(
        "[bridge] Error: 'websockets' package is not installed.\n"
        "[bridge] Please install it with: sudo pacman -S python-websockets\n"
    )
    sys.exit(1)

PROTOCOL_VERSION = 1
DEFAULT_PORT_PROD = 9955
DEFAULT_PORT_NESTED = 9956
ALLOWED_ORIGIN = "https://xpui.app.spotify.com"

def get_config_dir():
    return os.environ.get("DELOWAY_CONFIG_DIR") or os.path.expanduser("~/.config/deloway")

def read_token():
    config_dir = get_config_dir()
    token_path = os.path.join(config_dir, "spotify-token")

    if not os.path.isfile(token_path):
        sys.stderr.write(
            f"[bridge] Error: Persistent token file not found at {token_path}.\n"
            "[bridge] Please run scripts/deloway-spicetify-install.sh once to generate your token.\n"
        )
        sys.stderr.flush()
        try:
            sys.stdout.write(json.dumps({"v": PROTOCOL_VERSION, "t": "error", "message": "token_missing"}) + "\n")
            sys.stdout.flush()
        except Exception:
            pass
        sys.exit(1)

    # Validate file permissions (must be mode 0600 or stricter)
    try:
        st = os.stat(token_path)
        mode = stat.S_IMODE(st.st_mode)
        if mode & 0o077:
            sys.stderr.write(
                f"[bridge] Warning: Token file {token_path} has loose permissions ({oct(mode)}). "
                "Securing to 0600.\n"
            )
            os.chmod(token_path, 0o600)
    except Exception as e:
        sys.stderr.write(f"[bridge] Permission check error on {token_path}: {e}\n")

    with open(token_path, "r", encoding="utf-8") as f:
        token = f.read().strip()

    if not token:
        sys.stderr.write(f"[bridge] Error: Token file {token_path} is empty.\n")
        sys.exit(1)

    return token

def determine_default_port():
    if "DELOWAY_SPOTIFY_PORT" in os.environ:
        try:
            return int(os.environ["DELOWAY_SPOTIFY_PORT"])
        except ValueError:
            pass

    # Distinct port for nested sessions to prevent collision with real session
    home = os.environ.get("HOME", "")
    if os.environ.get("DELOWAY_NESTED_HOME") or "deloway-nested" in home:
        return DEFAULT_PORT_NESTED

    return DEFAULT_PORT_PROD

class SpotifyBridge:
    def __init__(self, token, port):
        self.token = token
        self.port = port
        self.active_client = None  # Current active WebSocket connection
        self.authenticated = False
        self.first_origin_logged = False
        self.liked = False
        self.queue = []
        self.server = None

    def emit_shell(self, payload):
        """Send JSON line to Quickshell via stdout."""
        try:
            line = json.dumps(payload, ensure_ascii=False)
            sys.stdout.write(line + "\n")
            sys.stdout.flush()
        except Exception as e:
            sys.stderr.write(f"[bridge] stdout write error: {e}\n")
            sys.stderr.flush()

    def get_origin(self, websocket):
        req = getattr(websocket, "request", None)
        if req is not None and hasattr(req, "headers"):
            return req.headers.get("Origin")
        if hasattr(websocket, "request_headers"):
            return websocket.request_headers.get("Origin")
        return None

    async def handle_client(self, websocket):
        origin = self.get_origin(websocket)

        # Log the first seen Origin (never log the token)
        if not self.first_origin_logged and origin:
            sys.stderr.write(f"[bridge] First seen Origin: {origin}\n")
            sys.stderr.flush()
            self.first_origin_logged = True

        # Origin verification: ONLY https://xpui.app.spotify.com
        if origin != ALLOWED_ORIGIN:
            sys.stderr.write(f"[bridge] Rejected connection from unauthorized Origin: {origin}\n")
            sys.stderr.flush()
            await websocket.close(1008, "Unauthorized Origin")
            return

        # Enforce single active connection
        if self.active_client is not None and not getattr(self.active_client, "closed", False):
            sys.stderr.write("[bridge] Rejected duplicate connection: another client is active\n")
            sys.stderr.flush()
            await websocket.close(1008, "Single connection only")
            return

        self.active_client = websocket
        self.authenticated = False

        # First frame MUST be a valid hello message with the correct token within 3.0s
        try:
            first_raw = await asyncio.wait_for(websocket.recv(), timeout=3.0)
            try:
                first_msg = json.loads(first_raw)
            except Exception:
                await websocket.close(1008, "Malformed JSON")
                return

            if not isinstance(first_msg, dict) or first_msg.get("t") != "hello" or first_msg.get("v") != PROTOCOL_VERSION:
                await websocket.close(1008, "Expected hello frame")
                return

            provided_token = str(first_msg.get("token", ""))
            if not secrets.compare_digest(provided_token, self.token):
                sys.stderr.write("[bridge] Authentication failed: invalid token\n")
                sys.stderr.flush()
                await websocket.close(1008, "Invalid token")
                return

            self.authenticated = True
            self.emit_shell({"v": PROTOCOL_VERSION, "t": "connected", "value": True})
            await websocket.send(json.dumps({"v": PROTOCOL_VERSION, "t": "hello_ack", "status": "ok"}))

        except (asyncio.TimeoutError, websockets.exceptions.ConnectionClosed):
            await websocket.close(1008, "Authentication timeout")
            return
        except Exception as e:
            sys.stderr.write(f"[bridge] Handshake error: {e}\n")
            sys.stderr.flush()
            return

        # Subsequent messages loop
        try:
            async for raw in websocket:
                try:
                    msg = json.loads(raw)
                except Exception:
                    # Malformed JSON frame
                    continue

                if not isinstance(msg, dict):
                    continue

                t = msg.get("t")
                if t == "state":
                    self.liked = bool(msg.get("liked", False))
                    raw_queue = msg.get("queue", [])
                    clean_queue = []
                    if isinstance(raw_queue, list):
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

        except websockets.exceptions.ConnectionClosed:
            pass
        except Exception as e:
            sys.stderr.write(f"[bridge] Connection error: {e}\n")
            sys.stderr.flush()
        finally:
            if self.active_client == websocket:
                was_authenticated = self.authenticated
                self.active_client = None
                self.authenticated = False
                if was_authenticated:
                    self.emit_shell({"v": PROTOCOL_VERSION, "t": "connected", "value": False})

    async def handle_stdin(self):
        """Reads JSON commands from Quickshell over stdin."""
        loop = asyncio.get_running_loop()
        reader = asyncio.StreamReader()
        protocol = asyncio.StreamReaderProtocol(reader)
        await loop.connect_read_pipe(lambda: protocol, sys.stdin)

        while True:
            line = await reader.readline()
            if not line:
                # Quickshell parent pipe closed -> exit cleanly
                break

            try:
                msg = json.loads(line.decode("utf-8").strip())
            except Exception:
                continue

            t = msg.get("t")
            if t == "cmd" and self.active_client and self.authenticated:
                try:
                    await self.active_client.send(json.dumps(msg))
                except Exception:
                    pass
            elif t == "ping":
                self.emit_shell({"v": PROTOCOL_VERSION, "t": "pong"})

    async def start(self):
        # max_size=65536 enforces strict 64KB frame limit per RFC 6455
        self.server = await serve(
            self.handle_client,
            "127.0.0.1",
            self.port,
            max_size=65536
        )

        self.emit_shell({"v": PROTOCOL_VERSION, "t": "ready", "port": self.port})
        self.emit_shell({"v": PROTOCOL_VERSION, "t": "connected", "value": False})

        stdin_task = asyncio.create_task(self.handle_stdin())
        done, pending = await asyncio.wait(
            [stdin_task, asyncio.create_task(self.server.serve_forever())],
            return_when=asyncio.FIRST_COMPLETED
        )
        for task in pending:
            task.cancel()

def main():
    parser = argparse.ArgumentParser(description="DeloWay Spotify Bridge Daemon")
    parser.add_argument("--port", type=int, default=determine_default_port(), help="TCP port to bind")
    args = parser.parse_args()

    token = read_token()
    bridge = SpotifyBridge(token, args.port)

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
