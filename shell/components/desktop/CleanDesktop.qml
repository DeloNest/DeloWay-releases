import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services"

Item {
    id: root
    anchors.fill: parent

    // Click handler for wallpaper
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                DesktopManager.showWallpaperContextMenu(mouse.x, mouse.y);
            } else {
                ShellState.closeAll();
                DesktopManager.closeContextMenu();
            }
        }
    }
}
