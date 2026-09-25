import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQml.Models
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Hyprland
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
    // Transport controls follow what the player actually supports (calling previous()/next()
    // on a player that can't do it only logged a warning).
    readonly property bool canPrev: hasPlayer && activePlayer.canGoPrevious
    readonly property bool canNext: hasPlayer && activePlayer.canGoNext
    readonly property bool canToggle: hasPlayer && activePlayer.canTogglePlaying

    function playerHasMedia(p) {
        if (!p) return false;
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

        const pref = ConfigManager.musicPreferredPlayer || "auto";

        // 1. Priority 0: Preferred player if specified and currently active with media
        if (pref !== "auto") {
            const prefClean = pref.toLowerCase().replace(/\.desktop$/, "");
            for (let i = 0; i < values.length; i++) {
                const p = values[i];
                if (!p) continue;
                const dEntry = (p.desktopEntry || "").toLowerCase().replace(/\.desktop$/, "");
                const ident = (p.identity || "").toLowerCase();
                if (dEntry === prefClean || ident === prefClean || (dEntry && prefClean.includes(dEntry))) {
                    if (root.playerHasMedia(p)) {
                        if (activePlayer !== p) activePlayer = p;
                        return;
                    }
                }
            }
        }

        // 2. Priority 1 (Auto): Check if any player is actively playing
        for (let i = 0; i < values.length; i++) {
            if (values[i] && values[i].isPlaying) {
                if (activePlayer !== values[i]) {
                    activePlayer = values[i];
                }
                return;
            }
        }

        // 3. Priority 2: If current activePlayer is still in values and has media, keep it (prevent jumping upon pause)
        if (activePlayer && root.playerHasMedia(activePlayer)) {
            for (let i = 0; i < values.length; i++) {
                if (values[i] === activePlayer) {
                    return;
                }
            }
        }

        // 4. Priority 3: Fallback to any player that has media loaded (e.g. paused music app)
        for (let i = 0; i < values.length; i++) {
            if (root.playerHasMedia(values[i])) {
                activePlayer = values[i];
                return;
            }
        }

        // 5. Default state: No player has active media or playback
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

    // Calendar helper functions (100% NotchNook matching)
    function getMonthName() {
        const monthsEn = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        const monthsAr = ["يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو", "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"];
        return I18n.isRTL ? monthsAr[root.currentTime.getMonth()] : monthsEn[root.currentTime.getMonth()];
    }

    function getDaysStrip() {
        const days = [];
        const dayNamesEn = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
        const dayNamesAr = ["أحد", "إثنين", "ثلاثاء", "أربعاء", "خميس", "جمعة", "سبت"];
        const dayAbbrAr = ["أح", "إث", "ثل", "أر", "خم", "جم", "سب"];
        for (let offset = -3; offset <= 3; offset++) {
            const d = new Date(root.currentTime.getFullYear(), root.currentTime.getMonth(), root.currentTime.getDate() + offset);
            const dayIdx = d.getDay();
            days.push({
                dayOffset: offset,
                dayNumber: d.getDate(),
                dayName: I18n.isRTL ? dayNamesAr[dayIdx] : dayNamesEn[dayIdx],
                dayAbbr: I18n.isRTL ? dayAbbrAr[dayIdx] : dayNamesEn[dayIdx].substring(0, 1),
                isToday: offset === 0
            });
        }
        return days;
    }

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

        // 2.2 Expanded Main View (Split: Music/Clock on Start + Calendar Strip on End)
        // 2.2 Expanded Main View: Music Player on Left + Calendar on Right (100% NotchNook Match)
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            anchors.topMargin: 6
            anchors.bottomMargin: 10
            spacing: 24
            opacity: root.viewMode !== "notification" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }

            // ── LEFT: Music Player (or Clock when idle) ──
            Item {
                Layout.preferredWidth: 260
                Layout.fillHeight: true

                // Sub-view: Music Playing (matches reference Lucy / Liberation / The Divine Comedy)
                RowLayout {
                    anchors.fill: parent
                    spacing: 14
                    visible: root.viewMode === "music"

                    // Album Artwork
                    Rectangle {
                        implicitWidth: 72
                        implicitHeight: 72
                        radius: 16
                        clip: true
                        color: Theme.notchSurfaceElevated
                        border.color: Theme.notchBorderSubtle
                        border.width: 1
                        Layout.alignment: Qt.AlignVCenter

                        Image {
                            anchors.fill: parent
                            source: root.activePlayer && root.activePlayer.trackArtUrl ? root.activePlayer.trackArtUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(144, 144)
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
                    }

                    // Track Info & Borderless Controls
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        // Track Title
                        Text {
                            horizontalAlignment: Text.AlignLeft   // reading start (mirrored in Arabic)
                            text: root.activePlayer && root.activePlayer.trackTitle ? root.activePlayer.trackTitle : I18n.tr("notch_now_playing")
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(15)
                            font.weight: Font.Bold
                            renderType: Theme.renderType
                            color: Theme.notchText
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        // Album Title (Line 2)
                        Text {
                            horizontalAlignment: Text.AlignLeft   // reading start (mirrored in Arabic)
                            text: (root.activePlayer && root.activePlayer.trackAlbum)
                                  ? root.activePlayer.trackAlbum
                                  : ((root.activePlayer && root.activePlayer.trackArtist) ? root.activePlayer.trackArtist : "Deloway Music")
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(12)
                            renderType: Theme.renderType
                            color: Theme.notchTextSecondary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        // Artist Name (Line 3)
                        Text {
                            horizontalAlignment: Text.AlignLeft   // reading start (mirrored in Arabic)
                            text: root.activePlayer && root.activePlayer.trackArtist ? root.activePlayer.trackArtist : "—"
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            renderType: Theme.renderType
                            color: Theme.notchTextTertiary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        // Playback Controls Row: Previous, Play/Pause, Next
                        RowLayout {
                            spacing: 8
                            Layout.topMargin: 6
                            LayoutMirroring.enabled: false
                            LayoutMirroring.childrenInherit: false

                            // Previous
                            Rectangle {
                                implicitWidth: 32
                                implicitHeight: 32
                                radius: 16
                                color: prevExpHover.containsMouse ? Theme.notchSurfaceHover : "transparent"
                                border.color: prevExpHover.containsMouse ? Theme.notchBorderHighlight : "transparent"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                                Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                                SymbolicIcon {
                                    anchors.centerIn: parent
                                    source: "media-skip-backward-symbolic"
                                    iconSize: 15
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

                            // Play / Pause (Prominent central control)
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

                            // Next
                            Rectangle {
                                implicitWidth: 32
                                implicitHeight: 32
                                radius: 16
                                color: nextExpHover.containsMouse ? Theme.notchSurfaceHover : "transparent"
                                border.color: nextExpHover.containsMouse ? Theme.notchBorderHighlight : "transparent"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                                Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                                SymbolicIcon {
                                    anchors.centerIn: parent
                                    source: "media-skip-forward-symbolic"
                                    iconSize: 15
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
                        }
                    }
                }

                // Sub-view: Digital Clock & Date (When idle)
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 3
                    visible: root.viewMode === "idle"
                    Layout.alignment: Qt.AlignVCenter

                    RowLayout {
                        spacing: 8
                        Text {
                            text: I18n.clockDigits(root.currentTime)
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(32)
                            font.weight: Font.Bold
                            renderType: Theme.renderType
                            color: Theme.notchText
                        }

                        ColumnLayout {
                            spacing: 0
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

                    Text {
                        text: I18n.fullDateText(root.currentTime)
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(12)
                        renderType: Theme.renderType
                        color: Theme.notchTextSecondary
                    }

                    // Quick Music Launcher button
                    Rectangle {
                        height: 28
                        implicitWidth: playMusicRow.implicitWidth + Theme.space24
                        radius: 14
                        color: playMusicMa.pressed ? Theme.notchSurfaceActive : (playMusicMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceElevated)
                        border.color: playMusicMa.containsMouse ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                        border.width: 1
                        Layout.topMargin: 4
                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                        Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                        RowLayout {
                            id: playMusicRow
                            anchors.centerIn: parent
                            spacing: 6

                            SymbolicIcon {
                                iconSize: 12
                                source: "media-playback-start-symbolic"
                                iconColor: Theme.notchText
                            }

                            Text {
                                text: I18n.isRTL ? "تشغيل الموسيقى" : "Play Music"
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: Font.DemiBold
                                color: Theme.notchText
                            }
                        }

                        MouseArea {
                            id: playMusicMa
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

            // ── RIGHT: Calendar Strip (Matches reference Jul + 7 days + Nothing for today) ──
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 6

                // Top: Month name + Horizontal Days Strip
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Large Month Label (e.g. Jul / سبتمبر)
                    Text {
                        text: root.getMonthName()
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(24)
                        font.weight: Font.Bold
                        renderType: Theme.renderType
                        color: Theme.notchText
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // 7-Day Horizontal Strip
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: root.getDaysStrip()

                            delegate: ColumnLayout {
                                id: dayCol
                                required property var modelData
                                spacing: 2
                                Layout.alignment: Qt.AlignHCenter

                                // Day of week abbreviation
                                Text {
                                    text: dayCol.modelData.isToday ? dayCol.modelData.dayName.toUpperCase() : dayCol.modelData.dayAbbr.toUpperCase()
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(dayCol.modelData.isToday ? 9 : 8)
                                    font.weight: dayCol.modelData.isToday ? Font.Bold : Font.Normal
                                    color: dayCol.modelData.isToday ? Theme.notchText : Theme.notchTextTertiary
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                // Day Number
                                Text {
                                    text: dayCol.modelData.dayNumber.toString()
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(dayCol.modelData.isToday ? 22 : 15)
                                    font.weight: dayCol.modelData.isToday ? Font.Bold : Font.Normal
                                    color: dayCol.modelData.isToday
                                           ? Theme.notchText
                                           : (dayCol.modelData.dayOffset === -2 ? Theme.calendarPast : (dayCol.modelData.dayOffset === 2 ? Theme.calendarFuture : Theme.notchTextTertiary))
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                    }
                }

                // Bottom: Calendar Icon + "Nothing for today" status
                RowLayout {
                    spacing: 6
                    Layout.alignment: Qt.AlignHCenter

                    SymbolicIcon {
                        iconSize: 13
                        source: "x-office-calendar-symbolic"
                        iconColor: Theme.notchTextTertiary
                    }

                    Text {
                        text: I18n.tr("notch_today_events")
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(12)
                        renderType: Theme.renderType
                        color: Theme.notchTextTertiary
                    }
                }
            }
        }
    }
}

