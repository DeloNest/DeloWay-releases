import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"
import "./desktop"

PanelWindow {
    id: root

    required property ShellScreen targetScreen
    screen: targetScreen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "deloway:background"
    WlrLayershell.layer: WlrLayer.Background
    exclusionMode: ExclusionMode.Ignore

    // ----------------------------------------------------
    // 1. MAIN BACKDROP WALLPAPER
    // ----------------------------------------------------
    Image {
        id: bgImage
        anchors.fill: parent
        source: (ConfigManager.wallpaper && ConfigManager.wallpaper.length > 0)
                ? (ConfigManager.wallpaper.startsWith("file://") ? ConfigManager.wallpaper : ("file://" + ConfigManager.wallpaper))
                : ("file://" + ConfigManager.projectDir + "/assets/wallpaper.jpg")
        fillMode: Image.PreserveAspectCrop
        cache: false
        asynchronous: true

        // Dark Mica Calm Overlay
        Rectangle {
            anchors.fill: parent
            color: Theme.mode === "dark" ? Qt.alpha(Theme.colors.background, 0.15) : Qt.alpha(Theme.colors.text, 0.07)
        }
    }

    // ----------------------------------------------------
    // 2. DESKTOP MODE SURFACES (§5.8)
    // ----------------------------------------------------

    // Mode A: Clean Desktop (Minimalist wallpaper only)
    CleanDesktop {
        anchors.fill: parent
        visible: ConfigManager.desktopMode === "clean"
    }

    // Mode B: Widgets Desktop (Draggable Fluent widgets)
    WidgetsDesktop {
        anchors.fill: parent
        visible: ConfigManager.desktopMode === "widgets"
    }

    // Mode C: Traditional Desktop (Icons grid & rubber-band select)
    TraditionalDesktop {
        anchors.fill: parent
        visible: ConfigManager.desktopMode === "traditional"
    }

    // ----------------------------------------------------
    // 3. DESKTOP CONTEXT MENU OVERLAY
    // ----------------------------------------------------
    DesktopContextMenu {
        anchors.fill: parent
        z: 90
    }

    // ----------------------------------------------------
    // 4. BOTTOM-LEFT DESKTOP PILL [⊞ Desktop]
    // ----------------------------------------------------
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: I18n.isRTL ? undefined : parent.left
        anchors.right: I18n.isRTL ? parent.right : undefined
        anchors.margins: Theme.space16
        implicitHeight: 28
        implicitWidth: deskRow.implicitWidth + 18
        radius: Theme.radiusSmall
        color: deskPillMouse.containsMouse ? Theme.colors.surfaceHover : Theme.colors.surfaceElevated
        border.color: deskPillMouse.containsMouse ? Theme.colors.accent : Theme.hairline
        border.width: 1
        z: 80

        RowLayout {
            id: deskRow
            anchors.centerIn: parent
            spacing: 6

            SymbolicIcon {
                iconSize: 13
                source: "view-app-grid-symbolic"
                iconColor: deskPillMouse.containsMouse ? Theme.colors.accent : Theme.colors.textSecondary
            }

            Text {
                text: I18n.tr("desktop")
                font.family: Theme.typography.fontFamily
                font.pixelSize: 11
                color: deskPillMouse.containsMouse ? Theme.colors.text : Theme.colors.textSecondary
            }
        }

        MouseArea {
            id: deskPillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                // Quick cycle desktop modes: clean -> widgets -> traditional -> clean
                if (ConfigManager.desktopMode === "clean") {
                    ConfigManager.setDesktopMode("widgets");
                } else if (ConfigManager.desktopMode === "widgets") {
                    ConfigManager.setDesktopMode("traditional");
                } else {
                    ConfigManager.setDesktopMode("clean");
                }
            }
        }
    }

    // ----------------------------------------------------
    // 5. BOTTOM-RIGHT BATTERY PILL [🔋 100% ⌄]
    // ----------------------------------------------------
    Rectangle {
        id: battPill
        visible: SystemMonitor.hasBattery
        anchors.bottom: parent.bottom
        anchors.right: I18n.isRTL ? undefined : parent.right
        anchors.left: I18n.isRTL ? parent.left : undefined
        anchors.margins: Theme.space16
        implicitHeight: 28
        implicitWidth: battRow.implicitWidth + 18
        radius: Theme.radiusSmall
        color: battPillMouse.containsMouse ? Theme.colors.surfaceHover : Theme.colors.surfaceElevated
        border.color: battPillMouse.containsMouse ? Theme.colors.accent : Theme.hairline
        border.width: 1
        z: 80

        RowLayout {
            id: battRow
            anchors.centerIn: parent
            spacing: 6

            SymbolicIcon {
                iconSize: 14
                source: "battery-level-100-symbolic"
                iconColor: Theme.colors.textSecondary
            }

            Text {
                text: SystemMonitor.batteryPercent + "%"
                font.family: Theme.typography.fontFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: Theme.colors.text
            }

            Text {
                text: "⌄"
                font.family: Theme.typography.fontFamily
                font.pixelSize: 11
                color: Theme.colors.textTertiary
            }
        }

        MouseArea {
            id: battPillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ShellState.toggleQuickSettings()
        }
    }
}
