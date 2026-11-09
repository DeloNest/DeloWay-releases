pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

// SpotifyBridgeService connects Quickshell to Spotify via the local Spicetify WebSocket bridge.
// When enabled, it launches scripts/deloway-spotify-bridge.py as a child process and communicates
// via line-delimited JSON over stdio.
Item {
    id: root

    readonly property bool connected: internalConnected
    readonly property bool liked: internalLiked
    readonly property var upNext: internalQueue
    readonly property bool bridgeEnabled: ConfigManager.spotifyBridgeEnabled

    property bool internalConnected: false
    property bool internalLiked: false
    property var internalQueue: []

    readonly property string helperScript: ConfigManager.projectDir + "/scripts/deloway-spotify-bridge.py"
    readonly property int bridgePort: (ConfigManager.userConfigDir.indexOf("deloway-nested") >= 0) ? 9956 : 9955

    function toggleLike() {
        if (!internalConnected || !bridgeProc.running) return;
        bridgeProc.write(JSON.stringify({ "v": 1, "t": "cmd", "a": "toggleLiked" }) + "\n");
    }

    function setLiked(val) {
        if (!internalConnected || !bridgeProc.running) return;
        bridgeProc.write(JSON.stringify({ "v": 1, "t": "cmd", "a": "setLiked", "value": Boolean(val) }) + "\n");
    }

    function handleLine(raw) {
        if (!raw) return;
        try {
            const msg = JSON.parse(raw);
            if (!msg || msg.v !== 1) return;
            if (msg.t === "connected") {
                root.internalConnected = Boolean(msg.value);
                if (!root.internalConnected) {
                    root.internalLiked = false;
                    root.internalQueue = [];
                }
            } else if (msg.t === "state") {
                root.internalLiked = Boolean(msg.liked);
                if (Array.isArray(msg.queue)) {
                    root.internalQueue = msg.queue.slice(0, 3);
                }
            }
        } catch (e) {
            // Malformed JSON ignored silently
        }
    }

    Process {
        id: bridgeProc
        stdinEnabled: true
        command: ["python3", root.helperScript, "--port", root.bridgePort.toString()]
        running: root.bridgeEnabled
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.handleLine(data)
        }
        onRunningChanged: {
            if (!running) {
                root.internalConnected = false;
                root.internalLiked = false;
                root.internalQueue = [];
            }
        }
        onExited: (code, status) => {
            if (root.bridgeEnabled) restartTimer.restart();
        }
    }

    Timer {
        id: restartTimer
        interval: 3000
        repeat: false
        onTriggered: {
            if (root.bridgeEnabled && !bridgeProc.running) {
                bridgeProc.running = true;
            }
        }
    }
}
