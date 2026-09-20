import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQml.Models
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Hyprland
import "../theme"
import "../services"

Item {
    id: root

    property bool expanded: false
    property ShellScreen targetScreen: null
    readonly property HyprlandMonitor hyprMonitor: targetScreen ? Hyprland.monitorFor(targetScreen) : (Hyprland.focusedMonitor || null)

    LayoutMirroring.enabled: false
    LayoutMirroring.childrenInherit: true

    // Time & Date state
    property date currentTime: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentTime = new Date()
    }

    // MPRIS Active Player tracking
    property var activePlayer: null
    readonly property bool hasPlayer: activePlayer !== null
    readonly property bool isMusicPlaying: hasPlayer && activePlayer.isPlaying

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

        // 1. Priority 1: Check if any player is actively playing
        for (let i = 0; i < values.length; i++) {
            if (values[i] && values[i].isPlaying) {
                if (activePlayer !== values[i]) {
                    activePlayer = values[i];
                }
                return;
            }
        }

        // 2. Priority 2: If current activePlayer is still in values, keep it (prevent jumping upon pause)
        if (activePlayer) {
            for (let i = 0; i < values.length; i++) {
                if (values[i] === activePlayer) {
                    return;
                }
            }
        }

        // 3. Fallback: Previous activePlayer was closed or not set; pick first available player
        activePlayer = values[0] || null;
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

    Connections {
        target: NotificationManager
        function onToastRequested(notif) {
            root.activeNotification = notif;
            root.notificationActive = true;
            notifTimer.restart();
        }
    }

    Timer {
        id: notifTimer
        interval: 50
        repeat: true
        running: root.notificationActive
        property int elapsed: 0
        readonly property int duration: ConfigManager.notificationsTimeout || 5000

        onRunningChanged: {
            if (running) {
                elapsed = 0;
                root.notifRemainingRatio = 1.0;
            }
        }

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

        // 1.1 Compact Notification
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8
            visible: root.viewMode === "notification"

            SymbolicIcon {
                iconSize: 15
                source: root.activeNotification && root.activeNotification.appIcon ? root.activeNotification.appIcon : "dialog-information"
                iconColor: Theme.notchText
            }

            Text {
                text: root.activeNotification ? root.activeNotification.summary : ""
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(11)
                font.weight: Font.DemiBold
                renderType: Theme.renderType
                color: Theme.colors.text
                elide: Text.ElideRight
                Layout.maximumWidth: 120
            }

            Text {
                text: "•"
                font.pixelSize: Theme.fontSize(10)
                color: Theme.colors.textTertiary
            }

            Text {
                text: root.activeNotification ? root.activeNotification.body : ""
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(10)
                renderType: Theme.renderType
                color: Theme.colors.textSecondary
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            // Quick Dismiss '✕'
            Rectangle {
                implicitWidth: 16
                implicitHeight: 16
                radius: 8
                color: dismissHover.containsMouse ? Theme.colors.surfaceHover : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: Theme.fontSize(8)
                    color: Theme.colors.textSecondary
                }

                MouseArea {
                    id: dismissHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) root.notificationActive = false;
                    }
                }
            }
        }

        // 1.2 Merged Compact Row: Workspaces + Music Player
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8
            visible: root.viewMode !== "notification"
            z: 1

            // ── SECTION A: Workspaces (Dynamic WorkspaceIndicator) ────────────
            WorkspaceIndicator {
                hyprMonitor:    root.hyprMonitor
                staticCount:    ConfigManager.workspacesCount
                indicatorStyle: ConfigManager.workspaceIndicatorStyle || "icons"
                reduceMotion:   false
                Layout.alignment: Qt.AlignVCenter
            }

            // ── SECTION B: Subtle Divider (Visible when music player is present) ─
            Rectangle {
                visible: root.hasPlayer
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

                // Mini Controls
                RowLayout {
                    spacing: 4

                    Rectangle {
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 12
                        color: playPauseHover.containsMouse ? Theme.notchSurfaceHover : "transparent"

                        SymbolicIcon {
                            anchors.centerIn: parent
                            iconSize: 14
                            source: root.activePlayer && root.activePlayer.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                            iconColor: Theme.notchText
                        }

                        MouseArea {
                            id: playPauseHover
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

                    Rectangle {
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 12
                        color: nextHover.containsMouse ? Theme.notchSurfaceHover : "transparent"

                        SymbolicIcon {
                            anchors.centerIn: parent
                            iconSize: 14
                            source: "media-skip-forward-symbolic"
                            iconColor: nextHover.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                        }

                        MouseArea {
                            id: nextHover
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

        // Notification countdown bar at the bottom edge
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: parent.width * root.notifRemainingRatio
            height: 1.5
            color: Theme.notchText
            visible: root.viewMode === "notification"
        }
    }

    // =========================================================================
    // VIEW 2: EXPANDED MODE (expanded)
    // =========================================================================
    Item {
        anchors.fill: parent
        visible: root.expanded

        // 2.1 Expanded Notification
        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14
            visible: root.viewMode === "notification"

            Rectangle {
                implicitWidth: 46
                implicitHeight: 46
                radius: 12
                color: Theme.notchSurfaceElevated
                border.color: Theme.notchBorderHighlight
                border.width: 1

                SymbolicIcon {
                    anchors.centerIn: parent
                    iconSize: 24
                    source: root.activeNotification && root.activeNotification.appIcon ? root.activeNotification.appIcon : "dialog-information"
                    iconColor: Theme.notchText
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                RowLayout {
                    spacing: 6
                    Text {
                        text: root.activeNotification ? root.activeNotification.appName : "System"
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(11)
                        font.weight: Font.DemiBold
                        color: Theme.notchText
                    }
                    Text {
                        text: "• " + (root.activeNotification ? root.activeNotification.timeStr : "")
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(10)
                        color: Theme.colors.textTertiary
                    }
                }

                Text {
                    text: root.activeNotification ? root.activeNotification.summary : ""
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(13)
                    font.weight: Font.Bold
                    renderType: Theme.renderType
                    color: Theme.colors.text
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: root.activeNotification ? root.activeNotification.body : ""
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(11)
                    renderType: Theme.renderType
                    color: Theme.colors.textSecondary
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            // Dismiss Button
            Rectangle {
                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                color: dismissExpHover.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurface
                border.color: Theme.notchBorderSubtle
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: Theme.fontSize(11)
                    color: Theme.colors.text
                }

                MouseArea {
                    id: dismissExpHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.notificationActive = false
                }
            }
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
            visible: root.viewMode !== "notification"

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
                            Layout.topMargin: 4

                            // Previous
                            Rectangle {
                                implicitWidth: 26
                                implicitHeight: 26
                                radius: 13
                                color: prevExpHover.containsMouse ? Theme.notchSurfaceHover : "transparent"
                                Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                                SymbolicIcon {
                                    anchors.centerIn: parent
                                    source: "media-skip-backward-symbolic"
                                    iconSize: 13
                                    iconColor: prevExpHover.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                                }

                                MouseArea {
                                    id: prevExpHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (root.activePlayer) root.activePlayer.previous()
                                }
                            }

                            // Play / Pause
                            Rectangle {
                                implicitWidth: 28
                                implicitHeight: 28
                                radius: 14
                                color: playExpHover.containsMouse ? Theme.notchSurfaceHover : "transparent"
                                Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                                SymbolicIcon {
                                    anchors.centerIn: parent
                                    source: (root.activePlayer && root.activePlayer.isPlaying) ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                                    iconSize: 15
                                    iconColor: playExpHover.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                                }

                                MouseArea {
                                    id: playExpHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
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
                                implicitWidth: 26
                                implicitHeight: 26
                                radius: 13
                                color: nextExpHover.containsMouse ? Theme.notchSurfaceHover : "transparent"
                                Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                                SymbolicIcon {
                                    anchors.centerIn: parent
                                    source: "media-skip-forward-symbolic"
                                    iconSize: 13
                                    iconColor: nextExpHover.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                                }

                                MouseArea {
                                    id: nextExpHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
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
                            text: Qt.formatTime(root.currentTime, "hh:mm")
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(32)
                            font.weight: Font.Bold
                            renderType: Theme.renderType
                            color: Theme.notchText
                        }

                        ColumnLayout {
                            spacing: 0
                            Text {
                                text: Qt.formatTime(root.currentTime, "AP")
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: Font.Bold
                                color: Theme.notchText
                            }
                            Text {
                                text: Qt.formatTime(root.currentTime, ":ss")
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                color: Theme.notchTextTertiary
                            }
                        }
                    }

                    Text {
                        text: Qt.formatDate(root.currentTime, I18n.isRTL ? "dddd، d MMMM yyyy" : "dddd, MMMM d, yyyy")
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(12)
                        renderType: Theme.renderType
                        color: Theme.notchTextSecondary
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

        // Notification countdown bar at the bottom edge
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: parent.width * root.notifRemainingRatio
            height: 2
            color: Theme.notchText
            visible: root.viewMode === "notification"
        }
    }
}

