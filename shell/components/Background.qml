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
    // Keyboard only while a desktop item is being renamed (the inline name field); a
    // layer surface gets none by default, so typing a new name used to do nothing.
    WlrLayershell.keyboardFocus: DesktopManager.editingItemId !== "" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    // ----------------------------------------------------
    // 1. MAIN BACKDROP WALLPAPER (Smooth Crossfade §5.8)
    // ----------------------------------------------------
    Item {
        id: wallpaperCrossfade
        anchors.fill: parent

        readonly property string bundled: "file://" + ConfigManager.projectDir + "/assets/wallpapers/01-noir-gradient.jpeg"
        readonly property string configured: (ConfigManager.wallpaper && ConfigManager.wallpaper.length > 0)
                ? ConfigManager.fileUrl(ConfigManager.wallpaper)
                : ""
        property bool configuredFailed: false
        onConfiguredChanged: configuredFailed = false

        readonly property string targetSource: (configured.length > 0 && !configuredFailed) ? configured : bundled

        property bool activeIsA: true
        property string currentSource: ""
        property string pendingSource: ""

        function handleSourceChange() {
            var target = targetSource;
            if (!target || target.length === 0) return;
            if (target === currentSource && (activeIsA ? layerA.status === Image.Ready : layerB.status === Image.Ready)) {
                return;
            }

            if (currentSource === "") {
                currentSource = target;
                layerA.source = target;
                layerA.opacity = 1.0;
                layerA.z = 0;
                layerB.opacity = 0.0;
                layerB.z = 1;
                layerB.source = "";
                return;
            }

            if (fadeAnim.running) {
                return; // Will be picked up in onFinished
            }

            pendingSource = target;
            var incoming = activeIsA ? layerB : layerA;
            incoming.z = 1;
            incoming.opacity = 0.0;
            incoming.source = target;
            if (incoming.status === Image.Ready && !fadeAnim.running) {
                fadeAnim.start();
            }
        }

        onTargetSourceChanged: handleSourceChange()
        Component.onCompleted: handleSourceChange()

        NumberAnimation {
            id: fadeAnim
            target: wallpaperCrossfade.activeIsA ? layerB : layerA
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: Theme.motionWallpaperFade
            easing.type: Theme.easingWallpaper
            onFinished: {
                wallpaperCrossfade.activeIsA = !wallpaperCrossfade.activeIsA;
                wallpaperCrossfade.currentSource = wallpaperCrossfade.pendingSource;
                if (wallpaperCrossfade.activeIsA) {
                    layerA.z = 0;
                    layerB.source = "";
                    layerB.opacity = 0.0;
                    layerB.z = 1;
                } else {
                    layerB.z = 0;
                    layerA.source = "";
                    layerA.opacity = 0.0;
                    layerA.z = 1;
                }
                if (wallpaperCrossfade.targetSource !== wallpaperCrossfade.currentSource) {
                    wallpaperCrossfade.handleSourceChange();
                }
            }
        }

        Image {
            id: layerA
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: Math.round(width * Screen.devicePixelRatio)
            sourceSize.height: Math.round(height * Screen.devicePixelRatio)
            cache: false
            asynchronous: true
            opacity: 1.0
            z: 0
            onStatusChanged: {
                if (status === Image.Ready && !wallpaperCrossfade.activeIsA && wallpaperCrossfade.pendingSource === source.toString()) {
                    if (!fadeAnim.running) fadeAnim.start();
                } else if (status === Image.Error && source.toString() === wallpaperCrossfade.configured) {
                    wallpaperCrossfade.configuredFailed = true;
                }
            }
        }

        Image {
            id: layerB
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: Math.round(width * Screen.devicePixelRatio)
            sourceSize.height: Math.round(height * Screen.devicePixelRatio)
            cache: false
            asynchronous: true
            opacity: 0.0
            z: 1
            onStatusChanged: {
                if (status === Image.Ready && wallpaperCrossfade.activeIsA && wallpaperCrossfade.pendingSource === source.toString()) {
                    if (!fadeAnim.running) fadeAnim.start();
                } else if (status === Image.Error && source.toString() === wallpaperCrossfade.configured) {
                    wallpaperCrossfade.configuredFailed = true;
                }
            }
        }

        // Dark Mica Calm Overlay
        Rectangle {
            anchors.fill: parent
            color: Theme.wallpaperTint
            z: 10
            Behavior on color { ColorAnimation { duration: Theme.motionThemeFade; easing.type: Theme.easingTheme } }
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
