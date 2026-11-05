# Spicetify Integration Research for DeloWay Smart Notch

## 1. Environment (Read-Only Audit)

| Property | Value | Evidence / Command Source |
| :--- | :--- | :--- |
| **Spicetify Installed** | **Yes** (`v2.46.4`) | `/home/waleed/.local/bin/spicetify` (symlinked to `/home/waleed/.spicetify/spicetify`), `spicetify -v` |
| **Installation Method** | Official standalone script | Script target in `~/.spicetify/` (no native pacman package owner) |
| **Spotify Installed** | **Yes** (Flatpak) | `flatpak list`: `com.spotify.Client`, branch `stable`, user installation |
| **Spotify Version** | `1.2.95.453.g0eeebbed` | `flatpak list`, `~/.config/spicetify/config-xpui.ini` |
| **Spicetify Config Path** | `~/.config/spicetify/config-xpui.ini` | `spicetify path`, `cat ~/.config/spicetify/config-xpui.ini` |
| **Extensions Paths** | `~/.config/spicetify/Extensions`<br>`~/.spicetify/Extensions` | User extensions in `~/.config/spicetify/Extensions`; bundled in `~/.spicetify/Extensions` |
| **Active Theme / Apps** | Theme: `marketplace`<br>Custom Apps: `marketplace`<br>Extensions: *(none)* | `config-xpui.ini`: `current_theme = marketplace`, `custom_apps = marketplace`, `extensions = ` |
| **Version Compatibility** | **COMPATIBLE** | Spicetify v2.46.4 supports Spotify Linux versions up to `1.3.4` (Spotify `1.2.95` falls in supported range `1.2.14`–`1.3.4`). `config-xpui.ini` confirms active backup: `version = 1.2.95.453.g0eeebbed with = 2.46.4`. |

---

## 2. API Surface

| Category | API Function / Object | Exact Purpose | Status |
| :--- | :--- | :--- | :--- |
| **Track & Context** | `Spicetify.Player.data.item` | Current track URI, title, duration, artists, album, images, custom metadata | **verified-in-installed-files** (`globals.d.ts` L200, L230) |
| **Track & Context** | `Spicetify.Player.data.context` | Current playback context (URI e.g. `spotify:playlist:...`, URL, metadata) | **verified-in-installed-files** (`globals.d.ts` L198, L218) |
| **Upcoming / Queue** | `Spicetify.Queue.nextTracks` | Array of upcoming queued tracks with metadata and UID | **verified-in-installed-files** (`globals.d.ts` L848, `spicetifyWrapper.js`) |
| **Upcoming / Queue** | `Spicetify.Queue.prevTracks` | Array of previously played tracks | **verified-in-installed-files** (`globals.d.ts` L849) |
| **Upcoming / Queue** | `Spicetify.Player.data.nextItems` | Upcoming tracks in active context queue | **verified-in-installed-files** (`globals.d.ts` L212) |
| **Playlists** | `Spicetify.Platform.RootlistAPI.getContents()` | Fetches user's complete sidebar hierarchy (playlists, folders, order) | **doc-only** (`spicetify.app/docs`, `Platform` verified) |
| **Playlists** | `Spicetify.Platform.PlaylistAPI.getContents(uri)` | Fetches tracklist and metadata for a specific playlist URI | **doc-only** (`spicetify.app/docs`, `Platform` verified) |
| **Playlists (Fallback)** | `Spicetify.CosmosAsync.get(url)` | Directly queries Spotify internal Cosmos endpoints (e.g. `spclient://playlist/...`) | **verified-in-installed-files** (`globals.d.ts` L549-570) |
| **Playback** | `Spicetify.Player.playUri(uri, context?, options?)` | Immediately plays any track, album, playlist, or context URI | **verified-in-installed-files** (`globals.d.ts` L466, `spicetifyWrapper.js`) |
| **Playback** | `Spicetify.Player.play()`, `pause()`, `togglePlay()` | Basic playback transport | **verified-in-installed-files** (`globals.d.ts` L455-465) |
| **Playback** | `Spicetify.Player.next()`, `back()` | Track skipping | **verified-in-installed-files** (`globals.d.ts` L383, L451) |
| **Queue Control** | `Spicetify.addToQueue(uri: ContextTrack[])` | Appends track(s) to user playback queue | **verified-in-installed-files** (`globals.d.ts` L538, `spicetifyWrapper.js`) |
| **Queue Control** | `Spicetify.removeFromQueue(uri: ContextTrack[])` | Removes track(s) from user playback queue | **verified-in-installed-files** (`globals.d.ts` L856, `spicetifyWrapper.js`) |
| **Like / Save** | `Spicetify.Player.getHeart()` | Checks if active track is in Liked Songs (`collection.in_collection`) | **verified-in-installed-files** (`globals.d.ts` L438, `spicetifyWrapper.js`) |
| **Like / Save** | `Spicetify.Player.toggleHeart()`, `setHeart(bool)` | Likes or unlikes the current playing track | **verified-in-installed-files** (`globals.d.ts` L510, `spicetifyWrapper.js`) |
| **Like / Save** | `Spicetify.Platform.LibraryAPI.add({uris})` / `.remove({uris})` | Adds or removes arbitrary URIs from library | **verified-in-installed-files** (`spicetifyWrapper.js`, `webnowplaying.js`) |
| **Like / Save** | `Spicetify.Platform.LibraryAPI.contains(uri)` | Checks whether any arbitrary URI is saved in library | **verified-in-installed-files** (`webnowplaying.js` L68) |
| **Shuffle / Repeat** | `Spicetify.Player.getShuffle()`, `setShuffle(bool)`, `toggleShuffle()` | Reads and mutates shuffle state | **verified-in-installed-files** (`globals.d.ts` L434, L492, L530) |
| **Shuffle / Repeat** | `Spicetify.Player.getRepeat()`, `setRepeat(mode)`, `toggleRepeat()` | Reads and mutates repeat (0 = off, 1 = context, 2 = track) | **verified-in-installed-files** (`globals.d.ts` L430, L488, L526) |
| **Seek / Volume** | `Spicetify.Player.seek(pos)` | Seeks position in ms or 0.0..1.0 fraction | **verified-in-installed-files** (`globals.d.ts` L478) |
| **Seek / Volume** | `Spicetify.Player.setVolume(level)`, `getVolume()` | Sets/reads volume from 0.0 to 1.0 via `Platform.PlaybackAPI` | **verified-in-installed-files** (`globals.d.ts` L442, L496) |
| **Events** | `Spicetify.Player.addEventListener("songchange", cb)` | Push notification when track or context changes | **verified-in-installed-files** (`globals.d.ts` L364) |
| **Events** | `Spicetify.Player.addEventListener("onplaypause", cb)` | Push notification on play/pause transitions | **verified-in-installed-files** (`globals.d.ts` L365) |
| **Events** | `Spicetify.Player.addEventListener("onprogress", cb)` | Push progress updates (emitted every ~100ms during playback) | **verified-in-installed-files** (`globals.d.ts` L366, `spicetifyWrapper.js`) |
| **Queue Events** | `Spicetify.Queue.queueRevision` check on `songchange` | Detects queue modifications | **verified-in-installed-files** (`globals.d.ts` L850, official docs) |

---

## 3. Bridge Evaluation

Spotify's UI runs inside a Chromium Embedded Framework (CEF) renderer sandbox. It **cannot** create TCP servers or access UNIX domain sockets directly. The extension must act as a **client**.

| Criterion | Option A: WebSocket Client $\rightarrow$ Local Daemon $\rightarrow$ D-Bus / Quickshell | Option B: Direct WebSocket to Quickshell Server | Option C: Local HTTP REST / Long-Polling | Option D: Local File / FIFO IPC |
| :--- | :--- | :--- | :--- | :--- |
| **How it Works** | Extension connects to `ws://127.0.0.1:PORT` hosted by a tiny daemon (`deloway-spotify-bridge`). Daemon registers `org.mpris.MediaPlayer2.Spicetify` or DeloWay D-Bus object. | Extension connects directly to a WebSocket server inside Quickshell. | Extension uses `fetch("http://127.0.0.1:PORT/...")` to post state and long-poll commands. | Extension writes state to `/tmp/spotify.fifo`. |
| **Feasibility** | **Verified feasible** (used by `webnowplaying.js`, Macro Deck, Tide-island). | **Infeasible out-of-the-box**: QtWebSockets is uninstalled; Quickshell `SocketServer` only supports UNIX sockets. | **Feasible**, but inefficient for bidirectional push. | **IMPOSSIBLE**: CEF browser sandbox prohibits arbitrary filesystem / FIFO writes. |
| **Extra Processes** | 1 lightweight background daemon (Python/Go/Rust, ~12MB RAM). | 0 extra processes. | 1 lightweight daemon. | N/A |
| **Latency** | < 2 ms (local loopback WebSocket). | < 2 ms. | 20–50 ms (HTTP overhead / poll latency). | N/A |
| **Startup Order** | Decoupled: Extension retries connection every 1–2s until daemon is up. | Decoupled: Extension retries connection. | Decoupled: HTTP retries. | N/A |
| **Reconnection** | Clean: Standard `ws.onclose` with exponential backoff. | Clean: `ws.onclose` retry loop. | Must handle timeout on every long-poll. | N/A |
| **Idle CPU / Wakeups** | **0% idle CPU**: Strictly event-driven push via WebSocket $\rightarrow$ D-Bus. Zero polling. | 0% idle CPU. | Periodic wakeups on long-poll timeouts. | N/A |
| **Complexity** | **Medium (M)**: Small daemon script + small JS extension. | **Large (L)**: Requires C++ Quickshell plugin or missing Qt6 packages. | **Medium (M)**: HTTP server + long-poll management. | N/A |
| **Failure Modes** | If daemon dies, Spotify logs connection error and retries silently; shell falls back to MPRIS. | Quickshell crash breaks socket immediately. | Dropped HTTP packets, hanging poll connections. | N/A |

---

## 4. Existing Work

| Project | URL | License | Last Updated | Stars | What It Exposes | Maintained? |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **WebNowPlaying-Redux** | [keifufu/WebNowPlaying](https://github.com/keifufu/WebNowPlaying) | MIT | 2026 | ~122 | Track info, progress, volume, liked state, playback controls over `ws://localhost:8974`. Bundled locally in Spicetify. | **Yes** |
| **ha-spicetify-bridge** | [tobfd/ha-spicetify-bridge](https://github.com/tobfd/ha-spicetify-bridge) | Open Source (MIT) | 2026 | ~3 | WebSocket bridge exposing playback state and controls for Home Assistant. | **Yes** |
| **MDBridgeSpicetify** | [NiyahVE/MDBridgeSpicetify](https://github.com/NiyahVE/MDBridgeSpicetify) | Apache-2.0 | Early 2026 | 1 | WebSocket companion extension for Macro Deck two-way controls and state. | Semi-active |
| **spicetify-queue-manager** | [D3SOX/spicetify-queue-manager](https://github.com/D3SOX/spicetify-queue-manager) | GPL-3.0 | Late 2023 | 1 | UI extension in Spotify for queue snapshots and playlist export (internal UI only, no external IPC). | Inactive |
| **spotify_info** | [Ricky12Awesome/spotify_info](https://github.com/Ricky12Awesome/spotify_info) | MIT | 2022 | ~2 | Rust library + Spicetify WebSocket extension for track changes and state. | Inactive |

---

## 5. Fragility, Distribution & Legal Risks

### A. Fragility Across Spotify Updates
1. **Flatpak Update Impact**:
   - Flatpak updates to `com.spotify.Client` replace the `/share/spotify/` assets, wiping Spicetify’s patched `xpui.js` and `xpui.css`.
   - Spotify immediately reverts to vanilla mode on next launch.
2. **User Action Required**:
   - The user must run `spicetify apply` in terminal to re-patch Spotify.
   - It **cannot** self-heal automatically without an external trigger script or hook.
3. **Graceful Degradation Architecture**:
   - The DeloWay Smart Notch must treat the Spicetify bridge as an **enhancement layer**, never a hard dependency.
   - **Degradation per feature**:
     - *Now Playing (Title, Artist, Album, Art, Scrubber, Volume, Play/Pause/Skip)*: Pure MPRIS (100% operational regardless of Spicetify).
     - *Liked / Heart State*: If bridge is disconnected, hide the heart toggle or show read-only status.
     - *Queue ("Up Next") & Playlists*: If bridge is disconnected, hide the Queue section and display the default fallback card.

### B. Legal & Terms of Service (Spotify TOS)
- **Spotify Terms of Service (Section 9 - User Guidelines)** explicitly prohibits:
  > *"circumventing any technology used by Spotify, its licensors, or any third party to protect Content or the Service"* and *"reverse engineering, decompiling, disassembling, modifying, or creating derivative works of the Spotify Service or any part thereof..."*
  *(Source: [Spotify Terms of Use § 9](https://www.spotify.com/legal/end-user-agreement/))*
- **Distribution Implication**:
  - Shipping a patched Spotify or bundling automated Spicetify installation into DeloWay's core distribution violates Spotify's Terms of Service and risks legal action / account bans.
  - Therefore, DeloWay **must NOT** distribute Spicetify or require it. It can only offer an **optional user-installed companion extension** for users who already independently run Spicetify.

---

## 6. Security & Localhost Attack Surface

Any website visited in the user's web browser can make HTTP requests or open WebSockets to `ws://127.0.0.1` or `http://127.0.0.1`.

| Mitigation | Description | Feasibility in Option A (WebSocket Bridge) |
| :--- | :--- | :--- |
| **Loopback Bind Only** | Bind exclusively to `127.0.0.1` (IPv4) / `::1` (IPv6), never `0.0.0.0` or external interfaces. | **Yes** (Standard socket bind option). |
| **Origin Header Verification** | Reject any WebSocket connection whose `Origin` header is not `https://xpui.app.spotify.com`. Browser tabs cannot spoof their own `Origin` header. | **Yes** (Checked in HTTP upgrade handshake). |
| **Session Bearer Token** | Generate a cryptographically random secret token at shell startup, stored with permissions `0600` under `$XDG_RUNTIME_DIR/deloway/spotify-bridge.token`. Client must supply token in query string or header. | **Yes** (Client reads token from config or runtime path). |
| **Strict Command Whitelist** | Never execute shell strings (`sh -c`). Only accept typed JSON payloads: `{ "action": "PLAY" \| "PAUSE" \| "SEEK" \| "LIKE" \| "QUEUE_ADD", ... }`. | **Yes** (Enum dispatch with schema validation). |
| **Payload Size Limits** | Cap incoming WebSocket frame payloads to $\le 64\text{KB}$ to prevent memory exhaustion attacks. | **Yes** (Standard WebSocket parser limit). |

---

## 7. Recommendation & Prototype Plan

### A. Ranked Features (Value vs. Effort vs. Fragility)
1. **Liked Songs ("Heart") Toggle & State** (Rank 1 — High Value / Low Effort / Low Fragility):
   Fills the single most glaring gap in MPRIS with minimal code (`Spicetify.Player.toggleHeart()`).
2. **Upcoming Track / Queue Preview** (Rank 2 — High Value / Medium Effort / Low Fragility):
   Exposes `Spicetify.Queue.nextTracks` (next 5 tracks) directly inside the Notch secondary card.
3. **Play from Context / Playlists** (Rank 3 — Medium Value / Medium Effort / Medium Fragility):
   Exposes user playlists via `RootlistAPI` to allow 1-click playback switching.
4. **Enhanced Shuffle/Repeat Sync** (Rank 4 — Low Value):
   MPRIS already handles shuffle and loop adequately in standard Linux.

### B. Single Best Bridge Architecture
**Option A: Spicetify WebSocket Client $\rightarrow$ Lightweight Python Daemon $\rightarrow$ Session D-Bus**
- **Why**:
  1. Keeps Quickshell 100% native: Quickshell natively consumes D-Bus with zero extra plugins or C++ recompilation.
  2. 0% idle CPU: Event-driven WebSocket push translates directly into D-Bus signals; no polling anywhere.
  3. Decoupled safety: If Spotify or Flatpak updates break Spicetify, the daemon simply signals D-Bus offline, and Quickshell stays in MPRIS mode.

### C. Smallest First Prototype Plan
```text
1. Extension:
   - Create ~/.config/spicetify/Extensions/deloway-bridge.js
   - Connects to ws://127.0.0.1:9955 with origin verification.
   - Pushes Spicetify.Player.data and Spicetify.Queue.nextTracks on "songchange" / "onplaypause".
2. Bridge Daemon:
   - scripts/deloway-spotify-bridge.py (Python asyncio + websockets + dbus-next, ~100 lines).
   - Exports org.deloway.SpotifyBridge on D-Bus with Properties (IsLiked, NextTracks) and Methods (ToggleLike, PlayUri).
3. Quickshell Integration:
   - DBusItem in shell/services listening to org.deloway.SpotifyBridge.
   - When present: NotchHome displays Liked Heart + Next 3 Queue tracks.
   - When absent: NotchHome seamlessly renders standard MPRIS controls.
4. Testing in Nested Sandbox:
   - Run in wayland-3 with nested session; test connect, disconnect, and pure MPRIS fallback.
```

---

## 8. UNVERIFIED List

1. **`Spicetify.Platform.RootlistAPI.getContents()` Internal Schema Consistency**:
   While verified in Spicetify documentation, the exact JSON structure of items returned by `RootlistAPI` shifts across Spotify desktop revisions and is marked **doc-only / unverified-at-runtime** until inspected live in the Chromium console.
2. **Native Event for Live Queue Drag-and-Drop Reordering**:
   There is no verified native event listener on `Spicetify.Player` specifically for when a user reorders tracks in Spotify's queue UI without changing songs. Queue updates outside of `songchange` currently require comparing `Spicetify.Queue.queueRevision`.
