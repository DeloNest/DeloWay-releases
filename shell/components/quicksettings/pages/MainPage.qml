import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../services"
import "../.."
import ".."

// MainPage — control-center home.
//   Header  : avatar · user@host ··· [screenshot] [settings] [lock] [power ›]
//   Tiles   : 2-column split tiles (toggle + details)
//   Sliders : volume (› outputs) · microphone · brightness
ColumnLayout {
    id: root

    required property var qs        // QuickSettingsCapsule (owns audio/brightness/night-light backends)
    spacing: 12

    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    readonly property bool rtl: I18n.isRTL
    function t(ar, en) { return root.rtl ? ar : en; }
    function go(view) { ShellState.quickSettingsCapsuleView = view; }

    // ── Header ───────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Rectangle {
            implicitWidth: 36
            implicitHeight: 36
            radius: 18
            color: Theme.qsTileActive
            Text {
                anchors.centerIn: parent
                text: (ControlCenterService.userName.charAt(0) || "?").toUpperCase()
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(15)
                font.weight: Font.Bold
                color: Theme.qsTileIconActive
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: -2
            Text {
                Layout.fillWidth: true
                text: ControlCenterService.userName
                horizontalAlignment: Text.AlignLeft
                elide: Text.ElideRight
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(13)
                font.weight: Font.Bold
                color: Theme.notchText
                renderType: Theme.renderType
            }
            Text {
                Layout.fillWidth: true
                text: ControlCenterService.hostName
                horizontalAlignment: Text.AlignLeft
                elide: Text.ElideRight
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(10)
                color: Theme.notchTextTertiary
                renderType: Theme.renderType
            }
        }

        QSIconButton {
            iconName: "applets-screenshooter-symbolic"
            onClicked: { ShellState.closeQuickSettingsCapsule(); ShellState.openScreenshot(); }
        }
        QSIconButton {
            iconName: "emblem-system-symbolic"
            onClicked: { ShellState.closeQuickSettingsCapsule(); ShellState.openSettingsApp(); }
        }
        QSIconButton {
            iconName: "system-lock-screen-symbolic"
            onClicked: ShellState.lock()
        }
        QSIconButton {
            iconName: "system-shutdown-symbolic"
            onClicked: root.go("power")
        }
    }

    // ── Toggles ──────────────────────────────────────────────────────────
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        rowSpacing: 8
        columnSpacing: 8

        QSTile {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            title: "Wi-Fi"
            iconName: root.qs.wifiEnabled ? "network-wireless-symbolic" : "network-wireless-disabled-symbolic"
            active: root.qs.wifiEnabled
            available: root.qs.wifiAvailable || NetworkService.ethernetConnected
            busy: NetworkService.connectingSsid.length > 0
            hasDetails: true
            subtitle: !root.qs.wifiAvailable
                      ? (NetworkService.ethernetConnected ? root.t("سلكي · متصل", "Wired · Connected") : root.t("غير متوفر", "Unavailable"))
                      : (!root.qs.wifiEnabled ? root.t("متوقف", "Off")
                         : (root.qs.wifiSsid || (NetworkService.ethernetConnected ? root.t("سلكي · متصل", "Wired · Connected") : root.t("غير متصل", "Not connected"))))
            onToggled: root.qs.toggleWifi()
            onDetailsRequested: root.go("wifi")
        }

        QSTile {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            title: root.t("بلوتوث", "Bluetooth")
            iconName: root.qs.bluetoothEnabled ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic"
            active: root.qs.bluetoothEnabled
            available: BluetoothService.available
            busy: BluetoothService.connectingAddress.length > 0
            hasDetails: true
            subtitle: !root.qs.bluetoothEnabled ? root.t("متوقف", "Off")
                      : (root.qs.bluetoothConnectedDevice || root.t("لا يوجد جهاز", "No device"))
            onToggled: root.qs.toggleBluetooth()
            onDetailsRequested: root.go("bluetooth")
        }

        QSTile {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            title: root.t("نقطة اتصال", "Hotspot")
            iconName: "network-wireless-hotspot-symbolic"
            active: root.qs.hotspotEnabled
            available: root.qs.hotspotAvailable
            busy: NetworkService.hotspotActionRunning
            hasDetails: true
            subtitle: root.qs.hotspotEnabled
                      ? (root.qs.hotspotClients.length > 0
                         ? root.t(root.qs.hotspotClients.length + " متصل", root.qs.hotspotClients.length + " connected")
                         : root.qs.hotspotSsid)
                      : root.t("متوقفة", "Off")
            onToggled: root.qs.toggleHotspot()
            onDetailsRequested: root.go("hotspot")
        }

        QSTile {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            title: root.t("عدم الإزعاج", "Do Not Disturb")
            iconName: ConfigManager.notificationsDnd ? "notifications-disabled-symbolic" : "preferences-system-notifications-symbolic"
            active: ConfigManager.notificationsDnd
            subtitle: ConfigManager.notificationsDnd ? root.t("مفعّل", "On") : root.t("متوقف", "Off")
            onToggled: ConfigManager.setNotificationsDnd(!ConfigManager.notificationsDnd)
        }

        QSTile {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            title: root.t("الإضاءة الليلية", "Night Light")
            iconName: "night-light-symbolic"
            active: root.qs.nightLightEnabled
            subtitle: root.qs.nightLightEnabled ? "4500K" : root.t("متوقفة", "Off")
            onToggled: root.qs.toggleNightLight()
        }

        QSTile {
            visible: ControlCenterService.showAirplaneToggle
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            title: root.t("وضع الطيران", "Airplane Mode")
            iconName: "airplane-mode-symbolic"
            active: ControlCenterService.airplaneMode
            available: ControlCenterService.airplaneAvailable
            subtitle: ControlCenterService.airplaneMode ? root.t("مفعّل", "On") : root.t("متوقف", "Off")
            onToggled: ControlCenterService.setAirplaneMode(!ControlCenterService.airplaneMode)
        }

        QSTile {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            title: root.t("الوضع الداكن", "Dark Mode")
            iconName: Theme.isDark ? "weather-clear-night-symbolic" : "weather-clear-symbolic"
            active: Theme.isDark
            subtitle: Theme.isDark ? root.t("داكن", "Dark") : root.t("فاتح", "Light")
            onToggled: ConfigManager.setThemeMode(Theme.isDark ? "light" : "dark")
        }

        QSTile {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            title: root.t("إبقاء الشاشة", "Keep Awake")
            iconName: "caffeine-cup-full-symbolic"
            active: ControlCenterService.keepAwake
            subtitle: ControlCenterService.keepAwake ? root.t("لن يدخل السكون", "Sleep blocked") : root.t("متوقف", "Off")
            onToggled: ControlCenterService.keepAwake = !ControlCenterService.keepAwake
        }

        QSTile {
            visible: ControlCenterService.powerProfilesAvailable
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            title: root.t("وضع الطاقة", "Power Mode")
            iconName: "power-profile-" + (ControlCenterService.powerProfile || "balanced") + "-symbolic"
            active: ControlCenterService.powerProfile === "performance"
            subtitle: ({ "power-saver": root.t("توفير", "Saver"),
                         "balanced": root.t("متوازن", "Balanced"),
                         "performance": root.t("أداء", "Performance") })[ControlCenterService.powerProfile] || ""
            onToggled: ControlCenterService.cyclePowerProfile()
        }
    }

    // ── Sliders ──────────────────────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: sliders.implicitHeight + 20
        radius: Theme.qsCardRadius
        color: Theme.qsTileBackground
        border.color: Theme.qsTileBorder
        border.width: 1

        ColumnLayout {
            id: sliders
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            QSSlider {
                Layout.fillWidth: true
                iconName: root.qs.volumeIconName + "-symbolic"
                value: root.qs.currentVolume
                muted: root.qs.isMuted
                enabledControl: root.qs.audioSink !== null
                hasDetails: true
                onMoved: (v) => root.qs.setVolume(v)
                onIconClicked: root.qs.toggleMute()
                onDetailsRequested: root.go("audio")
            }

            QSSlider {
                Layout.fillWidth: true
                visible: root.qs.brightnessBackend !== "none"
                iconName: "display-brightness-symbolic"
                value: root.qs.screenBrightness
                onMoved: (v) => root.qs.setBrightness(v)
            }
        }
    }
}
