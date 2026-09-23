import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import "../theme"
import "../services"

PopupWindow {
    id: root

    required property var menuHandle
    property string trayItemId: ""
    property bool _animVisible: false

    signal menuClosed()

    color: "transparent"
    visible: true

    HyprlandFocusGrab {
        windows: [ root ]
        active: root.visible
        onCleared: root.close()
    }

    implicitWidth: menuCard.width + 24
    implicitHeight: menuCard.height + menuCard.anchors.topMargin + 12

    function open() {
        stackView.clear();
        stackView.push(subMenuComponent.createObject(null, {
            handle: root.menuHandle,
            isSubMenu: false,
            title: ""
        }));
        _animVisible = true;
        menuCard.forceActiveFocus();
    }

    function close() {
        _animVisible = false;
        root.visible = false;
        root.menuClosed();
    }

    Component.onCompleted: {
        root.open();
    }

    // Escape dismissal (returns from submenus first, then dismisses)
    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: {
            if (stackView.depth > 1) {
                stackView.pop();
            } else {
                root.close();
            }
        }
    }

    // Main OLED Menu Card
    Rectangle {
        id: menuCard
        z: 1
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 14
        width: Math.max(180, Math.min(320, (stackView.currentItem ? stackView.currentItem.implicitWidth : 180) + 16))
        height: Math.max(38, Math.min(600, (stackView.currentItem ? stackView.currentItem.implicitHeight : 38) + 16))
        radius: Theme.radiusMedium
        color: Theme.notchBackground
        border.color: Theme.notchBorder
        border.width: 1

        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        focus: true
        Keys.onEscapePressed: {
            if (stackView.depth > 1) stackView.pop();
            else root.close();
        }

        // Smooth subtle entrance animation
        opacity: root._animVisible ? 1.0 : 0.0
        scale: root._animVisible ? 1.0 : 0.95
        transformOrigin: Item.Top
        Behavior on opacity { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingExit } }
        Behavior on scale   { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingExit } }
        Behavior on width   { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingExit } }
        Behavior on height  { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingExit } }

        // Top luminous rim
        Rectangle {
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            anchors.topMargin: 1; anchors.leftMargin: 1; anchors.rightMargin: 1
            height: 1; radius: parent.radius
            color: Theme.notchBorderSubtle
        }

        // Submenu Stack View
        StackView {
            id: stackView
            anchors.fill: parent
            anchors.margins: 8

            implicitWidth: currentItem ? currentItem.implicitWidth : 180
            implicitHeight: currentItem ? currentItem.implicitHeight : 38

            pushEnter: Transition { NumberAnimation { duration: 0 } }
            pushExit: Transition { NumberAnimation { duration: 0 } }
            popEnter: Transition { NumberAnimation { duration: 0 } }
            popExit: Transition { NumberAnimation { duration: 0 } }
        }
    }

    Component {
        id: subMenuComponent

        ColumnLayout {
            id: submenu
            required property var handle
            property bool isSubMenu: false
            property string title: ""

            spacing: 2
            Layout.fillWidth: true

            StackView.onRemoved: submenu.destroy()

            QsMenuOpener {
                id: menuOpener
                menu: submenu.handle
            }

            // ── Back Button (Submenus only) ──
            Rectangle {
                visible: submenu.isSubMenu
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 28 : 0
                radius: Theme.radiusSmall
                color: backMouse.pressed
                       ? Theme.notchSurfaceActive
                       : (backMouse.containsMouse ? Theme.notchSurfaceHover : "transparent")

                Behavior on color { ColorAnimation { duration: 80 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    Text {
                        text: I18n.isRTL ? "›" : "‹"
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: Theme.notchTextSecondary
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignLeft   // reading start, whatever the label's script
                        text: submenu.title.length > 0 ? submenu.title : (I18n.isRTL ? "رجوع" : "Back")
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(11)
                        font.weight: Font.DemiBold
                        color: Theme.notchText
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: stackView.pop()
                }
            }

            // Separator under back button
            Rectangle {
                visible: submenu.isSubMenu
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                Layout.topMargin: 2
                Layout.bottomMargin: 2
                color: Theme.notchBorderSubtle
            }

            Repeater {
                id: repeater
                model: menuOpener.children

                delegate: Item {
                    id: itemRoot
                    required property var modelData

                    visible: Boolean(modelData)
                    Layout.fillWidth: true
                    Layout.preferredHeight: modelData && modelData.isSeparator ? 7 : 30
                    implicitHeight: Layout.preferredHeight
                    implicitWidth: modelData && !modelData.isSeparator ? (itemRow.implicitWidth + 20) : 160

                    // ── Separator Line ──
                    Rectangle {
                        visible: modelData && modelData.isSeparator
                        anchors.centerIn: parent
                        width: parent.width - 8
                        height: 1
                        color: Theme.notchBorderSubtle
                    }

                    // ── Action / Status / Submenu Item ──
                    Rectangle {
                        id: itemBg
                        visible: modelData && !modelData.isSeparator
                        anchors.fill: parent
                        radius: Theme.radiusSmall

                        readonly property bool isEnabled: modelData ? modelData.enabled : false
                        readonly property bool isChecked: modelData && (modelData.checkState === Qt.Checked || modelData.checkState === Qt.PartiallyChecked)

                        color: !isEnabled
                               ? "transparent"
                               : (itemMouse.pressed
                                  ? Theme.notchSurfaceActive
                                  : (itemMouse.containsMouse ? Theme.notchSurfaceHover : "transparent"))


                        Behavior on color { ColorAnimation { duration: 80 } }

                        RowLayout {
                            id: itemRow
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            // Radio / Checkbox Indicator
                            Item {
                                visible: modelData && modelData.buttonType !== QsMenuButtonType.None
                                implicitWidth: 14
                                implicitHeight: 14
                                Layout.alignment: Qt.AlignVCenter

                                // Radio indicator
                                Rectangle {
                                    visible: modelData && modelData.buttonType === QsMenuButtonType.RadioButton
                                    anchors.centerIn: parent
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: "transparent"
                                    border.color: itemBg.isChecked ? Theme.notchText : Theme.notchTextTertiary
                                    border.width: 1

                                    Rectangle {
                                        visible: itemBg.isChecked
                                        anchors.centerIn: parent
                                        width: 6
                                        height: 6
                                        radius: 3
                                        color: Theme.notchText
                                    }
                                }

                                // Checkbox indicator
                                Text {
                                    visible: modelData && modelData.buttonType === QsMenuButtonType.CheckBox
                                    anchors.centerIn: parent
                                    text: itemBg.isChecked ? (modelData.checkState === Qt.PartiallyChecked ? "–" : "✓") : ""
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: Theme.notchText
                                }
                            }

                            // Icon
                            IconImage {
                                visible: modelData && modelData.icon && modelData.icon.length > 0
                                source: modelData ? (modelData.icon || "") : ""
                                implicitSize: 16
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // Text Label
                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignLeft   // reading start, whatever the label's script
                                text: modelData && modelData.text ? modelData.text.replace(/&(?=[^&])/g, "") : ""
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: itemBg.isChecked ? Font.DemiBold : Font.Normal
                                color: !itemBg.isEnabled
                                       ? Theme.notchTextTertiary
                                       : (itemMouse.containsMouse ? Theme.notchText : Theme.notchTextSecondary)
                                elide: Text.ElideRight
                                renderType: Theme.renderType
                                maximumLineCount: 1
                            }

                            // Submenu Chevron
                            Text {
                                visible: modelData && modelData.hasChildren
                                text: I18n.isRTL ? "‹" : "›"
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: itemMouse.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            enabled: itemBg.isEnabled
                            hoverEnabled: itemBg.isEnabled
                            cursorShape: itemBg.isEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                            onClicked: {
                                if (!itemBg.isEnabled) return;
                                if (modelData.hasChildren) {
                                    stackView.push(subMenuComponent.createObject(null, {
                                        handle: modelData,
                                        isSubMenu: true,
                                        title: modelData.text ? modelData.text.replace(/&(?=[^&])/g, "") : ""
                                    }));
                                    return;
                                }
                                modelData.triggered();
                                root.close();
                            }
                        }
                    }
                }
            }
        }
    }
}
