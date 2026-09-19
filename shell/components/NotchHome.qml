import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
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

    // MPRIS Active Player
    property var activePlayer: {
        if (!Mpris.players || !Mpris.players.values)
            return null;
        const values = Mpris.players.values;
        for (let i = 0; i < values.length; i++) {
            if (values[i] && values[i].isPlaying) return values[i];
        }
        return values.length > 0 ? values[0] : null;
    }
    readonly property bool isMusicPlaying: activePlayer !== null && activePlayer.isPlaying

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
    readonly property string viewMode: notificationActive ? "notification" : (isMusicPlaying ? "music" : "idle")

    // Calendar helper functions (100% NotchNook matching)
    function getMonthName() {
        const monthsEn = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        const monthsAr = ["يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو", "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"];
        return I18n.isRTL ? monthsAr[root.currentTime.getMonth()] : monthsEn[root.currentTime.getMonth()];
    }

    function getDaysStrip() {
        const days = [];
        const dayNamesEn = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
        const dayNamesAr = ["أحد", "اثنين", "ثلاثاء", "أربعاء", "خميس", "جمعة", "سبت"];
        for (let offset = -3; offset <= 3; offset++) {
            const d = new Date(root.currentTime.getFullYear(), root.currentTime.getMonth(), root.currentTime.getDate() + offset);
            days.push({
                dayOffset: offset,
                dayNumber: d.getDate(),
                dayName: I18n.isRTL ? dayNamesAr[d.getDay()] : dayNamesEn[d.getDay()],
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
                iconColor: Theme.colors.accent
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
            anchors.rightMargin: 14
            spacing: 8
            visible: root.viewMode !== "notification"
            z: 1

            // ── SECTION A: Workspaces (Always visible) ────────────────────
            RowLayout {
                spacing: 4
                Layout.alignment: Qt.AlignVCenter

                Repeater {
                    model: ConfigManager.workspacesCount

                    delegate: Rectangle {
                        id: wsBtn
                        required property int index
                        readonly property int wsId: index + 1
                        readonly property bool isActive:
                            (root.hyprMonitor && root.hyprMonitor.activeWorkspace
                             && root.hyprMonitor.activeWorkspace.id === wsId)

                        implicitWidth: isActive ? 30 : 26
                        implicitHeight: 28
                        radius: Theme.notchRadiusPill

                        color: isActive
                               ? "#ffffff"
                               : (wsMouse.pressed
                                  ? Theme.notchSurfaceActive
                                  : (wsMouse.containsMouse ? Theme.notchSurfaceHover : "transparent"))
                        border.color: isActive
                                      ? "transparent"
                                      : (wsMouse.containsMouse ? Theme.notchBorder : "transparent")
                        border.width: 1

                        Behavior on color        { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                        Behavior on border.color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

                        Text {
                            anchors.centerIn: parent
                            text: wsBtn.wsId.toString()
                            color: wsBtn.isActive ? "#000000" : Theme.notchTextTertiary
                            font.family: Theme.typography.fontFamily
                            font.hintingPreference: Theme.hintingPreference
                            font.pixelSize: Theme.fontSize(13)
                            font.weight: wsBtn.isActive ? Font.Bold : Font.Medium
                            renderType: Theme.renderType
                            Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                        }

                        MouseArea {
                            id: wsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.LeftButton) Hyprland.dispatch("workspace " + wsBtn.wsId);
                            }
                        }
                    }
                }
            }

            // ── SECTION B: Subtle Divider (Visible when music is playing) ─
            Rectangle {
                visible: root.isMusicPlaying
                Layout.preferredWidth: 1
                Layout.preferredHeight: 20
                Layout.alignment: Qt.AlignVCenter
                color: Theme.notchBorder
            }

            // ── SECTION C: Mini Music Player ──────────────────────────────
            RowLayout {
                id: miniMusicPlayer
                visible: root.isMusicPlaying
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
            color: Theme.colors.accent
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
                color: Qt.alpha(Theme.colors.accent, 0.15)
                border.color: Qt.alpha(Theme.colors.accent, 0.4)
                border.width: 1

                SymbolicIcon {
                    anchors.centerIn: parent
                    iconSize: 24
                    source: root.activeNotification && root.activeNotification.appIcon ? root.activeNotification.appIcon : "dialog-information"
                    iconColor: Theme.colors.accent
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
                        color: Theme.colors.accent
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
                color: dismissExpHover.containsMouse ? Theme.colors.surfaceHover : Theme.colors.surfaceVariant
                border.color: Theme.colors.borderSubtle
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

                    // Album Artwork with Music Badge
                    Item {
                        implicitWidth: 72
                        implicitHeight: 72
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: 16
                            clip: true
                            color: "#181818"

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
                                iconColor: "#555555"
                                visible: !root.activePlayer || !root.activePlayer.trackArtUrl
                            }
                        }

                        // Red/Music badge at bottom-right corner
                        Rectangle {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: -2
                            anchors.bottomMargin: -2
                            width: 22
                            height: 22
                            radius: 6
                            color: "#fa243c" // Apple Music Red
                            border.color: "#000000"
                            border.width: 1.5

                            Text {
                                anchors.centerIn: parent
                                text: "♫"
                                font.pixelSize: Theme.fontSize(11)
                                font.bold: true
                                color: "#ffffff"
                            }
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
                            color: "#ffffff"
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
                            color: "#b0b0b0"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        // Artist Name (Line 3)
                        Text {
                            text: root.activePlayer && root.activePlayer.trackArtist ? root.activePlayer.trackArtist : "—"
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            renderType: Theme.renderType
                            color: "#757575"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        // Playback Controls Row: |◀   ⏸   ▶| (Pure solid white glyphs, no circles)
                        RowLayout {
                            spacing: 16
                            Layout.topMargin: 4

                            // Previous (|◀)
                            Text {
                                text: "|◀"
                                font.pixelSize: Theme.fontSize(12)
                                font.weight: Font.Bold
                                color: prevExpHover.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.85)

                                MouseArea {
                                    id: prevExpHover
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (root.activePlayer) root.activePlayer.previous()
                                }
                            }

                            // Play / Pause (⏸ / ▶)
                            Text {
                                text: root.activePlayer && root.activePlayer.isPlaying ? "⏸" : "▶"
                                font.pixelSize: Theme.fontSize(14)
                                font.weight: Font.Bold
                                color: playExpHover.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.95)

                                MouseArea {
                                    id: playExpHover
                                    anchors.fill: parent
                                    anchors.margins: -4
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

                            // Next (▶|)
                            Text {
                                text: "▶|"
                                font.pixelSize: Theme.fontSize(12)
                                font.weight: Font.Bold
                                color: nextExpHover.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.85)

                                MouseArea {
                                    id: nextExpHover
                                    anchors.fill: parent
                                    anchors.margins: -4
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
                            color: "#ffffff"
                        }

                        ColumnLayout {
                            spacing: 0
                            Text {
                                text: Qt.formatTime(root.currentTime, "AP")
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: Font.Bold
                                color: Theme.colors.accent
                            }
                            Text {
                                text: Qt.formatTime(root.currentTime, ":ss")
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                color: "#666666"
                            }
                        }
                    }

                    Text {
                        text: Qt.formatDate(root.currentTime, I18n.isRTL ? "dddd، d MMMM yyyy" : "dddd, MMMM d, yyyy")
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(12)
                        renderType: Theme.renderType
                        color: "#999999"
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
                        color: "#ffffff"
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

                                // Day of week abbreviation (M, T, W, THU, F, S, S)
                                Text {
                                    text: dayCol.modelData.isToday ? dayCol.modelData.dayName.toUpperCase() : dayCol.modelData.dayName.substring(0, 1).toUpperCase()
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(dayCol.modelData.isToday ? 9 : 8)
                                    font.weight: dayCol.modelData.isToday ? Font.Bold : Font.Normal
                                    color: dayCol.modelData.isToday ? "#ffffff" : "#555555"
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                // Day Number
                                Text {
                                    text: dayCol.modelData.dayNumber.toString()
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(dayCol.modelData.isToday ? 22 : 15)
                                    font.weight: dayCol.modelData.isToday ? Font.Bold : Font.Normal
                                    color: dayCol.modelData.isToday
                                           ? "#ffffff"
                                           : (dayCol.modelData.dayOffset === -2 ? "#3b82f6" : (dayCol.modelData.dayOffset === 2 ? "#ef5350" : "#666666"))
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
                        iconColor: "#7e7e7e"
                    }

                    Text {
                        text: I18n.tr("notch_today_events")
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(12)
                        renderType: Theme.renderType
                        color: "#7e7e7e"
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
            color: Theme.colors.accent
            visible: root.viewMode === "notification"
        }
    }
}

