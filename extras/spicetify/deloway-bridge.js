// NAME: DeloWay Spotify Bridge
// AUTHOR: DeloWay Team
// DESCRIPTION: Pushes liked status and upcoming queue tracks to DeloWay Smart Notch

(function DeloWayBridge() {
    var TOKEN = "__DELOWAY_TOKEN__";
    var WS_PORT = 9955;
    var ws = null;
    var reconnectTimer = null;
    var lastQueueRev = null;

    function isReady() {
        return Boolean(
            window.Spicetify &&
            window.Spicetify.Player &&
            window.Spicetify.Player.data &&
            window.Spicetify.Queue
        );
    }

    function extractQueue() {
        if (!window.Spicetify || !window.Spicetify.Queue) return [];
        var raw = window.Spicetify.Queue.nextTracks || [];
        var list = [];
        for (var i = 0; i < Math.min(raw.length, 5); i++) {
            var item = raw[i];
            if (!item) continue;
            var title = item.name || (item.metadata && item.metadata.title) || "";
            var artist = "";
            if (item.artists && item.artists.length > 0) {
                artist = item.artists.map(function(a) { return a.name; }).join(", ");
            } else if (item.metadata && item.metadata.artist_name) {
                artist = item.metadata.artist_name;
            }
            list.push({
                title: String(title || "").trim(),
                artist: String(artist || "").trim(),
                uri: String(item.uri || "")
            });
        }
        return list;
    }

    function pushState() {
        if (!ws || ws.readyState !== WebSocket.OPEN) return;
        if (!isReady()) return;

        var liked = false;
        try {
            if (typeof Spicetify.Player.getHeart === "function") {
                liked = Boolean(Spicetify.Player.getHeart());
            }
        } catch (e) {}

        var queue = extractQueue();
        if (Spicetify.Queue && Spicetify.Queue.queueRevision !== undefined) {
            lastQueueRev = Spicetify.Queue.queueRevision;
        }

        var payload = {
            v: 1,
            t: "state",
            liked: liked,
            queue: queue
        };

        try {
            ws.send(JSON.stringify(payload));
        } catch (e) {}
    }

    function handleCommand(msg) {
        if (!msg || msg.v !== 1 || msg.t !== "cmd") return;
        var action = msg.a;

        if (action === "toggleLiked") {
            try {
                if (typeof Spicetify.Player.toggleHeart === "function") {
                    Spicetify.Player.toggleHeart();
                } else if (typeof Spicetify.Player.setHeart === "function") {
                    var cur = Spicetify.Player.getHeart ? Spicetify.Player.getHeart() : false;
                    Spicetify.Player.setHeart(!cur);
                }
            } catch (e) {}
            setTimeout(pushState, 120);
        } else if (action === "setLiked") {
            try {
                if (typeof Spicetify.Player.setHeart === "function") {
                    Spicetify.Player.setHeart(Boolean(msg.value));
                }
            } catch (e) {}
            setTimeout(pushState, 120);
        }
    }

    function connect() {
        if (reconnectTimer) {
            clearTimeout(reconnectTimer);
            reconnectTimer = null;
        }

        try {
            var url = "ws://127.0.0.1:" + WS_PORT + "/?token=" + encodeURIComponent(TOKEN);
            ws = new WebSocket(url);

            ws.onopen = function() {
                // Send hello handshake
                try {
                    ws.send(JSON.stringify({ v: 1, t: "hello", token: TOKEN }));
                } catch (e) {}
                pushState();
            };

            ws.onmessage = function(event) {
                try {
                    var data = JSON.parse(event.data);
                    handleCommand(data);
                } catch (e) {}
            };

            ws.onerror = function() {
                try { ws.close(); } catch (e) {}
            };

            ws.onclose = function() {
                ws = null;
                scheduleReconnect();
            };
        } catch (e) {
            scheduleReconnect();
        }
    }

    function scheduleReconnect() {
        if (!reconnectTimer) {
            reconnectTimer = setTimeout(connect, 3000);
        }
    }

    function init() {
        if (!isReady()) {
            setTimeout(init, 500);
            return;
        }

        // Attach listeners
        try {
            Spicetify.Player.addEventListener("songchange", pushState);
            Spicetify.Player.addEventListener("onplaypause", pushState);
        } catch (e) {}

        // Periodic queue check (only every 3s)
        setInterval(function() {
            if (!isReady()) return;
            if (Spicetify.Queue && Spicetify.Queue.queueRevision !== undefined) {
                if (Spicetify.Queue.queueRevision !== lastQueueRev) {
                    pushState();
                }
            }
        }, 3000);

        connect();
    }

    init();
})();
