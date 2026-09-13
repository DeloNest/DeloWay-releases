import QtQuick
import QtQuick.Layouts
import "../theme"
import "../services"

Rectangle {
    id: root

    property alias text: input.text
    property alias placeholderText: placeholder.text
    property alias echoMode: input.echoMode
    property bool showSearchIcon: false
    property bool showClearButton: true
    property alias readOnly: input.readOnly
    property alias inputFocus: input.focus
    property alias textInput: input
    property var customBackground: null
    property var customBorderColor: null
    property var customFocusBorderColor: null

    signal accepted()
    signal textEdited()

    function forceActiveFocus() {
        input.forceActiveFocus();
    }

    function clear() {
        input.text = "";
    }

    implicitWidth: 240
    implicitHeight: 38
    radius: Theme.radiusSmall

    color: customBackground !== null
           ? (input.activeFocus ? Qt.rgba(1, 1, 1, 0.12) : (mouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : customBackground))
           : (input.activeFocus ? Theme.colors.surface : Theme.colors.surfaceElevated)
    border.color: customBorderColor !== null
           ? (input.activeFocus ? (customFocusBorderColor !== null ? customFocusBorderColor : Theme.colors.accent) : (mouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : customBorderColor))
           : (input.activeFocus ? (customFocusBorderColor !== null ? customFocusBorderColor : Theme.colors.accent) : (mouseArea.containsMouse ? Theme.colors.borderHighlight : Theme.hairline))
    border.width: input.activeFocus ? 1.5 : 1

    Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
    Behavior on border.color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.IBeamCursor
        onClicked: input.forceActiveFocus()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.space8
        anchors.rightMargin: Theme.space8
        spacing: Theme.space8

        SymbolicIcon {
            visible: root.showSearchIcon
            source: "edit-find-symbolic"
            iconSize: 14
            iconColor: input.activeFocus
                       ? (customFocusBorderColor !== null ? Qt.rgba(1, 1, 1, 0.90) : Theme.colors.accent)
                       : Theme.colors.textTertiary
            Layout.alignment: Qt.AlignVCenter
            Behavior on iconColor { ColorAnimation { duration: Theme.motionFast } }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            TextInput {
                id: input
                anchors.fill: parent
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.colors.text
                selectionColor: Theme.colors.accent
                selectedTextColor: Theme.colors.accentText
                font.family: Theme.typography.fontFamily
                font.hintingPreference: Theme.hintingPreference
                font.pixelSize: Theme.typography.scaleBody.size
                renderType: Theme.renderType
                clip: true

                onAccepted: root.accepted()
                onTextEdited: root.textEdited()
            }

            Text {
                id: placeholder
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                color: Theme.colors.textMuted
                font.family: Theme.typography.fontFamily
                font.hintingPreference: Theme.hintingPreference
                font.pixelSize: Theme.typography.scaleBody.size
                renderType: Theme.renderType
                visible: input.text.length === 0 && !input.inputMethodComposing
                elide: Text.ElideRight
            }
        }

        // Clear button
        Rectangle {
            visible: root.showClearButton && input.text.length > 0
            width: 20
            height: 20
            radius: 10
            color: clearMouse.containsMouse ? Theme.overlayHoverStrong : "transparent"
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: "✕"
                font.pixelSize: 10
                color: Theme.colors.textTertiary
            }

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.clear();
                    root.textEdited();
                    input.forceActiveFocus();
                }
            }
        }
    }
}
