import QtQuick
import QtQuick.Layouts
import "../theme"
import "../services"

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property string iconSource: ""
    property bool showCloseButton: true
    property bool showMaximizeButton: false
    property bool showMinimizeButton: false
    property bool isMaximized: false

    default property alias contentData: contentArea.data

    signal closeClicked()
    signal maximizeClicked()
    signal minimizeClicked()

    radius: Theme.radiusLarge
    color: Theme.colors.surface
    border.color: Theme.hairline
    border.width: 1

    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Window Header Bar
        Rectangle {
            id: headerBar
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.space16
                anchors.rightMargin: Theme.space16
                spacing: Theme.space8

                // Window Icon
                SymbolicIcon {
                    visible: root.iconSource !== ""
                    source: root.iconSource
                    iconSize: 16
                    iconColor: Theme.colors.text
                    Layout.alignment: Qt.AlignVCenter
                }

                // Title & Subtitle
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 1

                    Text {
                        horizontalAlignment: Text.AlignLeft   // reading start (mirrored in Arabic)
                        text: root.title
                        font.family: Theme.typography.fontFamily
                        font.hintingPreference: Theme.hintingPreference
                        font.pixelSize: Theme.typography.scaleTitle.size
                        font.weight: Font.DemiBold
                        renderType: Theme.renderType
                        color: Theme.colors.text
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        horizontalAlignment: Text.AlignLeft   // reading start (mirrored in Arabic)
                        visible: root.subtitle !== ""
                        text: root.subtitle
                        font.family: Theme.typography.fontFamily
                        font.hintingPreference: Theme.hintingPreference
                        font.pixelSize: Theme.typography.scaleCaption.size
                        renderType: Theme.renderType
                        color: Theme.colors.textTertiary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Window Action Buttons
                RowLayout {
                    spacing: 4
                    Layout.alignment: Qt.AlignVCenter

                    // Minimize Button
                    Rectangle {
                        visible: root.showMinimizeButton
                        width: 28
                        height: 28
                        radius: Theme.radiusSmall
                        color: minMouse.containsMouse ? Theme.overlayHoverStrong : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                        Text {
                            font.family: Theme.typography.fontFamily
                            anchors.centerIn: parent
                            text: "─"
                            font.pixelSize: Theme.fontSize(11)
                            color: Theme.colors.textSecondary
                        }

                        MouseArea {
                            id: minMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.minimizeClicked()
                        }
                    }

                    // Maximize Button
                    Rectangle {
                        visible: root.showMaximizeButton
                        width: 28
                        height: 28
                        radius: Theme.radiusSmall
                        color: maxMouse.containsMouse ? Theme.overlayHoverStrong : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                        Text {
                            font.family: Theme.typography.fontFamily
                            anchors.centerIn: parent
                            text: root.isMaximized ? "❐" : "□"
                            font.pixelSize: Theme.fontSize(12)
                            color: Theme.colors.textSecondary
                        }

                        MouseArea {
                            id: maxMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.maximizeClicked()
                        }
                    }

                    // Close Button
                    Rectangle {
                        visible: root.showCloseButton
                        width: 28
                        height: 28
                        radius: Theme.radiusSmall
                        color: closeMouse.containsMouse ? Theme.overlayHoverStrong : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                        Text {
                            font.family: Theme.typography.fontFamily
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: Theme.fontSize(11)
                            color: closeMouse.containsMouse ? Theme.colors.urgent : Theme.colors.textSecondary
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeClicked()
                        }
                    }
                }
            }

            // Hairline separator below header
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.hairline
            }
        }

        // Window Content Slot
        Item {
            id: contentArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
        }
    }
}
