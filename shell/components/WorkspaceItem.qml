import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../theme"
import "../services"

// WorkspaceItem — one workspace in the collapsed Notch.
//
//   Empty     ·   7px dot in a fixed 12px slot. NO hover response at all (click still
//                 switches). Its size never changes → the Notch can't jitter.
//   Occupied  ◯   30px circle with up to 2 app icons. Hover: gentle scale-up (transform),
//                 lifted surface, icons cross-fade to the workspace number.
//   Active    ⬭   32px pill: number + up to 2 icons. Hover: subtle tonal shift only.
//
// Layout contract: implicitWidth depends ONLY on (style, isActive, hasTops, icon count) —
// never on hover. Every hover effect is a transform, colour or opacity change, none of
// which participate in layout. Pill width changes only on real state changes
// (workspace switch / windows opened) and animates smoothly.
Item {
    id: root

    // Required from WorkspaceIndicator
    property int    wsId:          1
    property bool   isActive:      false
    property bool   hasTops:       false
    property var    tops:          []
    property string primaryIcon:   ""
    property string secondaryIcon: ""
    property string style:         "icons"          // "icons" | "numbers" | "dots"
    property bool   reduceMotion:  false

    signal switchRequested(int id)
    signal closeAllRequested(int id)

    // ── Derived state ─────────────────────────────────────────────────────
    readonly property bool isEmpty: !isActive && !hasTops
    // Hover is meaningful only for active / occupied workspaces.
    readonly property bool hovered: wsMA.containsMouse && !isEmpty

    readonly property int shownIcons: {
        if (style !== "icons" || !hasTops) return 0;
        if (primaryIcon.length > 0 && secondaryIcon.length > 0 && tops.length >= 2) return 2;
        if (primaryIcon.length > 0) return 1;
        return 0;
    }
    readonly property int badgeCount: style === "icons" ? Math.max(0, tops.length - shownIcons) : 0

    readonly property int ic1Sz: Theme.wsIconSizeSingle
    readonly property int ic2Sz: Theme.wsIconSizeDouble
    readonly property int icOff: Theme.wsIconOverlapOffset
    readonly property int clusterW: shownIcons >= 2 ? (ic2Sz + icOff) : (shownIcons === 1 ? ic1Sz : 0)
    readonly property int clusterH: shownIcons >= 2 ? ic2Sz : ic1Sz

    readonly property int activePillW: {
        if (style === "dots") return 26;
        if (style === "numbers" || shownIcons === 0) return Theme.wsPillBase;
        return 12 + numberMetrics.advanceWidth + Theme.wsPillIconGap + clusterW + 12;
    }

    // Slot size — the ONLY thing the row layout sees.
    readonly property int slotW: {
        if (isActive) return activePillW;
        if (style === "numbers") return Theme.wsCircleSize;
        if (style === "dots") return hasTops ? 12 : Theme.wsEmptySlot;
        return hasTops ? Theme.wsCircleSize : Theme.wsEmptySlot;
    }
    readonly property int shapeW: {
        if (isActive) return activePillW;
        if (style === "numbers") return Theme.wsCircleSize;
        if (style === "dots") return hasTops ? 10 : Theme.wsDotSize;
        return hasTops ? Theme.wsCircleSize : Theme.wsDotSize;
    }
    readonly property int shapeH: {
        if (isActive) return Theme.wsPillHeight;
        if (style === "numbers") return Theme.wsCircleSize;
        if (style === "dots") return hasTops ? 10 : Theme.wsDotSize;
        return hasTops ? Theme.wsCircleSize : Theme.wsDotSize;
    }

    implicitWidth: slotW
    implicitHeight: Theme.wsPillHeight          // constant row height
    Behavior on implicitWidth {
        enabled: !root.reduceMotion
        NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter }
    }

    TextMetrics {
        id: numberMetrics
        font.family: Theme.typography.fontFamily
        font.pixelSize: Theme.fontSize(14)
        font.weight: Font.Bold
        text: root.wsId.toString()
    }

    // ── Shape ─────────────────────────────────────────────────────────────
    Rectangle {
        id: shape
        anchors.centerIn: parent
        width: root.shapeW
        height: root.shapeH
        radius: height / 2
        antialiasing: true

        Behavior on width  { enabled: !root.reduceMotion; NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
        Behavior on height { enabled: !root.reduceMotion; NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }

        color: root.isActive ? Theme.wsActiveBg
             : root.hasTops  ? (root.hovered ? Theme.notchSurfaceActive : Theme.wsOccupiedBg)
             : Theme.wsEmptyBg
        Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

        // Hover lift for occupied circles — a transform, so the row never moves.
        scale: (root.hovered && !root.isActive) ? 1.07 : 1.0
        Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic } }

        // Active pill hover: tonal veil (works in both themes: veil uses the pill's text colour)
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: root.isActive
            color: Theme.wsActiveText
            opacity: root.hovered ? 0.08 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }
        }

        // ── Active pill content: number + icon cluster ───────────────────
        Row {
            anchors.centerIn: parent
            spacing: Theme.wsPillIconGap
            visible: root.isActive
            LayoutMirroring.enabled: false

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.style !== "dots"
                text: root.wsId.toString()
                font: numberMetrics.font
                color: Theme.wsActiveText
                renderType: Theme.renderType
            }
            IconCluster {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.style === "icons" && root.shownIcons > 0
                ringColor: Theme.wsActiveBg
            }
        }

        // ── Occupied circle: icons ⇄ number cross-fade on hover ──────────
        IconCluster {
            anchors.centerIn: parent
            visible: !root.isActive && root.hasTops && root.style === "icons"
            ringColor: shape.color
            opacity: root.hovered ? 0 : 1
            scale: root.hovered ? 0.85 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }
            Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic } }
        }
        Text {
            anchors.centerIn: parent
            visible: !root.isActive && root.hasTops && root.style === "icons"
            text: root.wsId.toString()
            font.family: Theme.typography.fontFamily
            font.pixelSize: Theme.fontSize(14)
            font.weight: Font.Bold
            color: Theme.notchText
            renderType: Theme.renderType
            opacity: root.hovered ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }
        }

        // ── Numbers style: number always visible on inactive workspaces ──
        Text {
            anchors.centerIn: parent
            visible: !root.isActive && root.style === "numbers"
            text: root.wsId.toString()
            font.family: Theme.typography.fontFamily
            font.pixelSize: Theme.fontSize(12)
            font.weight: root.hasTops ? Font.Bold : Font.Medium
            color: root.hasTops ? Theme.notchText : Theme.notchTextTertiary
            renderType: Theme.renderType
        }

        // ── "+N" badge for windows beyond the shown icons ────────────────
        Rectangle {
            visible: root.style === "icons" && root.hasTops && root.badgeCount > 0
            width: Math.max(Theme.wsBadgeSize, badgeLabel.implicitWidth + 6)
            height: Theme.wsBadgeSize
            radius: height / 2
            color: Theme.notchBackground
            border.color: Theme.notchBorderHighlight
            border.width: 1
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: -3
            anchors.topMargin: -3
            opacity: root.hovered ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }

            Text {
                id: badgeLabel
                anchors.centerIn: parent
                text: "+" + root.badgeCount
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(8)
                font.weight: Font.Bold
                color: Theme.notchText
                renderType: Theme.renderType
            }
        }
    }

    // ── Icon cluster (1 icon, or 2 overlapping with a separator ring) ─────
    component IconCluster: Item {
        id: cluster
        property color ringColor: "transparent"
        width: root.clusterW
        height: root.clusterH

        AppIcon {
            x: 0
            y: Math.round((cluster.height - iconSize) / 2)
            iconSize: root.shownIcons >= 2 ? root.ic2Sz : root.ic1Sz
            source: root.primaryIcon
            visible: root.primaryIcon.length > 0
        }
        Item {
            x: root.icOff
            width: root.ic2Sz
            height: root.ic2Sz
            visible: root.shownIcons >= 2 && root.secondaryIcon.length > 0

            Rectangle {
                anchors.fill: parent
                anchors.margins: -2
                radius: width / 2
                color: cluster.ringColor
            }
            AppIcon {
                anchors.fill: parent
                iconSize: root.ic2Sz
                source: root.secondaryIcon
            }
        }
    }

    // ── Input ─────────────────────────────────────────────────────────────
    // Constant geometry (no hover-dependent margins → no enter/leave flicker loop).
    // Extends half the row spacing on each side so small dots are easy to click
    // without ever overlapping a neighbour's target.
    MouseArea {
        id: wsMA
        anchors.fill: parent
        anchors.leftMargin: -Math.floor(Theme.wsIndicatorSpacing / 2)
        anchors.rightMargin: -Math.floor(Theme.wsIndicatorSpacing / 2)
        hoverEnabled: !root.isEmpty
        cursorShape: root.isEmpty ? Qt.ArrowCursor : Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) root.switchRequested(root.wsId);
            else if (root.hasTops) root.closeAllRequested(root.wsId);
        }
    }

    // ── Appear animation (new extra workspaces) ──────────────────────────
    opacity: 1
    Component.onCompleted: if (!root.reduceMotion) appearAnim.running = true
    ParallelAnimation {
        id: appearAnim
        NumberAnimation { target: root; property: "opacity"; from: 0; to: 1; duration: Theme.motionBase; easing.type: Theme.easingEnter }
        // Animates the item, not `shape`: shape.scale is bound to hover and an animation
        // would overwrite (break) that binding.
        NumberAnimation { target: root; property: "scale"; from: 0.6; to: 1; duration: Theme.motionBase; easing.type: Theme.easingEnter }
    }
}
