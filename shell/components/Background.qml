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
        readonly property string bundled: "file://" + ConfigManager.projectDir + "/assets/wallpaper.jpg"
        readonly property string configured: (ConfigManager.wallpaper && ConfigManager.wallpaper.length > 0)
                ? ConfigManager.fileUrl(ConfigManager.wallpaper)
                : ""
        // A configured path that no longer exists falls back to the bundled wallpaper
        // instead of leaving a black desktop.
        property bool configuredFailed: false
        onConfiguredChanged: configuredFailed = false
        onStatusChanged: if (status === Image.Error && source.toString() === configured) configuredFailed = true
        source: (configured.length > 0 && !configuredFailed) ? configured : bundled
        fillMode: Image.PreserveAspectCrop
        // Decode at the output's pixel size (a 4K JPEG on a 1440p screen was ~33 MB decoded).
        sourceSize.width: Math.round(width * Screen.devicePixelRatio)
        sourceSize.height: Math.round(height * Screen.devicePixelRatio)
        cache: false
        asynchronous: true

        // Dark Mica Calm Overlay
        Rectangle {
            anchors.fill: parent
            color: Theme.wallpaperTint
        }
    }

    // ----------------------------------------------------
    // 2. DESKTOP MODE SURFACES (§5.8)
    // ----------------------------------------------------

    // Desktop content hidden: an empty desktop (wallpaper only, right-click still works)
    CleanDesktop {
        anchors.fill: parent
        screenName: root.targetScreen ? root.targetScreen.name : ""
        visible: !ConfigManager.showDesktopContent
    }

    // Widgets Desktop (draggable Fluent widgets)
    WidgetsDesktop {
        anchors.fill: parent
        screenName: root.targetScreen ? root.targetScreen.name : ""
        visible: ConfigManager.showDesktopContent && ConfigManager.desktopMode === "widgets"
    }

    // Traditional Desktop (icons grid & rubber-band select)
    TraditionalDesktop {
        anchors.fill: parent
        screenName: root.targetScreen ? root.targetScreen.name : ""
        visible: ConfigManager.showDesktopContent && ConfigManager.desktopMode === "traditional"
    }

    // ----------------------------------------------------
    // 5. BOTTOM-RIGHT BATTERY PILL [🔋 100% ⌄]
    // ----------------------------------------------------
    Rectangle {
        id: battPill
        visible: SystemMonitor.hasBattery
        // Direction via x: runtime-flipped left/right anchors stretch the item.
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.space16
        x: I18n.isRTL ? Theme.space16 : parent.width - width - Theme.space16
        implicitHeight: 28
        implicitWidth: battRow.implicitWidth + 18
        radius: Theme.radiusSmall
        color: battPillMouse.containsMouse ? Theme.colors.surfaceHover : Theme.colors.surfaceElevated
        border.color: battPillMouse.containsMouse ? Theme.colors.borderHighlight : Theme.hairline
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
                font.pixelSize: Theme.fontSize(11)
                font.weight: Font.DemiBold
                color: Theme.colors.text
            }

            Text {
                text: "⌄"
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(11)
                color: Theme.colors.textTertiary
            }
        }

        MouseArea {
            id: battPillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ShellState.toggleQuickSettingsCapsule("main")
        }
    }
}
