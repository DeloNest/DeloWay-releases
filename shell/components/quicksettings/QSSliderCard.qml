import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services"
import ".."

Rectangle {
    id: root

    property string title: ""
    property string icon: ""
    property color iconColor: Theme.notchText
    property bool iconClickable: false
    property string valueText: ""
    property real value: 0.0
    property bool isMuted: false

    signal sliderMoved(real newValue)
    signal sliderReleased()
    signal iconClicked()

    Layout.fillWidth: true
    Layout.preferredHeight: 60
    radius: Theme.notchRadiusCard
    color: (sliderMa.containsMouse || iconMa.containsMouse) ? Theme.notchSurfaceHover : Theme.notchSurfaceElevated
    border.color: Theme.notchBorderSubtle
    border.width: 1
    clip: true

    Behavior on color { ColorAnimation { duration: 100 } }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        spacing: 6

        // Top Header Row: Icon + Title + Spacer + Value
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Item {
                implicitWidth: 16
                implicitHeight: 16
                Layout.alignment: Qt.AlignVCenter

                SymbolicIcon {
                    anchors.centerIn: parent
                    source: root.icon
                    iconSize: 14
                    iconColor: root.iconColor
                }

                MouseArea {
                    id: iconMa
                    anchors.fill: parent
                    enabled: root.iconClickable
                    cursorShape: root.iconClickable ? Qt.PointingHandCursor : Qt.ArrowCursor
                    hoverEnabled: true
                    onClicked: root.iconClicked()
                }
            }

            Text {
                text: root.title
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(11)
                font.weight: Font.DemiBold
                color: Theme.notchText
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.valueText
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(10)
                font.weight: Font.Medium
                color: root.isMuted ? Theme.notchTextTertiary : Theme.notchTextSecondary
            }
        }

        // Slider Track & Thumb (LTR layout math)
        Item {
            id: sliderContainer
            Layout.fillWidth: true
            Layout.preferredHeight: 16
            LayoutMirroring.enabled: false
            LayoutMirroring.childrenInherit: true

            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                height: 6
                radius: 3
                color: Theme.sliderTrack

                Rectangle {
                    id: fill
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    width: parent.width * Math.max(0, Math.min(1, root.isMuted ? 0 : root.value))
                    radius: 3
                    color: Theme.sliderFill
                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                    Behavior on width {
                        enabled: !sliderMa.pressed
                        NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                    }
                }

                Rectangle {
                    id: thumb
                    width: 14
                    height: 14
                    radius: 7
                    color: Theme.sliderThumb
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(0, Math.min(parent.width - width, parent.width * (root.isMuted ? 0 : root.value) - width / 2))
                    border.color: Qt.rgba(0, 0, 0, 0.20)
                    border.width: 1
                    scale: sliderMa.pressed ? 1.25 : (sliderMa.containsMouse ? 1.15 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                    Behavior on x {
                        enabled: !sliderMa.pressed
                        NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                    }
                }
            }

            MouseArea {
                id: sliderMa
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                function updateVal(mouse) {
                    const raw = Math.max(0, Math.min(1, mouse.x / width));
                    root.sliderMoved(raw);
                }

                onPressed: mouse => updateVal(mouse)
                onPositionChanged: mouse => {
                    if (pressed) updateVal(mouse);
                }
                onReleased: root.sliderReleased()
                onCanceled: root.sliderReleased()
                onWheel: (wheel) => {
                    wheel.accepted = true;
                    const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                    const nextVal = Math.max(0, Math.min(1, root.value + delta));
                    root.sliderMoved(nextVal);
                    root.sliderReleased();
                }
            }
        }
    }
}
