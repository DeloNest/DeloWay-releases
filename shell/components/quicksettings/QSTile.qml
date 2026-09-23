import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services"
import ".."

// QSTile — split toggle tile.
//   [ icon  Title          |  › ]
//   [       Subtitle       |    ]
// Main area toggles; the chevron segment (only when `hasDetails`) opens the sub-page.
// Active state is monochrome: solid high-contrast fill with inverted glyphs.
// RTL: the whole tile mirrors (icon at reading-start, chevron at reading-end, chevron glyph
// points in the reading direction).
Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property string iconName: ""
    property bool active: false
    property bool hasDetails: false
    property bool busy: false
    property bool available: true

    signal toggled()
    signal detailsRequested()

    implicitHeight: Theme.qsTileHeight + 4
    radius: Theme.qsTileRadius
    color: root.active ? Theme.qsTileActive
                       : (mainMa.containsMouse || chevMa.containsMouse ? Theme.qsTileBackgroundHover : Theme.qsTileBackground)
    border.color: root.active ? "transparent" : Theme.qsTileBorder
    border.width: 1
    opacity: root.available ? 1 : 0.45
    scale: mainMa.pressed || chevMa.pressed ? 0.975 : 1
    Behavior on color { ColorAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
    Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic } }

    readonly property color fg: root.active ? Theme.qsTileIconActive : Theme.notchText
    readonly property color fgDim: root.active ? Qt.alpha(Theme.qsTileIconActive, 0.62) : Theme.notchTextSecondary

    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Toggle area ──
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: root.hasDetails ? 6 : 12
                spacing: 10

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 34
                    implicitHeight: 34
                    radius: 17
                    color: root.active ? Qt.alpha(Theme.qsTileIconActive, 0.08) : Theme.qsTileIconCircleInactive
                    Behavior on color { ColorAnimation { duration: Theme.motionBase } }

                    SymbolicIcon {
                        anchors.centerIn: parent
                        iconSize: 17
                        source: root.iconName
                        iconColor: root.fg
                        opacity: root.busy ? 0.35 : 1
                    }
                    // Busy ring (scanning / connecting)
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.width: 2
                        border.color: root.fg
                        visible: root.busy
                        opacity: 0.6
                        SequentialAnimation on opacity {
                            running: root.busy
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.15; duration: 600; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0.6; duration: 600; easing.type: Easing.InOutSine }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: -1

                    Text {
                        Layout.fillWidth: true
                        text: root.title
                        textFormat: Text.PlainText
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(12)
                        font.weight: Font.DemiBold
                        color: root.fg
                        renderType: Theme.renderType
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        // Subtitles are often SSIDs / device names: give each its own paragraph direction.
                        text: NotificationManager.bidi(root.subtitle)
                        textFormat: Text.PlainText
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(10)
                        color: root.fgDim
                        renderType: Theme.renderType
                    }
                }
            }

            MouseArea {
                id: mainMa
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.available
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggled()
            }
        }

        // ── Details segment ──
        Rectangle {
            visible: root.hasDetails
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 1
            implicitHeight: 24
            color: root.active ? Qt.alpha(Theme.qsTileIconActive, 0.15) : Theme.notchBorderSubtle
        }
        Item {
            visible: root.hasDetails
            Layout.fillHeight: true
            implicitWidth: 34

            SymbolicIcon {
                anchors.centerIn: parent
                iconSize: 13
                source: I18n.isRTL ? "go-previous-symbolic" : "go-next-symbolic"
                iconColor: root.fgDim
            }
            MouseArea {
                id: chevMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.detailsRequested()
            }
        }
    }
}
