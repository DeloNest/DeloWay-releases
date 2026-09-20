import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services"
import ".."

Rectangle {
    id: root

    property string title: ""
    property string icon: ""
    property bool iconClickable: false
    property real value: 0.0
    property bool isMuted: false
    property bool hasSubpage: false

    signal sliderMoved(real newValue)
    signal sliderReleased()
    signal iconClicked()
    signal subpageRequested()

    Layout.fillWidth: true
    Layout.preferredHeight: Theme.qsSliderCardHeight
    implicitHeight: Theme.qsSliderCardHeight
    radius: Theme.qsCardRadius
    color: cardMa.containsMouse ? Theme.qsTileBackgroundHover : Theme.qsTileBackground
    border.color: Theme.qsTileBorder
    border.width: 1
    clip: false

    Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

    MouseArea {
        id: cardMa
        anchors.fill: parent
        hoverEnabled: true
        onWheel: (wheel) => {
            wheel.accepted = true;
            const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
            const nextVal = Math.max(0, Math.min(1, root.value + delta));
            root.sliderMoved(nextVal);
            root.sliderReleased();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 10
        anchors.bottomMargin: 12
        spacing: 6

        // Top Header Row: Title + % (on drag) + Chevron
        RowLayout {
            Layout.fillWidth: true
            LayoutMirroring.enabled: I18n.isRTL
            LayoutMirroring.childrenInherit: true

            Text {
                text: root.title
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(13)
                font.weight: Font.DemiBold
                color: Theme.notchText
                renderType: Theme.renderType
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.isMuted
                      ? (I18n.isRTL ? "مكتوم" : "Muted")
                      : (Math.round(root.value * 100) + "%")
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(11)
                font.weight: Font.DemiBold
                color: root.isMuted ? Theme.colors.danger : Theme.notchText
                opacity: (sliderMa.pressed || sliderMa.containsMouse) ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }
                renderType: Theme.renderType
            }

            Item {
                visible: root.hasSubpage
                implicitWidth: 20
                implicitHeight: 20

                Text {
                    anchors.centerIn: parent
                    text: I18n.isRTL ? "‹" : "›"
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(14)
                    font.weight: Font.Bold
                    color: chevronMa.containsMouse ? Theme.notchText : Theme.notchTextTertiary
                    renderType: Theme.renderType
                }

                MouseArea {
                    id: chevronMa
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: (mouse) => {
                        mouse.accepted = true;
                        root.subpageRequested();
                    }
                }
            }
        }

        // Thick Pill Track (~32px)
        Item {
            id: sliderContainer
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.qsSliderTrackHeight
            implicitHeight: Theme.qsSliderTrackHeight

            // Track background
            Rectangle {
                id: track
                anchors.fill: parent
                radius: Theme.qsSliderTrackRadius
                color: sliderMa.containsMouse ? Theme.qsSliderTrackHover : Theme.qsSliderTrack
                clip: true

                // Accent fill pill
                Rectangle {
                    id: fill
                    height: track.height
                    radius: Theme.qsSliderTrackRadius
                    color: root.isMuted ? Theme.colors.danger : Theme.qsSliderFill

                    x: I18n.isRTL ? (track.width - width) : 0
                    width: {
                        const v = root.isMuted ? 0 : Math.max(0, Math.min(1, root.value));
                        if (v <= 0) return 0;
                        return Math.max(track.height, track.width * v);
                    }

                    Behavior on width {
                        enabled: !sliderMa.pressed
                        NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                    }
                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                }

                // Drag thumb indicator (visible only when dragging)
                Rectangle {
                    width: 4
                    height: 18
                    radius: 2
                    color: Theme.notchText
                    anchors.verticalCenter: parent.verticalCenter
                    x: {
                        const v = root.isMuted ? 0 : Math.max(0, Math.min(1, root.value));
                        if (I18n.isRTL) {
                            return Math.max(0, Math.min(track.width - width, track.width - (track.width * v) - width / 2));
                        } else {
                            return Math.max(0, Math.min(track.width - width, track.width * v - width / 2));
                        }
                    }
                    opacity: sliderMa.pressed ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 80 } }
                }
            }

            // Clickable icon inside start of track
            Item {
                id: iconArea
                width: 32
                height: 32
                anchors.verticalCenter: parent.verticalCenter
                x: I18n.isRTL ? (parent.width - width - 8) : 8

                SymbolicIcon {
                    anchors.centerIn: parent
                    source: root.icon
                    iconSize: 18
                    iconColor: {
                        if (root.isMuted) return Theme.colors.danger;
                        const v = Math.max(0, Math.min(1, root.value));
                        if (v > 0.08) {
                            return Theme.qsSliderIconActive;
                        }
                        return Theme.qsSliderIconInactive;
                    }
                }

                MouseArea {
                    id: iconMa
                    anchors.fill: parent
                    anchors.margins: -4
                    enabled: root.iconClickable
                    cursorShape: root.iconClickable ? Qt.PointingHandCursor : Qt.ArrowCursor
                    hoverEnabled: true
                    onClicked: (mouse) => {
                        mouse.accepted = true;
                        root.iconClicked();
                    }
                }
            }

            // Slider interaction MouseArea
            MouseArea {
                id: sliderMa
                anchors.fill: parent
                anchors.leftMargin: (!I18n.isRTL && root.iconClickable) ? 36 : 0
                anchors.rightMargin: (I18n.isRTL && root.iconClickable) ? 36 : 0
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                function updateVal(mouse) {
                    let raw = mouse.x / width;
                    if (I18n.isRTL) raw = 1.0 - raw;
                    root.sliderMoved(Math.max(0, Math.min(1, raw)));
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
