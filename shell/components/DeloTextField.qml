import QtQuick
import QtQuick.Layouts
import "../theme"
import "../services"

Rectangle {
    id: root

    // Own mirroring (icon · text · clear follow the reading direction wherever it is
    // hosted); text and placeholder start at the reading start, not by first letter.
    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    property alias text: input.text
    property alias placeholderText: placeholder.text
    property alias echoMode: input.echoMode
    property bool showSearchIcon: false
    property bool showClearButton: true
    property alias readOnly: input.readOnly
    property alias inputFocus: input.focus
    property alias textInput: input
    property int fontPixelSize: Theme.fontSize(13)
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
           ? (input.activeFocus ? Theme.notchSurfaceActive : (mouseArea.containsMouse ? Theme.notchSurfaceHover : customBackground))
           : (input.activeFocus ? Theme.colors.surface : Theme.colors.surfaceElevated)
    border.color: customBorderColor !== null
           ? (input.activeFocus ? (customFocusBorderColor !== null ? customFocusBorderColor : Theme.notchBorderHighlight) : (mouseArea.containsMouse ? Theme.notchBorderHighlight : customBorderColor))
           : (input.activeFocus ? (customFocusBorderColor !== null ? customFocusBorderColor : Theme.colors.borderHighlight) : (mouseArea.containsMouse ? Theme.colors.borderHighlight : Theme.hairline))
    border.width: 1   // focus is shown by the border colour, not a half-pixel width change

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
            iconColor: input.activeFocus ? Theme.notchText : Theme.notchTextTertiary
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
                horizontalAlignment: TextInput.AlignLeft
                color: Theme.colors.text
                selectionColor: Theme.textSelection
                selectedTextColor: Theme.colors.text
                font.family: Theme.typography.fontFamily
                font.hintingPreference: Theme.hintingPreference
                font.pixelSize: root.fontPixelSize
                renderType: Theme.renderType
                clip: true

                onAccepted: root.accepted()
                onTextEdited: root.textEdited()
            }

            Text {
                id: placeholder
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignLeft
                color: Theme.colors.textMuted
                font.family: Theme.typography.fontFamily
                font.hintingPreference: Theme.hintingPreference
                font.pixelSize: root.fontPixelSize
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
                font.pixelSize: Theme.fontSize(10)
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
