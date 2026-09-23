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
        color: Theme.notchShadow            // theme-aware (was a fixed 40% black)
        visible: root.isExpanded && Theme.enableShadows
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
    // LIGHT-MODE OUTLINE (attached state)
    // One continuous stroke: left ear arc → left side → bottom → right side → right ear
    // arc. Never along the screen edge, and no seam where the ears meet the body — a
    // plain rectangle border drew both, which read as black lines/corners in light mode.
    // ──────────────────────────────────────────────────────────────────────
    Shape {
        id: attachedOutline
        visible: root.isExpanded && !Theme.isDark
        opacity: 1
        z: 3
        preferredRendererType: Shape.CurveRenderer
        readonly property real er: root.earRadius
        readonly property real bx: notchBody.x
        readonly property real bw: notchBody.width
        readonly property real bh: notchBody.height
        readonly property real br: root.bottomRadius

        ShapePath {
            strokeColor: Theme.notchBorder
            strokeWidth: 1
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            startX: attachedOutline.bx - attachedOutline.er
            startY: 0.5
            PathArc {
                x: attachedOutline.bx + 0.5; y: attachedOutline.er
                radiusX: attachedOutline.er; radiusY: attachedOutline.er
                direction: PathArc.Clockwise
            }
            PathLine { x: attachedOutline.bx + 0.5; y: attachedOutline.bh - attachedOutline.br }
            PathArc {
                x: attachedOutline.bx + attachedOutline.br; y: attachedOutline.bh - 0.5
                radiusX: attachedOutline.br; radiusY: attachedOutline.br
                direction: PathArc.Counterclockwise
            }
            PathLine { x: attachedOutline.bx + attachedOutline.bw - attachedOutline.br; y: attachedOutline.bh - 0.5 }
            PathArc {
                x: attachedOutline.bx + attachedOutline.bw - 0.5; y: attachedOutline.bh - attachedOutline.br
                radiusX: attachedOutline.br; radiusY: attachedOutline.br
                direction: PathArc.Counterclockwise
            }
            PathLine { x: attachedOutline.bx + attachedOutline.bw - 0.5; y: attachedOutline.er }
            PathArc {
                x: attachedOutline.bx + attachedOutline.bw + attachedOutline.er; y: 0.5
                radiusX: attachedOutline.er; radiusY: attachedOutline.er
                direction: PathArc.Clockwise
            }
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
        // Full border only for the floating pill; attached state uses attachedOutline.
        border.width: (!Theme.isDark && !root.isExpanded) ? 1 : 0
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
