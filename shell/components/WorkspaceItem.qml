import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../theme"
import "../services"

// WorkspaceItem — Single workspace element with 3 visual states:
//   1. Empty (transparent dot)    — faint dot (6px), expands to 22px with number on hover
//   2. Occupied, not active       — circle (28px) with up to 2 overlapping icons, number on hover
//   3. Active workspace           — pill (32px high): number + up to 2 overlapping icons + badge
//
// Style modes: "icons" (default) | "numbers" | "dots"
Item {
    id: root

    // Required from WorkspaceIndicator
    property int    wsId:          1
    property bool   isActive:      false
    property bool   hasTops:       false
    property var    tops:          []        // WlrToplevel[] list
    property string primaryIcon:   ""
    property string secondaryIcon: ""
    property string style:         "icons"
    property bool   reduceMotion:  false

    signal switchRequested(int id)
    signal closeAllRequested(int id)

    // ── Derived state ─────────────────────────────────────────────────────
    // How many icons to show (0-2) — only relevant for "icons" style
    readonly property int shownIcons: {
        if (style !== "icons" || !hasTops) return 0;
        if (primaryIcon.length > 0 && secondaryIcon.length > 0 && tops.length >= 2) return 2;
        if (primaryIcon.length > 0) return 1;
        return 0;
    }
    // Badge count: windows beyond what is shown as icons
    readonly property int badgeCount: style === "icons"
        ? Math.max(0, tops.length - (shownIcons > 0 ? shownIcons : 0))
        : 0

    // ── Dimension helpers ─────────────────────────────────────────────────
    readonly property int dotSz:        Theme.wsDotSize
    readonly property int circSz:       Theme.wsCircleSize
    readonly property int pillH:        Theme.wsPillHeight
    readonly property int ic1Sz:        Theme.wsIconSizeSingle    // 15
    readonly property int ic2Sz:        Theme.wsIconSizeDouble    // 12
    readonly property int icOff:        Theme.wsIconOverlapOffset // 8
    readonly property int emptyHoverSz: 22

    // Active pill width — adapts to shown content
    readonly property int activePillW: {
        if (style === "dots")    return 24;
        if (style === "numbers") return Theme.wsPillBase;
        if (shownIcons === 2)    return Theme.wsPillBase + Theme.wsPillIconGap + ic2Sz + icOff;
        if (shownIcons === 1)    return Theme.wsPillBase + Theme.wsPillIconGap + ic1Sz;
        return Theme.wsPillBase;
    }

    // Shape dimensions based on state
    readonly property int targetW: {
        if (isActive) return activePillW;
        if (style === "numbers") return circSz;
        if (style === "dots") return hasTops ? 10 : dotSz;
        // style === "icons"
        if (hasTops) return circSz;
        return wsMA.containsMouse ? emptyHoverSz : dotSz;
    }

    readonly property int targetH: {
        if (isActive) return pillH;
        if (style === "numbers") return circSz;
        if (style === "dots") return hasTops ? 10 : dotSz;
        // style === "icons"
        if (hasTops) return circSz;
        return wsMA.containsMouse ? emptyHoverSz : dotSz;
    }

    // Fixed row height so the parent RowLayout never jumps
    implicitWidth:  targetW
    implicitHeight: pillH

    // ── Main shape ────────────────────────────────────────────────────────
    Rectangle {
        id: shape
        anchors.centerIn: parent

        width:  targetW
        height: targetH
        radius: height / 2

        Behavior on width  { NumberAnimation { duration: root.reduceMotion ? 0 : Theme.motionBase; easing.type: Theme.easingEnter } }
        Behavior on height { NumberAnimation { duration: root.reduceMotion ? 0 : Theme.motionBase; easing.type: Theme.easingEnter } }
        Behavior on radius { NumberAnimation { duration: root.reduceMotion ? 0 : Theme.motionBase; easing.type: Theme.easingEnter } }

        color: root.isActive
               ? Theme.wsActiveBg
               : (root.hasTops || root.style === "numbers")
                 ? (wsMA.containsMouse ? Theme.notchSurfaceHover : Theme.wsOccupiedBg)
                 : (wsMA.containsMouse ? Theme.notchSurfaceHover : Theme.wsEmptyBg)

        Behavior on color   { ColorAnimation  { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

        opacity: root.isActive ? 1.0
               : root.hasTops ? 1.0
               : root.style === "numbers" ? (root.hasTops ? 1.0 : 0.6)
               : wsMA.containsMouse ? 0.9 : 0.55
        Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }

        // ═══════════════════════════════════════════════════════════
        // ACTIVE PILL: number + up to 2 icons
        // ═══════════════════════════════════════════════════════════
        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: Theme.wsPillIconGap
            visible: root.isActive

            // Number (always in pill, except "dots" style)
            Text {
                text: root.wsId.toString()
                font.family:   Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(13)
                font.weight:   Font.Bold
                color:         Theme.wsActiveText
                renderType:    Theme.renderType
                visible:       root.style !== "dots"
                Layout.alignment: Qt.AlignVCenter
            }

            // Icon area (icons style + hasTops)
            Item {
                id: pillIconArea
                visible: root.style === "icons" && root.shownIcons > 0
                implicitWidth:  root.shownIcons >= 2
                                ? (root.ic2Sz + root.icOff)
                                : root.ic1Sz
                implicitHeight: root.shownIcons >= 2 ? root.ic2Sz : root.ic1Sz
                Layout.alignment: Qt.AlignVCenter

                // Primary icon
                AppIcon {
                    x: 0
                    y: root.shownIcons >= 2
                       ? Math.round((parent.implicitHeight - root.ic2Sz) / 2)
                       : 0
                    iconSize: root.shownIcons >= 2 ? root.ic2Sz : root.ic1Sz
                    source:   root.primaryIcon
                }

                // Secondary icon (overlapping) + separator ring
                Item {
                    x: root.icOff
                    y: Math.round((parent.implicitHeight - root.ic2Sz) / 2)
                    width:   root.ic2Sz
                    height:  root.ic2Sz
                    visible: root.shownIcons >= 2 && root.secondaryIcon.length > 0

                    // Separator ring — matches pill bg
                    Rectangle {
                        anchors.fill:    parent
                        anchors.margins: -1.5
                        radius:          width / 2
                        color:           Theme.wsActiveBg
                        z:               -1
                    }
                    AppIcon {
                        anchors.fill: parent
                        iconSize:     root.ic2Sz
                        source:       root.secondaryIcon
                    }
                }
            }
        } // pillRow

        // ═══════════════════════════════════════════════════════════
        // OCCUPIED CIRCLE: icons only (no number unless hover)
        // ═══════════════════════════════════════════════════════════
        Item {
            id: circleContent
            anchors.centerIn: parent
            visible: !root.isActive && root.hasTops && root.style === "icons"

            // Width is the icon-cluster width, centred inside circle
            implicitWidth: root.shownIcons >= 2 ? (root.ic2Sz + root.icOff) : root.ic1Sz
            implicitHeight: root.shownIcons >= 2 ? root.ic2Sz : root.ic1Sz
            width:  implicitWidth
            height: implicitHeight

            // Primary icon
            AppIcon {
                x: 0
                y: root.shownIcons >= 2 ? Math.round((parent.height - root.ic2Sz) / 2) : 0
                iconSize: root.shownIcons >= 2 ? root.ic2Sz : root.ic1Sz
                source:   root.primaryIcon
                visible:  root.primaryIcon.length > 0
            }

            // Secondary icon + separator ring
            Item {
                x: root.icOff
                y: Math.round((parent.height - root.ic2Sz) / 2)
                width:   root.ic2Sz
                height:  root.ic2Sz
                visible: root.shownIcons >= 2 && root.secondaryIcon.length > 0

                Rectangle {
                    anchors.fill:    parent
                    anchors.margins: -1.5
                    radius:          width / 2
                    color:           Theme.wsOccupiedBg
                    z:               -1
                }
                AppIcon {
                    anchors.fill: parent
                    iconSize:     root.ic2Sz
                    source:       root.secondaryIcon
                }
            }
        } // circleContent

        // ── Hover: workspace number overlay for occupied circle (icons mode) ───
        Rectangle {
            id: hoverCircleOverlay
            anchors.fill: parent
            radius: height / 2
            color: Theme.notchSurfaceActive
            border.color: Theme.notchBorderHighlight
            border.width: 1
            z: 4
            visible: !root.isActive && root.hasTops
                     && root.style === "icons"
                     && wsMA.containsMouse

            Text {
                anchors.centerIn: parent
                text: root.wsId.toString()
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(12)
                font.weight: Font.Bold
                color: Theme.notchText
                renderType: Theme.renderType
            }
        }

        // ── Empty dot — hover number (icons mode) ─────────────────────────
        Text {
            anchors.centerIn: parent
            visible: !root.isActive && !root.hasTops
                     && wsMA.containsMouse
                     && root.style === "icons"
            text:    root.wsId.toString()
            font.family:    Theme.typography.fontFamily
            font.pixelSize: Theme.fontSize(11)
            font.weight:    Font.Bold
            color:          Theme.notchText
            renderType:     Theme.renderType
        }

        // ── Numbers mode: number always visible for all inactive workspaces ─
        Text {
            anchors.centerIn: parent
            visible: !root.isActive && root.style === "numbers"
            text:    root.wsId.toString()
            font.family:    Theme.typography.fontFamily
            font.pixelSize: Theme.fontSize(11)
            font.weight:    root.hasTops ? Font.DemiBold : Font.Normal
            color:          root.hasTops ? Theme.notchText : Theme.notchTextTertiary
            renderType:     Theme.renderType
        }

        // ── Badge "+N" for extra windows beyond shown icons ───────────────
        Rectangle {
            id: badge
            visible: root.hasTops && root.badgeCount > 0 && root.style === "icons" && !wsMA.containsMouse
            width:   badgeLabel.implicitWidth + 5
            height:  Theme.wsBadgeSize
            radius:  Theme.wsBadgeSize / 2
            color:   Theme.notchBackground
            border.color: Theme.notchBorder
            border.width: 1
            anchors {
                right:       shape.right;  rightMargin: -2
                top:         shape.top;    topMargin:   -2
            }
            z: 5

            Text {
                id: badgeLabel
                anchors.centerIn: parent
                text:    "+" + root.badgeCount
                font.family:    Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(7)
                font.weight:    Font.Bold
                color:          Theme.notchTextSecondary
                renderType:     Theme.renderType
            }
        }

    } // shape

    // ── Mouse area ────────────────────────────────────────────────────────
    MouseArea {
        id: wsMA
        anchors.fill:    parent
        anchors.margins: (root.hasTops || root.isActive || wsMA.containsMouse) ? 0 : -6
        hoverEnabled:    true
        cursorShape:     Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                root.switchRequested(root.wsId);
            } else if (root.hasTops) {
                root.closeAllRequested(root.wsId);
            }
        }
    }

    // ── Appear scale animation ────────────────────────────────────────────
    scale: 1.0
    Component.onCompleted: {
        if (!root.reduceMotion) { scale = 0.3; appearAnim.running = true; }
    }
    NumberAnimation {
        id: appearAnim
        target: root; property: "scale"
        from: 0.3; to: 1.0
        duration: root.reduceMotion ? 0 : Theme.motionBase
        easing.type: Theme.easingEnter
    }
}
