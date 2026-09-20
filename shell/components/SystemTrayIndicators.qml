import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import "../theme"

Item {
    id: root

    // Determine whether any active, non-passive tray items exist
    readonly property bool hasVisibleItems: {
        const items = SystemTray.items.values;
        if (!items || items.length === 0) return false;
        for (let i = 0; i < items.length; i++) {
            if (items[i] && items[i].status !== Status.Passive) return true;
        }
        return false;
    }

    visible: hasVisibleItems
    implicitWidth: visible ? trayRow.implicitWidth : 0
    implicitHeight: visible ? trayRow.implicitHeight : 0

    RowLayout {
        id: trayRow
        anchors.fill: parent
        spacing: 4

        Repeater {
            model: SystemTray.items

            delegate: MouseArea {
                id: itemArea
                required property SystemTrayItem modelData

                visible: modelData.status !== Status.Passive
                implicitWidth: visible ? 28 : 0
                implicitHeight: visible ? 28 : 0
                Layout.alignment: Qt.AlignVCenter

                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                // Visual hover pill matching QuickSettings capsule buttons
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.notchRadiusPill
                    color: itemArea.containsMouse ? Theme.notchSurfaceHover : "transparent"
                    Behavior on color { ColorAnimation { duration: 80 } }
                }

                // Native QtQuick Image element displaying item.icon directly with crisp high-dpi sizing
                Image {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    sourceSize.width: 48
                    sourceSize.height: 48
                    fillMode: Image.PreserveAspectFit
                    source: modelData.icon || ""
                    smooth: true
                    mipmap: true
                }

                onPressed: (mouse) => {
                    if (mouse.button === Qt.LeftButton) {
                        modelData.activate();
                    } else if (mouse.button === Qt.MiddleButton) {
                        modelData.secondaryActivate();
                    } else if (mouse.button === Qt.RightButton) {
                        if (modelData.hasMenu) {
                            menuAnchor.open();
                        } else {
                            modelData.activate();
                        }
                    }
                }

                // Mouse wheel support (e.g. tray icons with volume or scroll actions)
                onWheel: (wheel) => {
                    wheel.accepted = true;
                    if (wheel.angleDelta.y !== 0) {
                        modelData.scroll(wheel.angleDelta.y > 0 ? 1 : -1, false);
                    } else if (wheel.angleDelta.x !== 0) {
                        modelData.scroll(wheel.angleDelta.x > 0 ? 1 : -1, true);
                    }
                }

                // Native D-Bus context menu anchor
                QsMenuAnchor {
                    id: menuAnchor
                    anchor.window: itemArea.QsWindow.window
                    anchor.item: itemArea
                    menu: modelData.menu
                }

            }
        }

        // Subtle vertical divider separating tray apps from system status indicators
        Rectangle {
            visible: root.hasVisibleItems
            implicitWidth: 1
            implicitHeight: 16
            color: Theme.notchTextTertiary
            opacity: 0.35
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: 4
            Layout.rightMargin: 4
        }
    }
}
