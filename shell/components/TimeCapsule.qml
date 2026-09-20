import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"

// TimeCapsule — Top-left status capsule for DeloWay Smart TopBar.
// Compact mode: Crisp bold time + localized short date powered by SystemClock.
// Expanded mode (Phase 2): Calendar + Hardware telemetry.
PanelWindow {
    id: root

    required property ShellScreen targetScreen
    screen: targetScreen

    anchors {
        top: true
        left: true
    }

    readonly property real earRadius: 18
    readonly property real bottomRadius: 26
    readonly property real capsuleGap: 10

    margins {
        top: root.isExpanded ? 0 : 10
        left: Math.round(10 - (root.isExpanded ? root.earRadius : 0))
    }

    color: "transparent"
    visible: ConfigManager.timeCapsuleEnabled

    WlrLayershell.namespace: "deloway:time-capsule"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: root.isExpanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    // ── Dimensions & State ────────────────────────────────────────────────
    readonly property bool isExpanded: ShellState.timeCapsuleExpanded
    readonly property real compactHeight: 44
    readonly property real compactWidth: Math.max(132, compactContentRow.implicitWidth + 36)
    readonly property real expandedWidth: 440
    readonly property real expandedHeight: 520

    property real currentWidth: root.isExpanded ? root.expandedWidth : root.compactWidth
    property real currentHeight: root.isExpanded ? root.expandedHeight : root.compactHeight

    Behavior on currentWidth  { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
    Behavior on currentHeight { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }

    implicitWidth:  Math.round(root.currentWidth + (root.isExpanded ? root.earRadius * 2 : 0))
    implicitHeight: Math.round(root.currentHeight + 8)

    // ── SystemClock: minute precision in compact, seconds in expanded ─────
    SystemClock {
        id: sysClock
        precision: root.isExpanded ? SystemClock.Seconds : SystemClock.Minutes
    }

    // ── Localization & Date Helpers ───────────────────────────────────────
    readonly property var arDays: ["الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت"]
    readonly property var arMonths: [
        "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
        "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"
    ]
    readonly property var enDays: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    readonly property var enMonths: [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ]

    readonly property string formattedTime: {
        const d = sysClock.date;
        if (!d) return "--:--";
        if (ConfigManager.clockFormat === "24h") {
            return Qt.formatDateTime(d, "hh:mm");
        }
        return Qt.formatDateTime(d, "h:mm ap");
    }

    readonly property string formattedShortDate: {
        const d = sysClock.date;
        if (!d) return "";
        const dayIdx = d.getDay();
        const monthIdx = d.getMonth();
        const dateNum = d.getDate();

        if (I18n.isRTL) {
            return (arDays[dayIdx] || "") + "، " + dateNum + " " + (arMonths[monthIdx] || "");
        }
        return (enDays[dayIdx] || "") + ", " + (enMonths[monthIdx] || "") + " " + dateNum;
    }

    // ── Keyboard Dismissal ────────────────────────────────────────────────
    Shortcut {
        sequence: "Escape"
        enabled: root.isExpanded
        onActivated: ShellState.closeTimeCapsule()
    }

    // ── Outer Shape & Notch Framing ───────────────────────────────────────
    NotchFrame {
        id: notchFrame
        anchors.fill: parent
        isExpanded: root.isExpanded
        currentWidth: root.currentWidth
        currentHeight: root.currentHeight
        earRadius: root.earRadius
        bottomRadius: root.bottomRadius

        // ═══════════════════════════════════════════════════════════════════
        // COMPACT VIEW: Time & Date side-by-side
        // ═══════════════════════════════════════════════════════════════════
        Rectangle {
            anchors.fill: parent
            radius: root.bottomRadius
            color: compactMa.containsMouse ? Theme.notchSurfaceHover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
            visible: !root.isExpanded

            RowLayout {
                id: compactContentRow
                anchors.centerIn: parent
                spacing: Theme.space8
                LayoutMirroring.enabled: I18n.isRTL
                LayoutMirroring.childrenInherit: true

                // Bold Time
                Text {
                    text: root.formattedTime
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(13)
                    font.weight: Font.Bold
                    color: Theme.notchText
                    renderType: Theme.renderType
                    Layout.alignment: Qt.AlignVCenter
                }

                // Subtle vertical divider
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 14
                    Layout.alignment: Qt.AlignVCenter
                    color: Theme.notchBorder
                    opacity: 0.55
                }

                // Short Date
                Text {
                    text: root.formattedShortDate
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(11)
                    font.weight: Font.Normal
                    color: Theme.notchTextSecondary
                    renderType: Theme.renderType
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            MouseArea {
                id: compactMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton
                onClicked: ShellState.toggleTimeCapsule()
                onWheel: (wheel) => {
                    wheel.accepted = true;
                    ShellState.toggleTimeCapsule();
                }
            }
        }
    }
}
