import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQml.Models
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Hyprland
import Quickshell.Io
import "../theme"
import "../services"
import "./notifications"

Item {
    id: root

    property bool expanded: false
    property ShellScreen targetScreen: null
    readonly property HyprlandMonitor hyprMonitor: targetScreen ? Hyprland.monitorFor(targetScreen) : (Hyprland.focusedMonitor || null)

    // Follows the reading direction. LTR islands are pinned where they are needed:
    // the workspace strip (WorkspaceIndicator) and the media transport rows.
    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    readonly property real workspaceContentWidth: (wsIndicator && wsIndicator.visible) ? wsIndicator.implicitWidth : 0
    readonly property real playerContentWidth: (miniMusicPlayer && hasPlayer) ? miniMusicPlayer.implicitWidth : 0

    // Time & Date state
    property date currentTime: new Date()
    // Only the expanded Home tab shows the seconds clock / day strip; ticking while hidden
    // dirtied the whole TopBar surface every second.
    Timer {
        interval: 1000
        running: root.expanded && ShellState.smartNotchExpanded && ShellState.smartNotchTab === 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.currentTime = new Date()
    }

    // MPRIS Active Player tracking
    property var activePlayer: null
    readonly property bool hasPlayer: activePlayer !== null && (activePlayer.isPlaying || (activePlayer.trackTitle && activePlayer.trackTitle.trim().length > 0))
    readonly property bool isMusicPlaying: hasPlayer && activePlayer.isPlaying
    readonly property bool canPrev: hasPlayer && activePlayer.canGoPrevious
    readonly property bool canNext: hasPlayer && activePlayer.canGoNext
    readonly property bool canToggle: hasPlayer && activePlayer.canTogglePlaying
    readonly property bool canSeek: hasPlayer && activePlayer.canSeek
    readonly property bool positionSupported: hasPlayer && activePlayer.positionSupported
    readonly property bool lengthSupported: hasPlayer && activePlayer.lengthSupported
    readonly property bool volumeSupported: hasPlayer && activePlayer.volumeSupported
    readonly property bool shuffleSupported: hasPlayer && activePlayer.shuffleSupported
    readonly property bool loopSupported: hasPlayer && activePlayer.loopSupported
    readonly property bool isBridgeQueueActive: SpotifyBridgeService.connected && SpotifyBridgeService.upNext && SpotifyBridgeService.upNext.length > 0

    // Live Playback Timeline & Position Tracking
    property real playbackPosition: 0.0
    property bool scrubberSeeking: false
    readonly property real trackLength: (hasPlayer && activePlayer.lengthSupported && activePlayer.length > 0) ? activePlayer.length : 0.0
    readonly property real playbackProgress: trackLength > 0 ? Math.min(1.0, Math.max(0.0, playbackPosition / trackLength)) : 0.0

    // Metadata Context Properties
    readonly property int trackNumber: (activePlayer && activePlayer.metadata && activePlayer.metadata["xesam:trackNumber"]) ? activePlayer.metadata["xesam:trackNumber"] : 0
    property real lastNonZeroVolume: 1.0

    onActivePlayerChanged: {
        root.syncPositionFromPlayer();
    }

    function syncPositionFromPlayer() {
        if (root.activePlayer && root.activePlayer.positionSupported) {
            root.playbackPosition = root.activePlayer.position;
        } else {
            root.playbackPosition = 0.0;
        }
    }

    function formatTime(sec) {
        if (isNaN(sec) || sec < 0) return "0:00";
        const total = Math.floor(sec);
        const m = Math.floor(total / 60);
        const s = total % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    function seekToRatio(ratio) {
        if (!activePlayer || trackLength <= 0) return;
        const targetSec = Math.max(0.0, Math.min(trackLength, ratio * trackLength));
        playbackPosition = targetSec;
        activePlayer.position = targetSec;
    }

    function cycleLoop() {
        if (!activePlayer || !activePlayer.loopSupported) return;
        if (activePlayer.loopState === MprisLoopState.None) {
            activePlayer.loopState = MprisLoopState.Playlist;
        } else if (activePlayer.loopState === MprisLoopState.Playlist) {
            activePlayer.loopState = MprisLoopState.Track;
        } else {
            activePlayer.loopState = MprisLoopState.None;
        }
    }

    function toggleMute() {
        if (!activePlayer || !activePlayer.volumeSupported) return;
        if (activePlayer.volume > 0.01) {
            lastNonZeroVolume = activePlayer.volume;
            activePlayer.volume = 0.0;
        } else {
            activePlayer.volume = (lastNonZeroVolume > 0.05 ? lastNonZeroVolume : 0.8);
        }
    }

    Process {
        id: spotifyUriProc
    }

    function switchMusicContext(uri) {
        if (activePlayer && activePlayer.canRaise) {
            activePlayer.raise();
        }
        spotifyUriProc.exec(["busctl", "--user", "call", "org.mpris.MediaPlayer2.spotify", "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", "OpenUri", "s", uri]);
        spotifyUriProc.exec(["xdg-open", uri]);
    }

    function raisePlayer() {
        if (activePlayer && activePlayer.canRaise) {
            activePlayer.raise();
        } else {
            ConfigManager.launchMusic();
        }
    }

    // Playback progression timer (500ms) - only ticks when expanded and music playing
    Timer {
        id: playbackTimer
        interval: 500
        running: root.expanded && ShellState.smartNotchExpanded && ShellState.smartNotchTab === 0 && root.isMusicPlaying && !root.scrubberSeeking
        repeat: true
        onTriggered: {
            if (root.activePlayer && root.activePlayer.positionSupported) {
                const reported = root.activePlayer.position;
                if (Math.abs(reported - root.playbackPosition) > 2.0) {
                    root.playbackPosition = reported;
                } else {
                    root.playbackPosition = Math.min(root.trackLength > 0 ? root.trackLength : 999999, root.playbackPosition + 0.5);
                }
            }
        }
    }

    function isSpotify(p) {
        if (!p) return false;
        const ident = (p.identity || "").toLowerCase();
        const dEntry = (p.desktopEntry || "").toLowerCase();
        const busName = (p.busName || p.dbusName || "").toLowerCase();
        return ident === "spotify" || dEntry === "spotify" || ident.includes("spotify") || dEntry.includes("spotify") || busName.includes("spotify");
    }

    function playerHasMedia(p) {
        if (!p || !isSpotify(p)) return false;
        if (p.isPlaying) return true;
        if (p.trackTitle && p.trackTitle.trim().length > 0) return true;
        return false;
    }

    function updateActivePlayer() {
        if (!Mpris.players || !Mpris.players.values) {
            activePlayer = null;
            return;
        }
        const values = Mpris.players.values;
        if (!values || values.length === 0) {
            activePlayer = null;
            return;
        }

        // 1. Search exclusively for Spotify if actively playing
        for (let i = 0; i < values.length; i++) {
            const p = values[i];
            if (p && isSpotify(p) && p.isPlaying) {
                if (activePlayer !== p) activePlayer = p;
                return;
            }
        }

        // 2. Check if Spotify has media loaded (even if paused)
        for (let i = 0; i < values.length; i++) {
            const p = values[i];
            if (p && isSpotify(p) && playerHasMedia(p)) {
                if (activePlayer !== p) activePlayer = p;
                return;
            }
        }

        // 3. Keep current Spotify player if still in values
        if (activePlayer && isSpotify(activePlayer)) {
            for (let i = 0; i < values.length; i++) {
                if (values[i] === activePlayer) return;
            }
        }

        // 4. Default: No Spotify player active
        activePlayer = null;
    }

    Connections {
        target: ConfigManager
        function onMusicPreferredPlayerChanged() {
            root.updateActivePlayer();
        }
    }

    Instantiator {
        model: Mpris.players
        delegate: Connections {
            target: modelData
            function onIsPlayingChanged() {
                root.updateActivePlayer();
            }
            function onPlaybackStateChanged() {
                root.updateActivePlayer();
            }
            function onTrackTitleChanged() {
                root.updateActivePlayer();
                root.syncPositionFromPlayer();
            }
            function onPositionChanged() {
                if (modelData === root.activePlayer && !root.scrubberSeeking) {
                    root.playbackPosition = modelData.position;
                }
            }
        }
        onObjectAdded: root.updateActivePlayer()
        onObjectRemoved: root.updateActivePlayer()
    }

    Connections {
        target: Mpris.players
        function onValuesChanged() {
            root.updateActivePlayer();
        }
    }

    Component.onCompleted: {
        root.updateActivePlayer();
    }

    // Notification State
    property var activeNotification: null
    property bool notificationActive: false
    property real notifRemainingRatio: 1.0

    // Hovering the banner / detail card pauses the countdown (resumes where it left off).
    readonly property bool notifPaused: bannerCard.hovered || detailCard.hovered

    Connections {
        target: NotificationManager
        function onToastRequested(notif) {
            // DND silences banners; with "Smart Notch Notifications" off the fallback
            // NotificationToast shows them instead (previously both appeared).
            if (ConfigManager.notificationsDnd || !ConfigManager.notchNotifications) return;
            root.activeNotification = notif;
            // Every new notification gets its full display time (was: inherited the
            // remaining time of the previous one because `elapsed` never reset).
            notifTimer.elapsed = 0;
            root.notifRemainingRatio = 1.0;
            root.notificationActive = true;
            notifTimer.restart();
        }
    }

    function dismissActiveNotification() {
        root.notificationActive = false;
    }

    Timer {
        id: notifTimer
        interval: 50
        repeat: true
        running: root.notificationActive && !root.notifPaused
        property int elapsed: 0
        readonly property int duration: ConfigManager.notificationsTimeout || 5000

        onTriggered: {
            elapsed += interval;
            root.notifRemainingRatio = Math.max(0.0, 1.0 - (elapsed / duration));
            if (elapsed >= duration) {
                root.notificationActive = false;
                stop();
            }
        }
    }

    // Active View Mode: notification overrides music, music overrides idle
    readonly property string viewMode: notificationActive ? "notification" : (hasPlayer ? "music" : "idle")

    // =========================================================================
    // VIEW 1: COMPACT MODE (!expanded)
    // =========================================================================
    Item {
        anchors.fill: parent
        visible: !root.expanded

        // 1.1 Compact Notification — shared single-line banner, cross-faded
        NotificationCard {
            id: bannerCard
            anchors.fill: parent
            variant: "banner"
            notif: root.activeNotification
            opacity: root.viewMode === "notification" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
            onCloseRequested: root.dismissActiveNotification()
        }

        // 1.2 Merged Compact Row: Workspaces + Music Player
        // Physical order kept (workspaces | player) like the rest of the top bar; the
        // player's own text still renders Arabic correctly.
        RowLayout {
            anchors.centerIn: parent
            spacing: 8
            LayoutMirroring.enabled: false
            LayoutMirroring.childrenInherit: true
            opacity: root.viewMode !== "notification" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
            z: 1

            // ── SECTION A: Workspaces (Dynamic WorkspaceIndicator) ────────────
            WorkspaceIndicator {
                id: wsIndicator
                visible:        ConfigManager.topBarShowWorkspaces
                hyprMonitor:    root.hyprMonitor
                staticCount:    ConfigManager.workspacesCount
                indicatorStyle: ConfigManager.workspaceIndicatorStyle || "icons"
                reduceMotion:   false
                Layout.alignment: Qt.AlignVCenter
            }

            // ── SECTION B: Subtle Divider (Visible when music player is present) ─
            Rectangle {
                visible: root.hasPlayer && wsIndicator.visible
                Layout.preferredWidth: 1
                Layout.preferredHeight: 20
                Layout.alignment: Qt.AlignVCenter
                color: Theme.notchBorder
            }


            // ── SECTION C: Mini Music Player ──────────────────────────────
            RowLayout {
                id: miniMusicPlayer
                visible: root.hasPlayer
                spacing: 6
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter

                // Mini Album Art
                Rectangle {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: 8
                    clip: true
                    color: Theme.notchSurfaceElevated

                    Image {
                        anchors.fill: parent
                        source: root.activePlayer && root.activePlayer.trackArtUrl ? root.activePlayer.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(64, 64)
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    SymbolicIcon {
                        anchors.centerIn: parent
                        iconSize: 18
                        source: "applications-multimedia"
                        iconColor: Theme.notchTextSecondary
                        visible: !root.activePlayer || !root.activePlayer.trackArtUrl
                    }
                }

                // Track Title
                Text {
                    horizontalAlignment: Text.AlignLeft   // reading start (mirrored in Arabic)
                    text: root.activePlayer && root.activePlayer.trackTitle ? root.activePlayer.trackTitle : I18n.tr("notch_now_playing")
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(14)
                    font.weight: Font.DemiBold
                    renderType: Theme.renderType
                    color: Theme.notchText
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.maximumWidth: 190
                }

                // Mini Controls: Previous, Play/Pause, Next
                RowLayout {
                    spacing: 4
                    LayoutMirroring.enabled: false
                    LayoutMirroring.childrenInherit: false

                    // Previous
                    Rectangle {
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 12
                        color: prevHover.containsMouse ? Theme.notchSurfaceHover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                        SymbolicIcon {
                            anchors.centerIn: parent
                            iconSize: 13
                            source: "media-skip-backward-symbolic"
                            iconColor: !prevHover.enabled ? Theme.notchTextTertiary : (prevHover.containsMouse ? Theme.notchText : Theme.notchTextSecondary)
                        }

                        MouseArea {
                            id: prevHover
                            enabled: root.canPrev
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.LeftButton && root.activePlayer) {
                                    root.activePlayer.previous();
                                }
                            }
                        }
                    }

                    // Play / Pause
                    Rectangle {
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: 13
                        color: playPauseHover.containsMouse ? Theme.notchSurfaceHover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                        SymbolicIcon {
                            anchors.centerIn: parent
                            iconSize: 14
                            source: root.activePlayer && root.activePlayer.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                            iconColor: Theme.notchText
                        }

                        MouseArea {
                            id: playPauseHover
                            enabled: root.canToggle
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.LeftButton && root.activePlayer) {
                                    if (root.activePlayer.isPlaying) root.activePlayer.pause();
                                    else root.activePlayer.play();
                                }
                            }
                        }
                    }

                    // Next
                    Rectangle {
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 12
                        color: nextHover.containsMouse ? Theme.notchSurfaceHover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                        SymbolicIcon {
                            anchors.centerIn: parent
                            iconSize: 13
                            source: "media-skip-forward-symbolic"
                            iconColor: !nextHover.enabled ? Theme.notchTextTertiary : (nextHover.containsMouse ? Theme.notchText : Theme.notchTextSecondary)
                        }

                        MouseArea {
                            id: nextHover
                            enabled: root.canNext
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.LeftButton && root.activePlayer) {
                                    root.activePlayer.next();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // VIEW 2: EXPANDED MODE (expanded)
    // =========================================================================
    Item {
        anchors.fill: parent
        visible: root.expanded

        // 2.1 Expanded Notification — full card, cross-faded with the home view
        NotificationCard {
            id: detailCard
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            variant: "card"
            iconSize: 40
            maxBodyLines: 4
            alwaysShowClose: true
            notif: root.activeNotification
            opacity: root.viewMode === "notification" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
            onCloseRequested: root.dismissActiveNotification()
        }

        // 2.2A Expanded Spotify Music View (2-Column Player + Context)
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            anchors.topMargin: 6
            anchors.bottomMargin: 10
            spacing: 20
            opacity: root.viewMode === "music" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }

            // ── LEFT: Spotify Rich Player (290px) ──
            Item {
                Layout.preferredWidth: 290
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8

                    // Top Row: Album Artwork + Track Information
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        // Album Artwork (78x78) with raise hover action
                        Rectangle {
                            implicitWidth: 78
                            implicitHeight: 78
                            radius: 14
                            clip: true
                            color: Theme.notchSurfaceElevated
                            border.color: Theme.notchBorderSubtle
                            border.width: 1
                            Layout.alignment: Qt.AlignVCenter

                            Image {
                                anchors.fill: parent
                                source: root.activePlayer && root.activePlayer.trackArtUrl ? root.activePlayer.trackArtUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(156, 156)
                                asynchronous: true
                                visible: status === Image.Ready
                            }

                            SymbolicIcon {
                                anchors.centerIn: parent
                                iconSize: 32
                                source: "applications-multimedia"
                                iconColor: Theme.notchTextTertiary
                                visible: !root.activePlayer || !root.activePlayer.trackArtUrl
                            }

                            // Subtle hover overlay with raise indicator
                            Rectangle {
                                anchors.fill: parent
                                color: Theme.notchSurfaceHover
                                opacity: artMa.containsMouse ? 0.6 : 0.0
                                Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }

                                SymbolicIcon {
                                    anchors.centerIn: parent
                                    iconSize: 18
                                    source: "applications-multimedia"
                                    iconColor: Theme.notchText
                                }
                            }

                            MouseArea {
                                id: artMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.raisePlayer()
                            }
                        }

                        // Track Info
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 3

                            // Track Title
                            Text {
                                text: root.activePlayer && root.activePlayer.trackTitle ? root.activePlayer.trackTitle : I18n.tr("notch_now_playing")
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(14)
                                font.weight: Font.Bold
                                renderType: Theme.renderType
                                color: Theme.notchText
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            // Artist Name
                            Text {
                                text: root.activePlayer && root.activePlayer.trackArtist ? root.activePlayer.trackArtist : "—"
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(12)
                                renderType: Theme.renderType
                                color: Theme.notchTextSecondary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            // Album Title
                            Text {
                                visible: text.length > 0 && text !== "—"
                                text: (root.activePlayer && root.activePlayer.trackAlbum) ? root.activePlayer.trackAlbum : ""
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                renderType: Theme.renderType
                                color: Theme.notchTextTertiary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // Middle Row: Interactive Scrubber / Progress Bar
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        LayoutMirroring.enabled: false
                        LayoutMirroring.childrenInherit: true

                        // Elapsed Time
                        Text {
                            text: root.formatTime(root.playbackPosition)
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(10)
                            font.weight: Font.Medium
                            color: Theme.notchTextSecondary
                            Layout.preferredWidth: 32
                            horizontalAlignment: Text.AlignRight
                        }

                        // Scrubber Track (Fixed LTR coordinates & fill direction)
                        Item {
                            id: scrubberTrack
                            Layout.fillWidth: true
                            Layout.preferredHeight: 16
                            LayoutMirroring.enabled: false
                            LayoutMirroring.childrenInherit: true

                            Rectangle {
                                x: 0
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 4
                                radius: 2
                                color: Theme.notchSurfaceHover

                                // Filled progress from physical left to current progress
                                Rectangle {
                                    x: 0
                                    y: 0
                                    height: parent.height
                                    width: Math.max(0, Math.min(parent.width, parent.width * root.playbackProgress))
                                    radius: 2
                                    color: scrubberMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                                }
                            }

                            // Scrubber Thumb Handle
                            Rectangle {
                                x: Math.max(0, Math.min(scrubberTrack.width - width, (scrubberTrack.width * root.playbackProgress) - (width / 2)))
                                anchors.verticalCenter: parent.verticalCenter
                                width: (scrubberMa.containsMouse || root.scrubberSeeking) ? 10 : 0
                                height: width
                                radius: width / 2
                                color: Theme.notchText
                                Behavior on width { NumberAnimation { duration: Theme.motionFast } }
                            }

                            MouseArea {
                                id: scrubberMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton

                                function updateFromMouse(mouseX) {
                                    const ratio = Math.max(0.0, Math.min(1.0, mouseX / width));
                                    root.seekToRatio(ratio);
                                }

                                onPressed: (mouse) => {
                                    root.scrubberSeeking = true;
                                    updateFromMouse(mouse.x);
                                }
                                onPositionChanged: (mouse) => {
                                    if (pressed) updateFromMouse(mouse.x);
                                }
                                onReleased: {
                                    root.scrubberSeeking = false;
                                }
                            }
                        }

                        // Total Duration
                        Text {
                            text: root.trackLength > 0 ? root.formatTime(root.trackLength) : "--:--"
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(10)
                            font.weight: Font.Medium
                            color: Theme.notchTextTertiary
                            Layout.preferredWidth: 32
                            horizontalAlignment: Text.AlignLeft
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Bottom Row: Transport Controls (Shuffle, Prev, Play/Pause, Next, Loop)
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: 2
                        spacing: 12
                        LayoutMirroring.enabled: false
                        LayoutMirroring.childrenInherit: true

                        // Shuffle Button
                        Rectangle {
                            implicitWidth: 28
                            implicitHeight: 28
                            radius: 14
                            color: (root.activePlayer && root.activePlayer.shuffle)
                                   ? Theme.notchSurfaceActive
                                   : (shuffHover.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                            SymbolicIcon {
                                anchors.centerIn: parent
                                source: "media-playlist-shuffle-symbolic"
                                iconSize: 13
                                iconColor: (root.activePlayer && root.activePlayer.shuffle)
                                           ? Theme.notchText
                                           : (!shuffHover.enabled ? Theme.notchTextTertiary : (shuffHover.containsMouse ? Theme.notchText : Theme.notchTextSecondary))
                            }

                            MouseArea {
                                id: shuffHover
                                enabled: root.shuffleSupported
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.activePlayer) root.activePlayer.shuffle = !root.activePlayer.shuffle;
                                }
                            }
                        }

                        // Previous Button
                        Rectangle {
                            implicitWidth: 30
                            implicitHeight: 30
                            radius: 15
                            color: prevExpHover.containsMouse ? Theme.notchSurfaceHover : "transparent"
                            border.color: prevExpHover.containsMouse ? Theme.notchBorderHighlight : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            SymbolicIcon {
                                anchors.centerIn: parent
                                source: "media-skip-backward-symbolic"
                                iconSize: 14
                                iconColor: !prevExpHover.enabled ? Theme.notchTextTertiary : (prevExpHover.containsMouse ? Theme.notchText : Theme.notchTextSecondary)
                            }

                            MouseArea {
                                id: prevExpHover
                                enabled: root.canPrev
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton
                                onClicked: if (root.activePlayer) root.activePlayer.previous()
                            }
                        }

                        // Play / Pause Button
                        Rectangle {
                            implicitWidth: 36
                            implicitHeight: 36
                            radius: 18
                            color: playExpHover.containsMouse ? Theme.notchSurfaceElevated : Theme.notchSurface
                            border.color: playExpHover.containsMouse ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            SymbolicIcon {
                                anchors.centerIn: parent
                                source: (root.activePlayer && root.activePlayer.isPlaying) ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                                iconSize: 16
                                iconColor: Theme.notchText
                            }

                            MouseArea {
                                id: playExpHover
                                enabled: root.canToggle
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton
                                onClicked: {
                                    if (root.activePlayer) {
                                        if (root.activePlayer.isPlaying) root.activePlayer.pause();
                                        else root.activePlayer.play();
                                    }
                                }
                            }
                        }

                        // Next Button
                        Rectangle {
                            implicitWidth: 30
                            implicitHeight: 30
                            radius: 15
                            color: nextExpHover.containsMouse ? Theme.notchSurfaceHover : "transparent"
                            border.color: nextExpHover.containsMouse ? Theme.notchBorderHighlight : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            SymbolicIcon {
                                anchors.centerIn: parent
                                source: "media-skip-forward-symbolic"
                                iconSize: 14
                                iconColor: !nextExpHover.enabled ? Theme.notchTextTertiary : (nextExpHover.containsMouse ? Theme.notchText : Theme.notchTextSecondary)
                            }

                            MouseArea {
                                id: nextExpHover
                                enabled: root.canNext
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton
                                onClicked: if (root.activePlayer) root.activePlayer.next()
                            }
                        }

                        // Repeat / Loop Button
                        Rectangle {
                            id: loopBtn
                            implicitWidth: 28
                            implicitHeight: 28
                            radius: 14
                            readonly property bool isLoopActive: root.activePlayer && root.activePlayer.loopState !== MprisLoopState.None
                            color: isLoopActive
                                   ? Theme.notchSurfaceActive
                                   : (loopHover.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                            SymbolicIcon {
                                anchors.centerIn: parent
                                source: (root.activePlayer && root.activePlayer.loopState === MprisLoopState.Track)
                                        ? "media-playlist-repeat-song-symbolic"
                                        : "media-playlist-repeat-symbolic"
                                iconSize: 13
                                iconColor: loopBtn.isLoopActive
                                           ? Theme.notchText
                                           : (!loopHover.enabled ? Theme.notchTextTertiary : (loopHover.containsMouse ? Theme.notchText : Theme.notchTextSecondary))
                            }

                            MouseArea {
                                id: loopHover
                                enabled: root.loopSupported
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.cycleLoop()
                            }
                        }

                        // Like / Heart Button (Optional: visible ONLY when SpotifyBridgeService.connected)
                        Rectangle {
                            id: likeBtn
                            visible: SpotifyBridgeService.connected
                            implicitWidth: 28
                            implicitHeight: 28
                            radius: 14
                            color: SpotifyBridgeService.liked
                                   ? Theme.notchSurfaceActive
                                   : (likeHover.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                            SymbolicIcon {
                                anchors.centerIn: parent
                                source: SpotifyBridgeService.liked ? "heart-symbolic" : "heart-outline-symbolic"
                                iconSize: 13
                                iconColor: SpotifyBridgeService.liked
                                           ? Theme.notchText
                                           : (likeHover.containsMouse ? Theme.notchText : Theme.notchTextSecondary)
                            }

                            MouseArea {
                                id: likeHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: SpotifyBridgeService.toggleLike()
                            }
                        }
                    }
                }
            }

            // ── RIGHT: Music Switching & Volume ──
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Context & Music Switching Card
                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: Theme.notchSurfaceElevated
                    border.color: Theme.notchBorderSubtle
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        // Header
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            SymbolicIcon {
                                source: isBridgeQueueActive ? "view-media-playlist-symbolic" : "view-list-symbolic"
                                iconSize: 13
                                iconColor: Theme.notchTextSecondary
                            }

                            Text {
                                text: isBridgeQueueActive ? I18n.tr("notch_up_next") : I18n.tr("notch_quick_switch")
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: Font.DemiBold
                                color: Theme.notchTextSecondary
                            }

                            Item { Layout.fillWidth: true }

                            // Track / queue badge
                            Rectangle {
                                visible: isBridgeQueueActive || root.trackNumber > 0
                                implicitWidth: trackNumText.implicitWidth + 8
                                implicitHeight: 16
                                radius: 8
                                color: Theme.notchSurfaceHover

                                Text {
                                    id: trackNumText
                                    anchors.centerIn: parent
                                    text: isBridgeQueueActive
                                          ? (I18n.digits(SpotifyBridgeService.upNext.length) + " " + I18n.tr("notch_next_track"))
                                          : (I18n.tr("notch_track_number") + " " + I18n.digits(root.trackNumber))
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(9)
                                    font.weight: Font.Bold
                                    color: Theme.notchText
                                }
                            }
                        }

                        // Up Next Queue Rows (Active when Spicetify bridge is connected)
                        Repeater {
                            model: isBridgeQueueActive ? SpotifyBridgeService.upNext.slice(0, 3) : []

                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                implicitHeight: 28
                                radius: 6
                                color: upNextMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurface
                                border.color: upNextMa.containsMouse ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                                Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Text {
                                        text: I18n.digits(index + 1)
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(10)
                                        font.weight: Font.Bold
                                        color: Theme.notchTextTertiary
                                        Layout.preferredWidth: 14
                                    }

                                    Text {
                                        text: modelData.title || ""
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(11)
                                        font.weight: Font.Medium
                                        color: upNextMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: modelData.artist || ""
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(10)
                                        font.weight: Font.Normal
                                        color: Theme.notchTextTertiary
                                        elide: Text.ElideRight
                                        Layout.maximumWidth: 90
                                        visible: text.length > 0
                                    }
                                }

                                MouseArea {
                                    id: upNextMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }
                            }
                        }

                        // Option 1: Liked Songs (المفضلة) - Fallback when bridge queue inactive
                        Rectangle {
                            visible: !isBridgeQueueActive
                            Layout.fillWidth: true
                            implicitHeight: 28
                            radius: 6
                            color: favMa.pressed ? Theme.notchSurfaceActive : (favMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurface)
                            border.color: favMa.containsMouse ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 7

                                SymbolicIcon {
                                    source: "starred-symbolic"
                                    iconSize: 13
                                    iconColor: favMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                                }

                                Text {
                                    text: I18n.tr("notch_favorites")
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(11)
                                    font.weight: Font.Medium
                                    color: favMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                SymbolicIcon {
                                    source: "media-playback-start-symbolic"
                                    iconSize: 10
                                    iconColor: Theme.notchTextTertiary
                                    opacity: favMa.containsMouse ? 1.0 : 0.4
                                    Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }
                                }
                            }

                            MouseArea {
                                id: favMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.switchMusicContext("spotify:collection:tracks")
                            }
                        }

                        // Option 2: Playlists (قوائم التشغيل) - Fallback when bridge queue inactive
                        Rectangle {
                            visible: !isBridgeQueueActive
                            Layout.fillWidth: true
                            implicitHeight: 28
                            radius: 6
                            color: playlMa.pressed ? Theme.notchSurfaceActive : (playlMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurface)
                            border.color: playlMa.containsMouse ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 7

                                SymbolicIcon {
                                    source: "view-media-playlist-symbolic"
                                    iconSize: 13
                                    iconColor: playlMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                                }

                                Text {
                                    text: I18n.tr("notch_playlists")
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(11)
                                    font.weight: Font.Medium
                                    color: playlMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                SymbolicIcon {
                                    source: "media-playback-start-symbolic"
                                    iconSize: 10
                                    iconColor: Theme.notchTextTertiary
                                    opacity: playlMa.containsMouse ? 1.0 : 0.4
                                    Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }
                                }
                            }

                            MouseArea {
                                id: playlMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.switchMusicContext("spotify:collection:playlists")
                            }
                        }

                        // Option 3: Current Album or Open in Player - Fallback when bridge queue inactive
                        Rectangle {
                            visible: !isBridgeQueueActive
                            Layout.fillWidth: true
                            implicitHeight: 28
                            radius: 6
                            color: albMa.pressed ? Theme.notchSurfaceActive : (albMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurface)
                            border.color: albMa.containsMouse ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 7

                                SymbolicIcon {
                                    source: "applications-multimedia"
                                    iconSize: 13
                                    iconColor: albMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                                }

                                Text {
                                    text: (root.activePlayer && root.activePlayer.trackAlbum)
                                          ? (I18n.tr("notch_current_album") + ": " + root.activePlayer.trackAlbum)
                                          : I18n.tr("notch_open_in_player")
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(11)
                                    font.weight: Font.Medium
                                    color: albMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                SymbolicIcon {
                                    source: "media-playback-start-symbolic"
                                    iconSize: 10
                                    iconColor: Theme.notchTextTertiary
                                    opacity: albMa.containsMouse ? 1.0 : 0.4
                                    Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }
                                }
                            }

                            MouseArea {
                                id: albMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.raisePlayer()
                            }
                        }

                        Item { Layout.fillHeight: true }

                        // Player Volume Slider Row (Strictly LTR coordinates & fill direction)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: root.volumeSupported
                            LayoutMirroring.enabled: false
                            LayoutMirroring.childrenInherit: true

                            // Mute / Speaker Icon Button (Physical Left = 0%)
                            Rectangle {
                                implicitWidth: 22
                                implicitHeight: 22
                                radius: 11
                                color: muteMa.containsMouse ? Theme.notchSurfaceHover : "transparent"

                                SymbolicIcon {
                                    anchors.centerIn: parent
                                    source: (root.activePlayer && root.activePlayer.volume > 0.01) ? "audio-volume-high-symbolic" : "audio-volume-muted-symbolic"
                                    iconSize: 13
                                    iconColor: Theme.notchTextSecondary
                                }

                                MouseArea {
                                    id: muteMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleMute()
                                }
                            }

                            // Volume Track
                            Item {
                                id: volTrack
                                Layout.fillWidth: true
                                Layout.preferredHeight: 14
                                LayoutMirroring.enabled: false
                                LayoutMirroring.childrenInherit: true

                                Rectangle {
                                    x: 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: 4
                                    radius: 2
                                    color: Theme.notchSurfaceHover

                                    // Filled bar starting from physical left (speaker side)
                                    Rectangle {
                                        x: 0
                                        y: 0
                                        height: parent.height
                                        width: Math.max(0, Math.min(parent.width, parent.width * (root.activePlayer ? root.activePlayer.volume : 0)))
                                        radius: 2
                                        color: volMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                                    }
                                }

                                // Volume Thumb Handle
                                Rectangle {
                                    readonly property real volRatio: root.activePlayer ? root.activePlayer.volume : 0
                                    x: Math.max(0, Math.min(volTrack.width - width, (volTrack.width * volRatio) - (width / 2)))
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: (volMa.containsMouse || volMa.pressed) ? 10 : 0
                                    height: width
                                    radius: width / 2
                                    color: Theme.notchText
                                    Behavior on width { NumberAnimation { duration: Theme.motionFast } }
                                }

                                MouseArea {
                                    id: volMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    function setVol(mouseX) {
                                        if (!root.activePlayer) return;
                                        const ratio = Math.max(0.0, Math.min(1.0, mouseX / width));
                                        root.activePlayer.volume = ratio;
                                    }

                                    onPressed: (mouse) => setVol(mouse.x)
                                    onPositionChanged: (mouse) => {
                                        if (pressed) setVol(mouse.x);
                                    }
                                }
                            }

                            // Volume Percentage Text (Physical Right = 100%)
                            Text {
                                text: I18n.digits(Math.round((root.activePlayer ? root.activePlayer.volume : 0) * 100)) + "%"
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(10)
                                font.weight: Font.Medium
                                color: Theme.notchTextTertiary
                                Layout.preferredWidth: 28
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
            }
        }

        // 2.2B Expanded Idle View (Centered Digital Clock & Date without calendar)
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 6
            visible: root.viewMode === "idle"
            opacity: root.viewMode === "idle" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }

            // Digital Clock: Hours:Minutes (Bold 34px) + Meridiem & Seconds
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Text {
                    text: I18n.clockDigits(root.currentTime)
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(34)
                    font.weight: Font.Bold
                    renderType: Theme.renderType
                    color: Theme.notchText
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    spacing: 0
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        text: I18n.meridiem(root.currentTime)
                        visible: text.length > 0
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(11)
                        font.weight: Font.Bold
                        color: Theme.notchText
                    }

                    Text {
                        text: I18n.digits(":" + String(root.currentTime.getSeconds()).padStart(2, "0"))
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(11)
                        color: Theme.notchTextTertiary
                    }
                }
            }

            // Localized Full Date (e.g. "الخميس، ٥ نوفمبر ٢٠٢٦")
            Text {
                text: I18n.fullDateText(root.currentTime)
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(13)
                font.weight: Font.Medium
                renderType: Theme.renderType
                color: Theme.notchTextSecondary
                Layout.alignment: Qt.AlignHCenter
            }

            // Quick Spotify Launcher Button
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                implicitWidth: playSpotifyRow.implicitWidth + 24
                implicitHeight: 28
                radius: 14
                color: playSpotifyMa.pressed ? Theme.notchSurfaceActive : (playSpotifyMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceElevated)
                border.color: playSpotifyMa.containsMouse ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                RowLayout {
                    id: playSpotifyRow
                    anchors.centerIn: parent
                    spacing: 6

                    SymbolicIcon {
                        iconSize: 13
                        source: "applications-multimedia"
                        iconColor: Theme.notchText
                    }

                    Text {
                        text: I18n.isRTL ? "تشغيل Spotify" : "Open Spotify"
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(11)
                        font.weight: Font.DemiBold
                        color: Theme.notchText
                    }
                }

                MouseArea {
                    id: playSpotifyMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            ConfigManager.launchMusic();
                        }
                    }
                }
            }
        }
    }
}

