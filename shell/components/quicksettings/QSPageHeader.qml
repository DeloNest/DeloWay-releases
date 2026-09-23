import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services"
import "../timecapsule"

// QSPageHeader — sub-page header: [back] Title ··· [action] [switch]
// The back glyph points toward the reading start (→ in Arabic, ← in English).
// API is backward compatible with the previous header (title/hasAction/actionText).
RowLayout {
    id: root

    property string title: ""
    property string subtitle: ""
    property bool hasAction: false
    property string actionIcon: "view-refresh-symbolic"
    property string actionText: ""          // legacy; ignored in favour of actionIcon
    property bool actionBusy: false
    property bool hasSwitch: false
    property bool switchOn: false

    signal backClicked()
    signal actionClicked()
    signal switchToggled(bool on)

    Layout.fillWidth: true
    spacing: 10
    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    QSIconButton {
        size: 30
        iconName: I18n.isRTL ? "go-next-symbolic" : "go-previous-symbolic"
        onClicked: root.backClicked()
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: -2
        Text {
            Layout.fillWidth: true
            text: root.title
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideRight
            font.family: Theme.typography.fontFamily
            font.pixelSize: Theme.fontSize(14)
            font.weight: Font.Bold
            color: Theme.notchText
            renderType: Theme.renderType
        }
        Text {
            Layout.fillWidth: true
            visible: text.length > 0
            // Paragraph direction from the UI language, not the content (an English SSID
            // inside an Arabic sentence used to flip the whole line).
            text: (I18n.isRTL ? "\u200F" : "\u200E") + root.subtitle
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideRight
            font.family: Theme.typography.fontFamily
            font.pixelSize: Theme.fontSize(10)
            color: Theme.notchTextTertiary
            renderType: Theme.renderType
        }
    }

    QSIconButton {
        visible: root.hasAction
        size: 30
        iconName: root.actionIcon
        spinning: root.actionBusy
        onClicked: root.actionClicked()
    }

    MonoSwitch {
        visible: root.hasSwitch
        Layout.alignment: Qt.AlignVCenter
        checked: root.switchOn
        onToggled: (on) => root.switchToggled(on)
    }
}
