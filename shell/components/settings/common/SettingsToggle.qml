import QtQuick
import "../../../theme"
import "../../../services"

Item {
    id: root

    property bool checked: false
    property color onColor: Theme.colors.accent
    property color offColor: Theme.notchSurfaceElevated
    property color knobColor: "#ffffff"
    signal toggled(bool checked)

    implicitWidth: 44
    implicitHeight: 24

    opacity: root.enabled ? 1.0 : 0.4
    Behavior on opacity {
        NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter }
    }

    // Pill Track Container
    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? root.onColor : root.offColor
        border.color: root.checked ? root.onColor : Theme.notchBorder
        border.width: 1

        Behavior on color {
            ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter }
        }
        Behavior on border.color {
            ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter }
        }

        // Sliding Knob
        Rectangle {
            id: knob
            readonly property real knobMargin: 3
            readonly property real knobSize: parent.height - (knobMargin * 2)

            width: knobSize
            height: knobSize
            radius: knobSize / 2
            color: root.knobColor
            anchors.verticalCenter: parent.verticalCenter

            readonly property real targetX: {
                if (I18n.isRTL) {
                    return root.checked ? knobMargin : (parent.width - knobSize - knobMargin);
                } else {
                    return root.checked ? (parent.width - knobSize - knobMargin) : knobMargin;
                }
            }

            x: targetX

            Behavior on x {
                NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.enabled
            cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                root.checked = !root.checked;
                root.toggled(root.checked);
            }
        }
    }
}
