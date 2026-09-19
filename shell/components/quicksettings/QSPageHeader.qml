import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services"

RowLayout {
    id: root

    property string title: ""
    property bool hasAction: false
    property string actionIcon: ""
    property string actionText: ""

    signal backClicked()
    signal actionClicked()

    Layout.fillWidth: true
    Layout.preferredHeight: 28
    spacing: 6

    // Back Button
    QSRoundButton {
        buttonSize: 28
        text: I18n.isRTL ? "›" : "‹"
        iconSize: 16
        normalColor: "transparent"
        hoverColor: Theme.notchSurfaceHover
        textColor: Theme.notchText
        onClicked: root.backClicked()
    }

    // Title
    Text {
        text: root.title
        font.family: Theme.typography.fontFamily
        font.pixelSize: Theme.fontSize(12)
        font.weight: Font.DemiBold
        color: Theme.notchText
        elide: Text.ElideRight
        Layout.fillWidth: true
    }

    // Action Button
    QSRoundButton {
        visible: root.hasAction
        buttonSize: 28
        icon: root.actionIcon
        text: root.actionText
        iconSize: 14
        normalColor: "transparent"
        hoverColor: Theme.notchSurfaceHover
        textColor: Theme.notchTextSecondary
        hoverTextColor: Theme.notchText
        onClicked: root.actionClicked()
    }
}
