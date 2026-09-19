import QtQuick
import QtQuick.Shapes
import "../theme"
import "../services"

Item {
    id: root

    property bool isExpanded: false
    property real currentWidth: 200
    property real currentHeight: 44
    property real earRadius: 18
    property real bottomRadius: 26
    property bool clipContent: true

    readonly property alias body: notchBody
    default property alias content: bodyContent.data

    implicitWidth: Math.round(currentWidth + (isExpanded ? earRadius * 2 : 0))
    implicitHeight: Math.round(currentHeight + 8)

    // ──────────────────────────────────────────────────────────────────────
    // SOFT AMBIENT DROP SHADOW (macOS card depth)
    // ──────────────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: notchBody
        anchors.topMargin: 6
        anchors.bottomMargin: -6
        anchors.leftMargin: -2
        anchors.rightMargin: -2
        radius: root.bottomRadius + 2
        color: Qt.rgba(0, 0, 0, 0.40)
        visible: root.isExpanded
        z: 0
    }

    // ──────────────────────────────────────────────────────────────────────
    // TOP CONCAVE FILLET EARS (macOS camera notch seamless integration)
    // ──────────────────────────────────────────────────────────────────────
    // Left Ear
    Shape {
        anchors.top: notchBody.top
        anchors.right: notchBody.left
        width: root.isExpanded ? root.earRadius : 0
        height: root.earRadius
        visible: width > 0
        z: 1

        ShapePath {
            fillColor: Theme.notchBackground
            strokeColor: "transparent"
            startX: 0
            startY: 0
            PathLine { x: root.earRadius; y: 0 }
            PathLine { x: root.earRadius; y: root.earRadius }
            PathArc {
                x: 0
                y: 0
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Counterclockwise
            }
        }
    }

    // Right Ear
    Shape {
        anchors.top: notchBody.top
        anchors.left: notchBody.right
        width: root.isExpanded ? root.earRadius : 0
        height: root.earRadius
        visible: width > 0
        z: 1

        ShapePath {
            fillColor: Theme.notchBackground
            strokeColor: "transparent"
            startX: 0
            startY: 0
            PathLine { x: root.earRadius; y: 0 }
            PathArc {
                x: 0
                y: root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Counterclockwise
            }
            PathLine { x: 0; y: 0 }
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // MAIN NOTCH BODY (Pure solid deep black, macOS Retina/OLED feel)
    // ──────────────────────────────────────────────────────────────────────
    Rectangle {
        id: notchBody
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.currentWidth
        height: root.currentHeight
        color: Theme.notchBackground
        border.color: Theme.notchBorderSubtle
        border.width: Theme.isDark ? 0 : 1
        clip: root.clipContent
        z: 2

        topLeftRadius: root.isExpanded ? 0 : (height / 2)
        topRightRadius: root.isExpanded ? 0 : (height / 2)
        bottomLeftRadius: root.isExpanded ? root.bottomRadius : (height / 2)
        bottomRightRadius: root.isExpanded ? root.bottomRadius : (height / 2)

        Behavior on topLeftRadius { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
        Behavior on topRightRadius { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
        Behavior on bottomLeftRadius { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
        Behavior on bottomRightRadius { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }

        Item {
            id: bodyContent
            anchors.fill: parent
            LayoutMirroring.enabled: I18n.isRTL
            LayoutMirroring.childrenInherit: true
        }
    }
}
