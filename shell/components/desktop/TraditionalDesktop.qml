import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../theme"
import "../../services"
import "../"

Item {
    id: root
    anchors.fill: parent

    // ----------------------------------------------------
    // RUBBER-BAND MULTI-SELECT RECTANGLE
    // ----------------------------------------------------
    property bool isSelecting: false
    property real selectStartX: 0
    property real selectStartY: 0
    property real selectCurrentX: 0
    property real selectCurrentY: 0

    readonly property real selectionBoxX: Math.min(selectStartX, selectCurrentX)
    readonly property real selectionBoxY: Math.min(selectStartY, selectCurrentY)
    readonly property real selectionBoxW: Math.abs(selectCurrentX - selectStartX)
    readonly property real selectionBoxH: Math.abs(selectCurrentY - selectStartY)

    Rectangle {
        id: rubberBand
        visible: root.isSelecting && (root.selectionBoxW > 4 || root.selectionBoxH > 4)
        x: root.selectionBoxX
        y: root.selectionBoxY
        width: root.selectionBoxW
        height: root.selectionBoxH
        color: Theme.colors.primary + "26"
        border.color: Theme.colors.primary
        border.width: 1
        radius: 2
        z: 99
    }

    // Wallpaper MouseArea for clicking empty space and rubber-band drag
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        z: 1

        onPressed: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                DesktopManager.closeContextMenu();
                if (!(mouse.modifiers & Qt.ControlModifier)) {
                    DesktopManager.clearSelection();
                }
                root.isSelecting = true;
                root.selectStartX = mouse.x;
                root.selectStartY = mouse.y;
                root.selectCurrentX = mouse.x;
                root.selectCurrentY = mouse.y;
            } else if (mouse.button === Qt.RightButton) {
                DesktopManager.showWallpaperContextMenu(mouse.x, mouse.y);
            }
        }

        onPositionChanged: function(mouse) {
            if (root.isSelecting) {
                root.selectCurrentX = mouse.x;
                root.selectCurrentY = mouse.y;
                checkRubberBandIntersections();
            }
        }

        onReleased: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                root.isSelecting = false;
            }
        }
    }

    function checkRubberBandIntersections() {
        const selX = root.selectionBoxX;
        const selY = root.selectionBoxY;
        const selW = root.selectionBoxW;
        const selH = root.selectionBoxH;

        if (selW < 5 && selH < 5) return;

        var selected = [];
        for (var i = 0; i < iconRepeater.count; ++i) {
            var itemObj = iconRepeater.itemAt(i);
            if (!itemObj) continue;

            // Map item coordinates to desktop root
            var itemPos = itemObj.mapToItem(root, 0, 0);
            var ix = itemPos.x;
            var iy = itemPos.y;
            var iw = itemObj.width;
            var ih = itemObj.height;

            // Bounding box collision test
            if (selX < ix + iw && selX + selW > ix &&
                selY < iy + ih && selY + selH > iy) {
                if (itemObj.itemData && itemObj.itemData.id) {
                    selected.push(itemObj.itemData.id);
                }
            }
        }
        DesktopManager.selectedItemIds = selected;
    }

    // ----------------------------------------------------
    // DESKTOP ICON GRID
    // ----------------------------------------------------
    Grid {
        id: iconGrid
        anchors.top: parent.top
        anchors.left: I18n.isRTL ? undefined : parent.left
        anchors.right: I18n.isRTL ? parent.right : undefined
        anchors.topMargin: 56
        anchors.leftMargin: I18n.isRTL ? 0 : 18
        anchors.rightMargin: I18n.isRTL ? 18 : 0
        spacing: 14
        columns: 1
        flow: Grid.TopToBottom
        z: 10

        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        Repeater {
            id: iconRepeater
            model: DesktopManager.allItems

            delegate: Rectangle {
                id: deskItem
                property var itemData: modelData
                readonly property bool isSelected: DesktopManager.isItemSelected(modelData.id)
                readonly property bool isEditing: DesktopManager.editingItemId === modelData.id

                implicitWidth: 76
                implicitHeight: 76
                radius: Theme.radiusMedium
                color: isSelected
                       ? Qt.alpha(Theme.colors.primary, 0.2)
                       : (itemMouse.containsMouse ? Theme.colors.surfaceHover : "transparent")
                border.color: isSelected
                              ? Theme.colors.primary
                              : (itemMouse.containsMouse ? Theme.colors.borderHighlight : "transparent")
                border.width: isSelected ? 1.5 : 1

                Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                Behavior on border.color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    width: parent.width - 8

                    AppIcon {
                        Layout.alignment: Qt.AlignHCenter
                        iconSize: 42
                        source: deskItem.itemData.icon
                    }

                    // Display Name (Normal)
                    Text {
                        visible: !deskItem.isEditing
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: deskItem.itemData.name
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: Theme.colors.text
                        style: Text.Outline
                        styleColor: Qt.alpha(Theme.colors.background, 0.7)
                    }

                    // Inline Rename TextField
                    TextField {
                        id: renameField
                        visible: deskItem.isEditing
                        Layout.fillWidth: true
                        text: deskItem.itemData.name
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: 11
                        color: Theme.colors.text
                        background: Rectangle {
                            color: Theme.colors.surface
                            radius: Theme.radiusSmall
                            border.color: Theme.colors.primary
                            border.width: 1
                        }
                        onAccepted: {
                            DesktopManager.renameItem(deskItem.itemData, renameField.text);
                        }
                        Keys.onEscapePressed: {
                            DesktopManager.cancelRenaming();
                        }
                        Component.onCompleted: {
                            if (deskItem.isEditing) {
                                forceActiveFocus();
                                selectAll();
                            }
                        }
                    }
                }

                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor

                    onPressed: function(mouse) {
                        if (mouse.button === Qt.LeftButton) {
                            const isMulti = (mouse.modifiers & Qt.ControlModifier);
                            DesktopManager.selectItem(deskItem.itemData.id, isMulti);
                        } else if (mouse.button === Qt.RightButton) {
                            DesktopManager.showItemContextMenu(deskItem.itemData, mouse.x + deskItem.x, mouse.y + deskItem.y + 56);
                        }
                    }

                    onDoubleClicked: function(mouse) {
                        if (mouse.button === Qt.LeftButton) {
                            DesktopManager.openItem(deskItem.itemData);
                        }
                    }
                }
            }
        }
    }
}
