import QtQuick
import QtQuick.Layouts
import "../theme"
import "../services"

// One key combination as chips: [⊞] + [Shift] + [V]. Super shows as its four-square logo.
// keys: display names in order (ShortcutService.comboKeys() gives them for a bind).
// Always laid out left to right: a combination reads the same in both languages.
RowLayout {
    id: root

    property var keys: []
    property bool dim: false

    spacing: 3
    LayoutMirroring.enabled: false
    LayoutMirroring.childrenInherit: true

    Repeater {
        model: root.keys

        delegate: RowLayout {
            id: keyDel
            required property string modelData
            required property int index
            readonly property bool isSuper: modelData === "Super"
            spacing: 3

            Rectangle {
                implicitHeight: 22
                implicitWidth: keyDel.isSuper ? 26 : Math.max(22, keyText.implicitWidth + Theme.space8)
                radius: Theme.radiusSmall
                color: Theme.colors.surfaceElevated
                border.color: Theme.hairline
                border.width: 1
                opacity: root.dim ? 0.55 : 1

                Grid {
                    anchors.centerIn: parent
                    visible: keyDel.isSuper
                    columns: 2
                    spacing: 1.5
                    Repeater {
                        model: 4
                        Rectangle { width: 4; height: 4; radius: 0.8; color: Theme.colors.text }
                    }
                }

                Text {
                    id: keyText
                    anchors.centerIn: parent
                    visible: !keyDel.isSuper
                    text: keyDel.modelData
                    font.family: Theme.typography.fontFamily
                    font.hintingPreference: Theme.hintingPreference
                    font.pixelSize: Theme.fontSize(11)
                    font.weight: Font.Medium
                    renderType: Theme.renderType
                    color: Theme.colors.text
                }
            }

            Text {
                visible: keyDel.index < root.keys.length - 1
                text: "+"
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(11)
                renderType: Theme.renderType
                color: Theme.colors.textTertiary
            }
        }
    }
}
