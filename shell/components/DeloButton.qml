import QtQuick
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root

    // API properties
    property string text: ""
    property string iconSource: ""
    property real iconSize: 14
    property string variant: "secondary" // "primary" | "secondary" | "danger" | "ghost"
    property bool disabled: false
    property bool loading: false

    signal clicked()

    implicitWidth: contentRow.implicitWidth + (Theme.space16 * 1.5)
    implicitHeight: 36
    radius: Theme.radiusSmall

    // Base background colors based on variant and state
    readonly property color baseColor: {
        if (root.variant === "primary") {
            return mouseArea.pressed ? Theme.colors.primaryActive : (mouseArea.containsMouse ? Theme.colors.primaryHover : Theme.colors.primary);
        } else if (root.variant === "danger") {
            return mouseArea.pressed ? Qt.darker(Theme.colors.urgent, 1.2) : (mouseArea.containsMouse ? Theme.colors.urgent : Qt.alpha(Theme.colors.urgent, 0.15));
        } else if (root.variant === "ghost") {
            return mouseArea.pressed ? Theme.overlayHoverStrong : (mouseArea.containsMouse ? Theme.overlayHover : "transparent");
        } else {
            // "secondary"
            return mouseArea.pressed ? Theme.colors.surfaceActive : (mouseArea.containsMouse ? Theme.colors.surfaceHover : Theme.colors.surfaceElevated);
        }
    }

    // Border styling
    readonly property color baseBorderColor: {
        if (root.variant === "primary") {
            return "transparent";
        } else if (root.variant === "danger") {
            return mouseArea.containsMouse ? Theme.colors.urgent : Qt.alpha(Theme.colors.urgent, 0.35);
        } else if (root.variant === "ghost") {
            return "transparent";
        } else {
            return mouseArea.containsMouse ? Theme.colors.borderHighlight : Theme.hairline;
        }
    }

    // Text color
    readonly property color textColor: {
        if (root.variant === "primary") {
            return Theme.colors.accentText;
        } else if (root.variant === "danger") {
            return (mouseArea.containsMouse || root.variant === "danger") ? (mouseArea.containsMouse ? Theme.textOnPrimary : Theme.colors.urgent) : Theme.colors.urgent;
        } else {
            return mouseArea.containsMouse ? Theme.colors.text : Theme.colors.textSecondary;
        }
    }

    color: root.baseColor
    border.color: root.baseBorderColor
    border.width: (root.variant === "ghost" || root.variant === "primary") ? 0 : 1

    opacity: root.disabled ? 0.5 : 1.0
    scale: (mouseArea.pressed && !root.disabled) ? 0.97 : 1.0

    Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
    Behavior on border.color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
    Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
    Behavior on opacity { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: Theme.space8

        SymbolicIcon {
            visible: root.iconSource !== "" && !root.loading
            source: root.iconSource
            iconSize: root.iconSize
            iconColor: root.textColor
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            id: labelText
            visible: root.text !== ""
            text: root.text
            font.family: Theme.typography.fontFamily
            font.hintingPreference: Theme.hintingPreference
            font.pixelSize: Theme.typography.scaleBody.size
            font.weight: root.variant === "primary" ? Font.DemiBold : Font.Medium
            renderType: Theme.renderType
            color: root.textColor
            Layout.alignment: Qt.AlignVCenter
            Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: !root.disabled
        cursorShape: root.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
        enabled: !root.disabled && !root.loading
        onClicked: root.clicked()
    }
}
