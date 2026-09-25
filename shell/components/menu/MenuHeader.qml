import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services"
import ".."

// Header of a DeloWay context menu opened on one item: its icon and name (as in
// AppContextMenu). Follow it with a MenuSeparator.
RowLayout {
    id: root

    property string icon: ""
    property string title: ""

    Layout.fillWidth: true
    Layout.leftMargin: 8
    Layout.rightMargin: 8
    Layout.topMargin: 4
    Layout.bottomMargin: 4
    spacing: 10

    AppIcon {
        iconSize: 22
        source: root.icon
        Layout.alignment: Qt.AlignVCenter
    }

    Text {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        text: NotificationManager.bidi(root.title)
        textFormat: Text.PlainText
        font.family: Theme.typography.fontFamily
        font.pixelSize: Theme.fontSize(14)
        font.weight: Font.DemiBold
        color: Theme.notchText
        elide: Text.ElideRight
        maximumLineCount: 1
        horizontalAlignment: Text.AlignLeft
        renderType: Theme.renderType
    }
}
