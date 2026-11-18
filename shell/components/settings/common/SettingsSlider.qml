import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../services"

// SettingsSlider — Clean, minimalist slider control for Settings app rows.
// Supports drag, click-to-seek, mouse wheel, RTL layout mirroring, and percentage label.
RowLayout {
    id: root

    property real value: 0.0          // 0.0 .. 1.0
    property real from: 0.0
    property real to: 1.0
    property real stepSize: 0.01
    property bool showValueLabel: true
    property string valueSuffix: "%"
    property int valuePrecision: 0
    property bool enabledControl: true

    signal moved(real value)

    spacing: Theme.space8
    opacity: enabledControl ? 1.0 : 0.4
    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    readonly property real normalizedValue: Math.max(0.0, Math.min(1.0, (root.value - root.from) / Math.max(0.001, (root.to - root.from))))
    property bool dragging: false
    property real dragNormalized: 0.0
    readonly property real activeNormalized: dragging ? dragNormalized : normalizedValue

    // Track container
    Rectangle {
        id: track
        Layout.fillWidth: true
        Layout.minimumWidth: 120
        Layout.preferredWidth: 160
        implicitHeight: 20
        radius: 10
        color: Theme.notchSurfaceActive
        border.color: trackMa.containsMouse || root.dragging ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
        border.width: 1

        Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

        // Filled active track
        Rectangle {
            id: fill
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: I18n.isRTL ? undefined : parent.left
            anchors.right: I18n.isRTL ? parent.right : undefined
            anchors.margins: 2
            width: Math.max(16, (parent.width - 4) * root.activeNormalized)
            radius: 8
            color: Theme.inverseSurface

            Behavior on width {
                enabled: !root.dragging
                NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter }
            }
        }

        MouseArea {
            id: trackMa
            anchors.fill: parent
            hoverEnabled: root.enabledControl
            cursorShape: root.enabledControl ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: root.enabledControl

            function updateFromMouse(mouseX) {
                var pos = Math.max(0, Math.min(track.width, mouseX));
                var fraction = pos / Math.max(1, track.width);
                if (I18n.isRTL) {
                    fraction = 1.0 - fraction;
                }
                var val = root.from + fraction * (root.to - root.from);
                if (root.stepSize > 0) {
                    val = Math.round(val / root.stepSize) * root.stepSize;
                }
                val = Math.max(root.from, Math.min(root.to, val));
                root.dragNormalized = Math.max(0.0, Math.min(1.0, (val - root.from) / Math.max(0.001, (root.to - root.from))));
                root.moved(val);
            }

            onPressed: (mouse) => {
                root.dragging = true;
                updateFromMouse(mouse.x);
            }

            onPositionChanged: (mouse) => {
                if (root.dragging) {
                    updateFromMouse(mouse.x);
                }
            }

            onReleased: {
                root.dragging = false;
            }

            onWheel: (wheel) => {
                var delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                var currentVal = root.value + delta * (root.to - root.from);
                currentVal = Math.max(root.from, Math.min(root.to, currentVal));
                root.moved(currentVal);
            }
        }
    }

    // Value percentage text
    Text {
        visible: root.showValueLabel
        Layout.minimumWidth: Math.round(34 * Math.max(1.0, Theme.fontScale))
        horizontalAlignment: Text.AlignHCenter
        text: Math.round(root.value * 100) + root.valueSuffix
        font.family: Theme.typography.fontFamily
        font.pixelSize: Theme.fontSize(11)
        font.weight: Font.DemiBold
        color: Theme.notchTextSecondary
        renderType: Theme.renderType
    }
}
