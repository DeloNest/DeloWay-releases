import QtQuick
import QtQuick.Shapes
import "../../theme"

// RingGauge — 270° monochrome arc gauge with the value centred inside.
// Hierarchy is pure luminance: a faint track and a solid high-contrast arc.
Item {
    id: root

    property real value: 0              // 0..1
    property bool hasValue: true
    property string centerText: hasValue ? Math.round(value * 100) + "%" : "—"
    property real stroke: 5

    implicitWidth: 56
    implicitHeight: 56

    readonly property real clamped: Math.max(0, Math.min(1, value))
    property real shown: hasValue ? clamped : 0
    property bool animate: true         // false while off screen: jump instead of animating
    Behavior on shown { enabled: root.animate; NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

    readonly property real arcStart: 135
    readonly property real arcSweep: 270
    readonly property real r: Math.min(width, height) / 2 - stroke / 2

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // Track
        ShapePath {
            strokeColor: Theme.notchSurfaceHover
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2; centerY: root.height / 2
                radiusX: root.r; radiusY: root.r
                startAngle: root.arcStart; sweepAngle: root.arcSweep
            }
        }

        // Value
        ShapePath {
            strokeColor: root.shown > 0.004 ? Theme.notchText : "transparent"
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2; centerY: root.height / 2
                radiusX: root.r; radiusY: root.r
                startAngle: root.arcStart; sweepAngle: Math.max(0.5, root.arcSweep * root.shown)
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.centerText
        font.family: Theme.typography.fontFamily
        font.pixelSize: Theme.fontSize(13)
        font.weight: Font.Bold
        color: Theme.notchText
        renderType: Theme.renderType
    }
}
