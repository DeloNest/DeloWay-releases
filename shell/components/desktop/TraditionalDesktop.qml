import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../theme"
import "../../services"
import "../"

Item {
    id: root
    property string screenName: ""   // this desktop's screen: the context menu opens there
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
        color: Theme.notchSurfaceElevated
        border.color: Theme.notchBorderHighlight
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
            // A click on the desktop ends an inline rename (the field commits on blur)
            if (DesktopManager.editingItemId !== "") root.forceActiveFocus();
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
                DesktopManager.showWallpaperContextMenu(mouse.x, mouse.y, root.screenName);
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
    // DESKTOP ICONS (MOVABLE / DRAGGABLE CANVAS)
    // ----------------------------------------------------
    Item {
        id: iconsContainer
        anchors.fill: parent
        z: 10

        Repeater {
            id: iconRepeater
            model: DesktopManager.allItems

            delegate: Item {
                id: deskItemWrapper
                property var itemData: modelData
                readonly property bool isSelected: DesktopManager.isItemSelected(modelData.id)
                readonly property bool isEditing: DesktopManager.editingItemId === modelData.id

                property real targetX: DesktopManager.getItemX(modelData.id, index, root.width, root.height)
                property real targetY: DesktopManager.getItemY(modelData.id, index, root.width, root.height)

                onTargetXChanged: {
                    if (!itemMouse.drag.active) {
                        deskItemWrapper.x = targetX;
                    }
                }
                onTargetYChanged: {
                    if (!itemMouse.drag.active) {
                        deskItemWrapper.y = targetY;
                    }
                }
                Component.onCompleted: {
                    deskItemWrapper.x = targetX;
                    deskItemWrapper.y = targetY;
                }

                width: DesktopManager.itemWidth
                height: DesktopManager.itemHeight
                z: itemMouse.drag.active ? 1000 : (isSelected ? 20 : 10)

                property real dragStartX: 0
                property real dragStartY: 0

                // Smooth position transition when snapping/repositioning
                Behavior on x {
                    enabled: !itemMouse.drag.active
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
                Behavior on y {
                    enabled: !itemMouse.drag.active
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                // Card Container (Translucent frosted highlight on hover/select)
                Rectangle {
                    id: deskItemCard
                    anchors.fill: parent
                    radius: 6
                    color: deskItemWrapper.isSelected
                           ? Theme.notchSurfaceActive
                           : (itemMouse.containsMouse ? Theme.notchSurfaceHover : "transparent")
                    border.color: deskItemWrapper.isSelected
                                  ? Theme.notchBorderHighlight
                                  : (itemMouse.containsMouse ? Theme.notchBorder : "transparent")
                    border.width: 1
                    opacity: itemMouse.drag.active ? 0.90 : 1.0

                    Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                    Behavior on border.color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                    Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 4

                        AppIcon {
                            Layout.alignment: Qt.AlignHCenter
                            iconSize: 40
                            source: deskItemWrapper.itemData.icon
                        }

                        // Display Name with soft backdrop pill and clean text shadow
                        Item {
                            id: nameContainer
                            visible: !deskItemWrapper.isEditing
                            Layout.fillWidth: true
                            Layout.preferredHeight: nameText.implicitHeight + 4
                            Layout.alignment: Qt.AlignHCenter

                            // Soft subtle backdrop pill
                            Rectangle {
                                id: nameBackdrop
                                anchors.centerIn: parent
                                width: Math.min(parent.width, nameText.implicitWidth + 10)
                                height: nameText.implicitHeight + 4
                                radius: 4
                                color: deskItemWrapper.isSelected
                                       ? "transparent"
                                       : (itemMouse.containsMouse ? Theme.imageScrim : Theme.imageScrimSoft)
                                Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            }

                            // Text shadow layer
                            Text {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: 1
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.Wrap
                                text: deskItemWrapper.itemData.name
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: deskItemWrapper.isSelected ? Font.Medium : Font.Normal
                                color: Theme.imageTextShadow
                                renderType: Theme.renderType
                            }

                            // Main crisp text
                            Text {
                                id: nameText
                                anchors.centerIn: parent
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.Wrap
                                text: deskItemWrapper.itemData.name
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: deskItemWrapper.isSelected ? Font.Medium : Font.Normal
                                color: Theme.onImageText
                                renderType: Theme.renderType
                            }
                        }

                        // Inline Rename TextField
                        TextField {
                            selectionColor: Theme.textSelection      // monochrome, not the palette's blue
                            selectedTextColor: color
                            id: renameField
                            visible: deskItemWrapper.isEditing
                            Layout.fillWidth: true
                            text: deskItemWrapper.itemData.name
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            color: Theme.notchText
                            horizontalAlignment: Text.AlignHCenter
                            background: Rectangle {
                                color: Theme.notchBackground
                                radius: 6
                                border.color: Theme.notchBorderHighlight
                                border.width: 1
                            }
                            onAccepted: {
                                DesktopManager.renameItem(deskItemWrapper.itemData, renameField.text);
                            }
                            Keys.onEscapePressed: {
                                DesktopManager.cancelRenaming();
                            }
                            // Focus when renaming starts (it used to be requested only if
                            // the icon was created mid-rename, so the field never got the
                            // keyboard) and select the name without its extension.
                            function beginEditing() {
                                text = deskItemWrapper.itemData.name;
                                forceActiveFocus();
                                const dot = deskItemWrapper.itemData.isDir ? -1 : text.lastIndexOf(".");
                                select(0, dot > 0 ? dot : text.length);
                            }
                            onVisibleChanged: if (visible) beginEditing()
                            Component.onCompleted: if (deskItemWrapper.isEditing) beginEditing()
                            // Clicking elsewhere keeps the typed name (Enter and Escape end
                            // the rename first, so they never reach this).
                            onActiveFocusChanged: {
                                if (!activeFocus && deskItemWrapper.isEditing)
                                    DesktopManager.renameItem(deskItemWrapper.itemData, renameField.text);
                            }
                        }
                    }
                }

                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                    drag.target: deskItemWrapper
                    drag.axis: Drag.XAndYAxis
                    drag.minimumX: 8
                    drag.maximumX: root.width - deskItemWrapper.width - 8
                    drag.minimumY: 48
                    drag.maximumY: root.height - deskItemWrapper.height - 48

                    onPressed: function(mouse) {
                        deskItemWrapper.dragStartX = deskItemWrapper.x;
                        deskItemWrapper.dragStartY = deskItemWrapper.y;

                        if (mouse.button === Qt.LeftButton) {
                            const isMulti = (mouse.modifiers & Qt.ControlModifier);
                            DesktopManager.selectItem(deskItemWrapper.itemData.id, isMulti);
                        } else if (mouse.button === Qt.RightButton) {
                            DesktopManager.showItemContextMenu(deskItemWrapper.itemData, deskItemWrapper.x + mouse.x, deskItemWrapper.y + mouse.y, root.screenName);
                        }
                    }

                    onReleased: function(mouse) {
                        if (mouse.button === Qt.LeftButton) {
                            // Check if dropped into Central Notch area (top center of screen)
                            const itemCenterX = deskItemWrapper.x + deskItemWrapper.width / 2;
                            const screenCenterX = root.width / 2;
                            const isOverNotch = (deskItemWrapper.y < 56) && (Math.abs(itemCenterX - screenCenterX) < 260);

                            if (isOverNotch && deskItemWrapper.itemData.path) {
                                // Stage file into Central Notch LocalSend tray tab
                                ShellState.setSmartNotchTab(2);   // Share tab
                                ShellState.openSmartNotch();
                                LocalSendService.stageFiles([deskItemWrapper.itemData.path]);

                                // Return icon to original position
                                deskItemWrapper.x = deskItemWrapper.targetX;
                                deskItemWrapper.y = deskItemWrapper.targetY;
                            } else {
                                // Normal desktop repositioning with snap-to-grid
                                DesktopManager.saveItemPosition(deskItemWrapper.itemData.id, deskItemWrapper.x, deskItemWrapper.y, root.width, root.height);
                                deskItemWrapper.x = deskItemWrapper.targetX;
                                deskItemWrapper.y = deskItemWrapper.targetY;
                            }
                        }
                    }

                    onDoubleClicked: function(mouse) {
                        if (mouse.button === Qt.LeftButton) {
                            DesktopManager.openItem(deskItemWrapper.itemData);
                        }
                    }
                }
            }
        }
    }
}
