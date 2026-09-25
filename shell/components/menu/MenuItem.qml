import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services"
import ".."

// One row of a DeloWay context menu — the metrics and states of AppContextMenu's rows
// (the reference menu): 32 px, 16 px neutral icon, 13 px regular label, fill-only hover.
//   toggle: true   → a two-state switch at the row's end (checked = on)
//   checkable: true → a check mark at the row's end while checked (one-of-many choices)
Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property bool toggle: false
    property bool checkable: false
    property bool checked: false
    signal triggered()

    readonly property bool hovered: rowMa.containsMouse && root.enabled

    Layout.fillWidth: true
    implicitHeight: 32
    radius: Theme.radiusSmall
    color: rowMa.pressed ? Theme.notchSurfaceActive : (root.hovered ? Theme.notchSurfaceHover : "transparent")
    opacity: root.enabled ? 1 : 0.5
    Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 10

        SymbolicIcon {
            visible: root.icon.length > 0
            source: root.icon
            iconSize: 16
            iconColor: root.hovered ? Theme.notchText : Theme.notchTextSecondary
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: NotificationManager.bidi(root.text)
            textFormat: Text.PlainText
            font.family: Theme.typography.fontFamily
            font.pixelSize: Theme.fontSize(13)
            font.weight: Font.Normal
            color: Theme.notchText
            elide: Text.ElideRight
            maximumLineCount: 1
            horizontalAlignment: Text.AlignLeft   // reading start (mirrored in Arabic)
            renderType: Theme.renderType
        }

        SymbolicIcon {
            visible: root.checkable && root.checked
            source: "object-select-symbolic"
            iconSize: 14
            iconColor: Theme.notchText
            Layout.alignment: Qt.AlignVCenter
        }

        // Compact monochrome switch: on = inverse fill, knob at the reading end
        Rectangle {
            visible: root.toggle
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 28
            implicitHeight: 16
            radius: 8
            color: root.checked ? Theme.inverseSurface : Theme.notchSurfaceHover
            border.color: root.checked ? Theme.inverseSurface : Theme.notchBorder
            border.width: 1
            Behavior on color { ColorAnimation { duration: Theme.motionFast } }

            Rectangle {
                width: 10
                height: 10
                radius: 5
                anchors.verticalCenter: parent.verticalCenter
                // x is not mirrored by LayoutMirroring: "on" sits at the reading end.
                x: (root.checked !== I18n.isRTL) ? parent.width - width - 3 : 3
                color: root.checked ? Theme.inverseText : Theme.notchTextSecondary
                Behavior on x { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
            }
        }
    }

    MouseArea {
        id: rowMa
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggered()
    }
}
