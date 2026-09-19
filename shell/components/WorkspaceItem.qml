import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../theme"
import "../services"

// WorkspaceItem — Single workspace visual unit.
// Three states:
//   1. empty (in static range)  — small dot 6px, faint
//   2. has toplevels, not active — circle 28px with app icon (AppIcon)
//   3. active workspace          — pill, taller, bright bg, number + icon
Item {
    id: root

    property int    wsId: 1
    property bool   isActive: false
    property bool   hasTops: false
    property var    tops: []
    property string primaryIcon: ""
    property int    extraCount: 0
    property string style: "icons"      // "icons" | "numbers" | "dots"
    property bool   reduceMotion: false

    signal switchRequested(int id)
    signal closeAllRequested(int id)

    // ── Size tokens ───────────────────────────────────────────────────────
    readonly property int dotSize:    Theme.wsDotSize         // 6
    readonly property int circleSize: Theme.wsCircleSize      // 28
    readonly property int pillW:      Theme.wsPillWidth       // 36
    readonly property int pillH:      Theme.wsPillHeight      // 32
    readonly property int iconSz:     Theme.wsIconSize        // 16
    readonly property int badgeSz:    Theme.wsBadgeSize       // 14

    // Fixed row height so the RowLayout never jumps
    implicitWidth:  isActive ? pillW : (hasTops ? circleSize : dotSize)
    implicitHeight: pillH

    // ── Main shape ───────────────────────────────────────────────────────
    Rectangle {
        id: shape

        // Animate to active pill or occupied circle or empty dot
        readonly property int targetW: root.isActive ? root.pillW
                                     : root.hasTops  ? root.circleSize
                                     :                 root.dotSize
        readonly property int targetH: root.isActive ? root.pillH
                                     : root.hasTops  ? root.circleSize
                                     :                 root.dotSize

        width:  targetW
        height: targetH
        radius: targetH / 2
        anchors.centerIn: parent

        Behavior on width  { NumberAnimation { duration: root.reduceMotion ? 0 : Theme.motionBase; easing.type: Theme.easingEnter } }
        Behavior on height { NumberAnimation { duration: root.reduceMotion ? 0 : Theme.motionBase; easing.type: Theme.easingEnter } }
        Behavior on radius { NumberAnimation { duration: root.reduceMotion ? 0 : Theme.motionBase; easing.type: Theme.easingEnter } }

        color: root.isActive
               ? Theme.wsActiveBg
               : (root.hasTops
                  ? Theme.wsOccupiedBg
                  : (wsMA.containsMouse ? Theme.notchSurfaceHover : Theme.wsEmptyBg))
        Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

        opacity: root.isActive  ? 1.0
               : root.hasTops   ? 1.0
               : wsMA.containsMouse ? 0.75 : 0.45
        Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }

        // ── App icon (for occupied or active workspaces) ──────────────
        AppIcon {
            id: wsAppIcon
            anchors.centerIn: parent
            iconSize: root.iconSz
            source: root.primaryIcon
            visible: (root.isActive || root.hasTops)
                     && root.style === "icons"
                     && root.primaryIcon.length > 0
        }

        // ── Workspace number ─────────────────────────────────────────
        Text {
            anchors.centerIn: parent
            // Show: always in "numbers" style, or in active pill if no icon shows
            visible: root.style === "numbers"
                     || (root.isActive && (root.style !== "icons" || root.primaryIcon.length === 0))
            text: root.wsId.toString()
            font.family: Theme.typography.fontFamily
            font.pixelSize: Theme.fontSize(root.isActive ? 13 : 11)
            font.weight: root.isActive ? Font.Bold : Font.Medium
            color: root.isActive ? Theme.wsActiveText : Theme.notchTextSecondary
            renderType: Theme.renderType
        }

        // ── Hover number for empty dot (icons / dots style) ───────────
        Text {
            anchors.centerIn: parent
            visible: !root.isActive && !root.hasTops
                     && root.style !== "numbers"
                     && wsMA.containsMouse
            text: root.wsId.toString()
            font.family: Theme.typography.fontFamily
            font.pixelSize: Theme.fontSize(9)
            font.weight: Font.Medium
            color: Theme.notchTextTertiary
            renderType: Theme.renderType
        }

        // ── Extra windows badge (+N) ──────────────────────────────────
        Rectangle {
            id: badge
            visible: root.hasTops && root.extraCount > 0
            width:  badgeLabel.implicitWidth + 6
            height: root.badgeSz
            radius: root.badgeSz / 2
            color:  Theme.notchBackground
            border.color: Theme.notchBorder
            border.width: 1
            anchors {
                right:  shape.right;  rightMargin: -2
                top:    shape.top;    topMargin:   -2
            }
            z: 2

            Text {
                id: badgeLabel
                anchors.centerIn: parent
                text: "+" + root.extraCount
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(8)
                font.weight: Font.Bold
                color: Theme.notchTextSecondary
                renderType: Theme.renderType
            }
        }
    }

    // ── Mouse area ────────────────────────────────────────────────────────
    MouseArea {
        id: wsMA
        anchors.fill: parent
        // Expand hit area a bit for small dots
        anchors.margins: root.hasTops || root.isActive ? 0 : -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                root.switchRequested(root.wsId);
            } else if (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton) {
                if (root.hasTops) root.closeAllRequested(root.wsId);
            }
        }
    }

    // ── Appear animation (scale from 0) ───────────────────────────────────
    scale: 1.0
    Component.onCompleted: {
        if (!root.reduceMotion) {
            scale = 0.3;
            appearAnim.running = true;
        }
    }
    NumberAnimation {
        id: appearAnim
        target: root
        property: "scale"
        from: 0.3; to: 1.0
        duration: root.reduceMotion ? 0 : Theme.motionBase
        easing.type: Theme.easingEnter
    }
}
