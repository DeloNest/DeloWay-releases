import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services"
import ".."

// QSSlider — [mute/icon button] [ track ········ 62% ] [›]
// • Fill grows from the reading-start edge (right in Arabic) — the track mirrors.
// • Drag, click-to-seek, or wheel (±5%). Value text uses tabular digits (no jitter).
// • Local `dragValue` keeps the thumb glued to the pointer while the backend catches up.
Item {
    id: root

    property real value: 0            // 0..1
    property string iconName: ""
    property bool muted: false
    property bool enabledControl: true
    property bool hasDetails: false
    property string label: ""         // accessible name, shown when hovering the icon

    signal moved(real value)
    signal iconClicked()
    signal detailsRequested()

    implicitHeight: 36
    opacity: enabledControl ? 1 : 0.45

    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    property bool dragging: false
    property real dragValue: 0
    readonly property real shown: dragging ? dragValue : Math.max(0, Math.min(1, value))
    property real animated: shown
    Behavior on animated { enabled: !root.dragging; NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }

    RowLayout {
        anchors.fill: parent
        spacing: 8

        // Icon button (mute toggle)
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 36
            implicitHeight: 36
            radius: 18
            color: root.muted ? Theme.qsTileActive
                   : (iconMa.containsMouse ? Theme.qsTileBackgroundHover : Theme.qsTileBackground)
            border.color: root.muted ? "transparent" : Theme.qsTileBorder
            border.width: 1
            Behavior on color { ColorAnimation { duration: Theme.motionFast } }

            SymbolicIcon {
                anchors.centerIn: parent
                iconSize: 16
                source: root.iconName
                iconColor: root.muted ? Theme.qsTileIconActive : Theme.notchText
            }
            MouseArea {
                id: iconMa
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.enabledControl
                cursorShape: Qt.PointingHandCursor
                onClicked: root.iconClicked()
            }
        }

        // Track
        Rectangle {
            id: track
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            implicitHeight: 30
            radius: 15
            color: trackMa.containsMouse || root.dragging ? Theme.qsSliderTrackHover : Theme.qsSliderTrack
            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
            clip: true

            // Fill: anchored to the reading-start edge
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(height, Math.round(track.width * root.animated))
                radius: track.radius
                color: Theme.qsSliderFill
                opacity: root.muted ? 0.35 : 1
                Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }

                // Thumb dot at the fill's leading edge
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18; height: 18; radius: 9
                    color: Theme.qsSliderIconActive
                    opacity: 0.18
                }
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(root.shown * 100) + "%"
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(10)
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                // Readable over both the empty track and the fill
                color: root.animated > 0.86 ? Theme.qsSliderIconActive : Theme.notchTextSecondary
                renderType: Theme.renderType
            }

            MouseArea {
                id: trackMa
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.enabledControl
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                function valueAt(mx) {
                    const f = Math.max(0, Math.min(1, mx / track.width));
                    return I18n.isRTL ? 1 - f : f;
                }
                onPressed: (m) => {
                    root.dragging = true;
                    root.dragValue = valueAt(m.x);
                    root.moved(root.dragValue);
                }
                onPositionChanged: (m) => {
                    if (!pressed) return;
                    root.dragValue = valueAt(m.x);
                    root.moved(root.dragValue);
                }
                onReleased: root.dragging = false
                onCanceled: root.dragging = false
                onWheel: (w) => {
                    const step = w.angleDelta.y > 0 ? 0.05 : -0.05;
                    root.moved(Math.max(0, Math.min(1, root.value + step)));
                }
            }
        }

        // Details chevron (output devices…)
        Rectangle {
            visible: root.hasDetails
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 30
            implicitHeight: 30
            radius: 15
            color: detMa.containsMouse ? Theme.qsTileBackgroundHover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.motionFast } }

            SymbolicIcon {
                anchors.centerIn: parent
                iconSize: 13
                source: I18n.isRTL ? "go-previous-symbolic" : "go-next-symbolic"
                iconColor: Theme.notchTextSecondary
            }
            MouseArea {
                id: detMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.detailsRequested()
            }
        }
    }
}
