import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../services"
import "../../"

Item {
    id: root

    property string title: ""
    property real contentSpacing: 0
    property alias cardRadius: card.radius
    property alias cardColor: card.color
    property bool collapsible: false
    property bool isExpanded: false

    default property alias content: contentLayout.data

    Layout.fillWidth: true
    implicitWidth: 300
    implicitHeight: mainCol.implicitHeight
    height: implicitHeight
    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    ColumnLayout {
        id: mainCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Theme.space8
        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        // Section Title / Collapsible Header
        Item {
            Layout.fillWidth: true
            implicitHeight: 28
            visible: root.title.length > 0

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.space4
                anchors.rightMargin: Theme.space4
                spacing: Theme.space8
                LayoutMirroring.enabled: I18n.isRTL
                LayoutMirroring.childrenInherit: true

                Text {
                    text: root.title
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(12)
                    font.weight: Font.DemiBold
                    color: root.collapsible && headerMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignLeft
                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                }

                SymbolicIcon {
                    visible: root.collapsible
                    source: root.isExpanded ? "pan-down-symbolic" : (I18n.isRTL ? "pan-start-symbolic" : "pan-end-symbolic")
                    iconSize: 14
                    iconColor: headerMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                    Layout.alignment: Qt.AlignVCenter
                    Behavior on iconColor { ColorAnimation { duration: Theme.motionFast } }
                }
            }

            MouseArea {
                id: headerMa
                anchors.fill: parent
                enabled: root.collapsible
                hoverEnabled: root.collapsible
                cursorShape: root.collapsible ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (root.collapsible) {
                        root.isExpanded = !root.isExpanded;
                    }
                }
            }
        }

        // Floating Card Container
        Rectangle {
            id: card
            Layout.fillWidth: true
            visible: !root.collapsible || root.isExpanded || card.height > 1
            implicitHeight: (!root.collapsible || root.isExpanded) ? contentLayout.implicitHeight : 0
            Layout.preferredHeight: implicitHeight
            radius: Theme.notchRadiusPanel
            color: Theme.notchSurface
            border.color: Theme.notchBorderSubtle
            border.width: 1
            clip: true
            LayoutMirroring.enabled: I18n.isRTL
            LayoutMirroring.childrenInherit: true

            Behavior on implicitHeight {
                NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter }
            }

            ColumnLayout {
                id: contentLayout
                width: parent.width
                spacing: root.contentSpacing
                LayoutMirroring.enabled: I18n.isRTL
                LayoutMirroring.childrenInherit: true
            }
        }
    }
}
