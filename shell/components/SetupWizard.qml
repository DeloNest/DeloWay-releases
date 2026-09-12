import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../services"

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

    color: "transparent"

    readonly property bool isActive: (!ConfigManager.setupCompleted || ShellState.setupWizardOpen)

    WlrLayershell.namespace: "deloway:setup-wizard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.isActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    visible: root.isActive || wizardCard.opacity > 0.01

    property int currentStep: 0
    readonly property int totalSteps: 7

    // Full-Screen Dark Acrylic Backdrop (Blocks desktop interaction completely until setup is done)
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Qt.alpha(Theme.colors.background, 0.94)
        opacity: root.isActive ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            // Block all clicks and scroll through to desktop
            onWheel: function(wheel) { wheel.accepted = true; }
        }
    }

    // Centered Fluent Setup Card
    Rectangle {
        id: wizardCard
        anchors.centerIn: parent
        width: Math.min(720, parent.width - 48)
        height: Math.min(560, parent.height - 60)
        radius: Theme.radiusLarge
        color: Theme.colors.surface
        border.color: Theme.colors.borderHighlight
        border.width: 1

        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        opacity: root.isActive ? 1.0 : 0.0
        scale: root.isActive ? 1.0 : 0.94
        transformOrigin: Item.Center
        Behavior on scale { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
        Behavior on opacity { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.space24
            spacing: Theme.space16

            // HEADER: Brand & Progress Indicator
            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Rectangle {
                    width: 44
                    height: 44
                    radius: Theme.radiusMedium
                    color: Theme.colors.primary

                    Grid {
                        anchors.centerIn: parent
                        columns: 2
                        rows: 2
                        spacing: 3

                        Repeater {
                            model: 4
                            Rectangle { width: 8; height: 8; radius: 1.5; color: Theme.textOnPrimary }
                        }
                    }
                }

                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true

                    Text {
                        text: I18n.tr("welcome_deloos")
                        font.family: Theme.typography.fontFamily
                        font.hintingPreference: Theme.hintingPreference
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        renderType: Theme.renderType
                        color: Theme.colors.text
                    }
                    Text {
                        text: I18n.tr("setup_wizard_desc")
                        font.family: Theme.typography.fontFamily
                        font.hintingPreference: Theme.hintingPreference
                        font.pixelSize: 11
                        renderType: Theme.renderType
                        color: Theme.colors.textSecondary
                    }
                }

                // Step Pills
                RowLayout {
                    spacing: 6
                    Repeater {
                        model: root.totalSteps
                        Rectangle {
                            required property int index
                            width: (index === root.currentStep) ? 22 : 8
                            height: 8
                            radius: 4
                            color: (index === root.currentStep) ? Theme.colors.accent : (index < root.currentStep ? Theme.colors.primary : Theme.colors.surfaceHover)
                            Behavior on width { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                            Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.colors.borderSubtle
            }

            // BODY: Step Views Container
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // =============================================================
                // STEP 0: INTERFACE LANGUAGE
                // =============================================================
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 14
                    visible: root.currentStep === 0

                    Text {
                        text: I18n.tr("step_language")
                        font.family: Theme.typography.fontFamily
                        font.hintingPreference: Theme.hintingPreference
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        renderType: Theme.renderType
                        color: Theme.colors.text
                    }

                    Text {
                        text: I18n.tr("step_language_desc")
                        font.family: Theme.typography.fontFamily
                        font.hintingPreference: Theme.hintingPreference
                        font.pixelSize: Theme.typography.scaleCaption.size
                        renderType: Theme.renderType
                        color: Theme.colors.textSecondary
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space16

                        // English Card
                        DeloCard {
                            Layout.fillWidth: true
                            height: 120
                            hoverable: true
                            selected: ConfigManager.uiLanguage === "en"
                            cardRadius: Theme.radiusMedium
                            onClicked: ConfigManager.setUiLanguage("en")

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: Theme.space8

                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    width: 38
                                    height: 28
                                    radius: Theme.radiusSmall
                                    color: ConfigManager.uiLanguage === "en" ? Theme.colors.accent : Theme.colors.surfaceElevated

                                    Text {
                                        anchors.centerIn: parent
                                        text: "EN"
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                        color: ConfigManager.uiLanguage === "en" ? Theme.textOnAccent : Theme.colors.text
                                    }
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "English (United States)"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    renderType: Theme.renderType
                                    color: Theme.colors.text
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Default desktop interface (LTR)"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 11
                                    renderType: Theme.renderType
                                    color: Theme.colors.textSecondary
                                }
                            }
                        }

                        // Arabic Card
                        DeloCard {
                            Layout.fillWidth: true
                            height: 120
                            hoverable: true
                            selected: ConfigManager.uiLanguage === "ar"
                            cardRadius: Theme.radiusMedium
                            onClicked: ConfigManager.setUiLanguage("ar")

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: Theme.space8

                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    width: 38
                                    height: 28
                                    radius: Theme.radiusSmall
                                    color: ConfigManager.uiLanguage === "ar" ? Theme.colors.accent : Theme.colors.surfaceElevated

                                    Text {
                                        anchors.centerIn: parent
                                        text: "ع"
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 14
                                        font.weight: Font.Bold
                                        color: ConfigManager.uiLanguage === "ar" ? Theme.textOnAccent : Theme.colors.text
                                    }
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "العربية (المملكة العربية السعودية)"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    renderType: Theme.renderType
                                    color: Theme.colors.text
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "واجهة سطح مكتب عربية متكاملة (RTL)"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 11
                                    renderType: Theme.renderType
                                    color: Theme.colors.textSecondary
                                }
                            }
                        }
                    }
                }

                // =============================================================
                // STEP 1: THEME & ACCENT COLOR
                // =============================================================
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 14
                    visible: root.currentStep === 1

                    Text {
                        text: I18n.tr("step_theme")
                        font.family: Theme.typography.fontFamily
                        font.hintingPreference: Theme.hintingPreference
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        renderType: Theme.renderType
                        color: Theme.colors.text
                    }

                    Text {
                        text: I18n.tr("step_theme_desc")
                        font.family: Theme.typography.fontFamily
                        font.hintingPreference: Theme.hintingPreference
                        font.pixelSize: Theme.typography.scaleCaption.size
                        renderType: Theme.renderType
                        color: Theme.colors.textSecondary
                    }

                    RowLayout {
                        spacing: Theme.space16

                        // Dark Mode Card
                        DeloCard {
                            width: 170
                            height: 100
                            hoverable: true
                            selected: ConfigManager.themeMode === "dark"
                            cardRadius: Theme.radiusMedium
                            onClicked: ConfigManager.setThemeMode("dark")

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: Theme.space8
                                SymbolicIcon {
                                    Layout.alignment: Qt.AlignHCenter
                                    iconSize: 26
                                    source: "weather-clear-night-symbolic"
                                    iconColor: ConfigManager.themeMode === "dark" ? Theme.colors.accent : Theme.colors.textSecondary
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Dark Mica (Default)"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    renderType: Theme.renderType
                                    color: Theme.colors.text
                                }
                            }
                        }

                        // Light Mode Card
                        DeloCard {
                            width: 170
                            height: 100
                            hoverable: true
                            selected: ConfigManager.themeMode === "light"
                            cardRadius: Theme.radiusMedium
                            onClicked: ConfigManager.setThemeMode("light")

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: Theme.space8
                                SymbolicIcon {
                                    Layout.alignment: Qt.AlignHCenter
                                    iconSize: 26
                                    source: "weather-sunny"
                                    iconColor: ConfigManager.themeMode === "light" ? Theme.colors.accent : Theme.colors.textSecondary
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Light Mode"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    renderType: Theme.renderType
                                    color: Theme.colors.text
                                }
                            }
                        }
                    }

                    Item { Layout.preferredHeight: Theme.space4 }

                    Text {
                        text: "Accent Color Palette"
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.typography.scaleBody.size
                        font.weight: Font.DemiBold
                        renderType: Theme.renderType
                        color: Theme.colors.text
                    }

                    RowLayout {
                        spacing: 12
                        Repeater {
                            model: Theme.accentPaletteOptions

                            delegate: Rectangle {
                                id: colorChip
                                required property var modelData
                                readonly property bool isSelected: ConfigManager.accentColor.toString().toLowerCase() === colorChip.modelData.color.toLowerCase()

                                width: 38
                                height: 38
                                radius: 19
                                color: colorChip.modelData.color
                                border.color: isSelected ? Theme.textOnAccent : "transparent"
                                border.width: isSelected ? 3 : 0
                                scale: chipMouse.containsMouse ? 1.12 : 1.0
                                Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

                                MouseArea {
                                    id: chipMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ConfigManager.setAccentColor(colorChip.modelData.color)
                                }
                            }
                        }
                    }
                }

                // =============================================================
                // STEP 2: DESKTOP EXPERIENCE MODE
                // =============================================================
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 14
                    visible: root.currentStep === 2

                    Text {
                        text: I18n.tr("step_desktop")
                        font.family: Theme.typography.fontFamily
                        font.hintingPreference: Theme.hintingPreference
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        renderType: Theme.renderType
                        color: Theme.colors.text
                    }

                    Text {
                        text: I18n.tr("step_desktop_desc")
                        font.family: Theme.typography.fontFamily
                        font.hintingPreference: Theme.hintingPreference
                        font.pixelSize: Theme.typography.scaleCaption.size
                        renderType: Theme.renderType
                        color: Theme.colors.textSecondary
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        Repeater {
                            model: [
                                { "id": "clean", "title": "Clean", "desc": "Uncluttered wallpaper focus with minimal footprint", "icon": "applications-graphics-symbolic" },
                                { "id": "widgets", "title": "Widgets", "desc": "Live clock, weather, system telemetry, & notes cards", "icon": "preferences-system-symbolic" },
                                { "id": "traditional", "title": "Traditional", "desc": "Standard desktop icon grid with file manager drag & drop", "icon": "user-home-symbolic" }
                            ]

                            delegate: DeloCard {
                                id: dCard
                                required property var modelData
                                readonly property bool isSelected: ConfigManager.desktopMode === dCard.modelData.id

                                Layout.fillWidth: true
                                height: 160
                                hoverable: true
                                selected: isSelected
                                cardRadius: Theme.radiusMedium
                                onClicked: ConfigManager.setDesktopMode(dCard.modelData.id)

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.space16
                                    spacing: 10

                                    SymbolicIcon {
                                        iconSize: 28
                                        source: dCard.modelData.icon
                                        iconColor: dCard.isSelected ? Theme.colors.accent : Theme.colors.textSecondary
                                    }

                                    Text {
                                        text: dCard.modelData.title
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        renderType: Theme.renderType
                                        color: dCard.isSelected ? Theme.colors.accent : Theme.colors.text
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: dCard.modelData.desc
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 11
                                        renderType: Theme.renderType
                                        color: Theme.colors.textSecondary
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }
                        }
                    }
                }

                // =============================================================
                // STEP 3: DOCK & TOP BAR BEHAVIOR
                // =============================================================
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 14
                    visible: root.currentStep === 3

                    Text {
                        text: I18n.tr("step_dock")
                        font.family: Theme.typography.fontFamily
                        font.hintingPreference: Theme.hintingPreference
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        renderType: Theme.renderType
                        color: Theme.colors.text
                    }

                    Text {
                        text: I18n.tr("step_dock_desc")
                        font.family: Theme.typography.fontFamily
                        font.hintingPreference: Theme.hintingPreference
                        font.pixelSize: Theme.typography.scaleCaption.size
                        renderType: Theme.renderType
                        color: Theme.colors.textSecondary
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space16

                        // Dock Auto-Hide Option
                        DeloCard {
                            Layout.fillWidth: true
                            height: 72
                            cardRadius: Theme.radiusMedium

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 12

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        text: "Dock Auto-Hide"
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        renderType: Theme.renderType
                                        color: Theme.colors.text
                                    }
                                    Text {
                                        text: ConfigManager.dockAutoHide ? "Dock slides down when windows overlap" : "Dock is permanently pinned at screen bottom"
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.typography.scaleCaption.size
                                        renderType: Theme.renderType
                                        color: Theme.colors.textSecondary
                                    }
                                }

                                Rectangle {
                                    width: 44
                                    height: 24
                                    radius: 12
                                    color: ConfigManager.dockAutoHide ? Theme.colors.primary : Theme.colors.surfaceHover

                                    Rectangle {
                                        x: ConfigManager.dockAutoHide ? 22 : 2
                                        y: 2
                                        width: 20
                                        height: 20
                                        radius: 10
                                        color: Theme.textOnPrimary
                                        Behavior on x { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: ConfigManager.setDockAutoHide(!ConfigManager.dockAutoHide)
                                    }
                                }
                            }
                        }

                        // Clock Format Option
                        DeloCard {
                            Layout.fillWidth: true
                            height: 72
                            cardRadius: Theme.radiusMedium

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 12

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        text: "Clock Format"
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        renderType: Theme.renderType
                                        color: Theme.colors.text
                                    }
                                    Text {
                                        text: ConfigManager.clockFormat === "24h" ? "24-Hour International (14:30)" : "12-Hour AM/PM (02:30 PM)"
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.typography.scaleCaption.size
                                        renderType: Theme.renderType
                                        color: Theme.colors.textSecondary
                                    }
                                }

                                DeloButton {
                                    implicitWidth: 70
                                    implicitHeight: 28
                                    variant: "secondary"
                                    text: ConfigManager.clockFormat.toUpperCase()
                                    onClicked: ConfigManager.setClockFormat(ConfigManager.clockFormat === "12h" ? "24h" : "12h")
                                }
                            }
                        }
                    }
                }

                // =============================================================
                // STEP 4: RECOMMENDED APPLICATIONS (Section 5)
                // =============================================================
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12
                    visible: root.currentStep === 4

                    Text {
                        text: I18n.tr("step_apps")
                        font.family: Theme.typography.fontFamily
                        font.hintingPreference: Theme.hintingPreference
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        renderType: Theme.renderType
                        color: Theme.colors.text
                    }

                    Text {
                        text: I18n.tr("step_apps_desc")
                        font.family: Theme.typography.fontFamily
                        font.hintingPreference: Theme.hintingPreference
                        font.pixelSize: Theme.typography.scaleCaption.size
                        renderType: Theme.renderType
                        color: Theme.colors.textSecondary
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 10
                        columnSpacing: 12

                        Repeater {
                            model: [
                                {
                                    "id": "thunar",
                                    "name": "Thunar File Manager",
                                    "desc": I18n.locale === "ar" ? "مدير ملفات حديث وخفيف وسريع" : "Modern, fast, and lightweight file manager",
                                    "icon": "system-file-manager"
                                },
                                {
                                    "id": "org.gnome.TextEditor",
                                    "name": "GNOME Text Editor",
                                    "desc": I18n.locale === "ar" ? "محرر نصوص حديث مع تمييز الصيغ" : "Clean, modern text and code editor",
                                    "icon": "text-editor"
                                },
                                {
                                    "id": "pwvucontrol",
                                    "name": "PipeWire Volume Control",
                                    "desc": I18n.locale === "ar" ? "تحكم متقدم في أجهزة وقنوات الصوت" : "Granular PipeWire sound and device mixer",
                                    "icon": "multimedia-volume-control"
                                },
                                {
                                    "id": "io.missioncenter.MissionCenter",
                                    "name": "Mission Center",
                                    "desc": I18n.locale === "ar" ? "مراقب أداء النظام والعتاد في الوقت الفعلي" : "Real-time hardware and resource monitor",
                                    "icon": "utilities-system-monitor"
                                }
                            ]

                            delegate: DeloCard {
                                id: appCard
                                required property var modelData
                                readonly property bool isInstalled: PackageManager.isInstalled(appCard.modelData.id)
                                readonly property bool isInstalling: PackageManager.isInstalling(appCard.modelData.id)
                                readonly property real progress: PackageManager.getInstallProgress(appCard.modelData.id)
                                readonly property string statusText: PackageManager.getInstallStatus(appCard.modelData.id)

                                Layout.fillWidth: true
                                Layout.preferredHeight: 96
                                cardRadius: Theme.radiusMedium
                                selected: appCard.isInstalling
                                selectedBorderColor: Theme.colors.accent

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 6

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 12

                                        AppIcon {
                                            iconSize: 36
                                            source: appCard.modelData.icon
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Text {
                                                text: appCard.modelData.name
                                                font.family: Theme.typography.fontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.DemiBold
                                                renderType: Theme.renderType
                                                color: Theme.colors.text
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: appCard.modelData.desc
                                                font.family: Theme.typography.fontFamily
                                                font.pixelSize: 10
                                                renderType: Theme.renderType
                                                color: Theme.colors.textSecondary
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        // Action Button / Badge
                                        Rectangle {
                                            visible: appCard.isInstalled
                                            implicitWidth: 80
                                            implicitHeight: 28
                                            radius: Theme.radiusSmall
                                            color: Qt.alpha(Theme.colors.success, 0.16)
                                            border.color: Theme.colors.success
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: "✓ " + I18n.tr("installed_btn")
                                                font.family: Theme.typography.fontFamily
                                                font.pixelSize: 10
                                                font.weight: Font.DemiBold
                                                color: Theme.colors.success
                                            }
                                        }

                                        DeloButton {
                                            visible: !appCard.isInstalled
                                            implicitWidth: 80
                                            implicitHeight: 28
                                            variant: "primary"
                                            loading: appCard.isInstalling
                                            text: appCard.isInstalling ? (Math.round(appCard.progress * 100) + "%") : I18n.tr("install_btn")
                                            onClicked: {
                                                PackageManager.installApp(appCard.modelData.id, "native");
                                            }
                                        }
                                    }

                                    // Progress Bar (when installing)
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 3
                                        radius: 1.5
                                        color: Theme.colors.surfaceElevated
                                        visible: appCard.isInstalling

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            width: parent.width * Math.max(0.05, Math.min(1.0, appCard.progress))
                                            radius: 1.5
                                            color: Theme.colors.accent
                                            Behavior on width { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // =============================================================
                // STEP 5: WINDOW MANAGEMENT STYLE
                // =============================================================
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 14
                    visible: root.currentStep === 5

                    Text {
                        text: I18n.tr("step_windows")
                        font.family: Theme.typography.fontFamily
                        font.hintingPreference: Theme.hintingPreference
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        renderType: Theme.renderType
                        color: Theme.colors.text
                    }

                    Text {
                        text: I18n.tr("step_windows_desc")
                        font.family: Theme.typography.fontFamily
                        font.hintingPreference: Theme.hintingPreference
                        font.pixelSize: Theme.typography.scaleCaption.size
                        renderType: Theme.renderType
                        color: Theme.colors.textSecondary
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        Repeater {
                            model: [
                                { "id": "compact", "title": "Compact", "gapsIn": 3, "gapsOut": 6, "rounding": 6, "desc": "Maximum screen space, narrow borders" },
                                { "id": "standard", "title": "Standard (Default)", "gapsIn": 5, "gapsOut": 10, "rounding": 10, "desc": "Optimal balance of aesthetic padding and utility" },
                                { "id": "spacious", "title": "Spacious", "gapsIn": 10, "gapsOut": 18, "rounding": 14, "desc": "Airy, floating aesthetic with generous gaps" }
                            ]

                            delegate: DeloCard {
                                id: styleCard
                                required property var modelData
                                readonly property bool isSelected: ConfigManager.windowGapsIn === styleCard.modelData.gapsIn && ConfigManager.windowRounding === styleCard.modelData.rounding

                                Layout.fillWidth: true
                                height: 140
                                hoverable: true
                                selected: isSelected
                                cardRadius: Theme.radiusMedium
                                onClicked: {
                                    ConfigManager.setWindowGaps(styleCard.modelData.gapsIn, styleCard.modelData.gapsOut);
                                    ConfigManager.setWindowRounding(styleCard.modelData.rounding);
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.space16
                                    spacing: Theme.space8

                                    Text {
                                        text: styleCard.modelData.title
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        renderType: Theme.renderType
                                        color: styleCard.isSelected ? Theme.colors.accent : Theme.colors.text
                                    }

                                    Text {
                                        text: "Gaps: " + styleCard.modelData.gapsIn + "px / " + styleCard.modelData.gapsOut + "px  •  Corner: " + styleCard.modelData.rounding + "px"
                                        font.family: Theme.typography.terminalFont
                                        font.pixelSize: 10
                                        color: Theme.colors.accent
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: styleCard.modelData.desc
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 11
                                        renderType: Theme.renderType
                                        color: Theme.colors.textSecondary
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }
                        }
                    }
                }

                // =============================================================
                // STEP 6: SHORTCUTS & GET STARTED
                // =============================================================
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12
                    visible: root.currentStep === 6

                    Text {
                        text: I18n.tr("step_review")
                        font.family: Theme.typography.fontFamily
                        font.hintingPreference: Theme.hintingPreference
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        renderType: Theme.renderType
                        color: Theme.colors.text
                    }

                    Text {
                        text: I18n.tr("step_review_desc")
                        font.family: Theme.typography.fontFamily
                        font.hintingPreference: Theme.hintingPreference
                        font.pixelSize: Theme.typography.scaleCaption.size
                        renderType: Theme.renderType
                        color: Theme.colors.textSecondary
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 8
                        columnSpacing: 16

                        Repeater {
                            model: [
                                { "key": "SUPER + Return", "desc": "Open Kitty Terminal" },
                                { "key": "SUPER + D / Space", "desc": "Toggle App Drawer & Search" },
                                { "key": "SUPER + I", "desc": "Open DeloOS Settings" },
                                { "key": "SUPER + Shift + S", "desc": "Take Screenshot (Tool Overlay)" },
                                { "key": "SUPER + E", "desc": "Open Thunar File Manager" },
                                { "key": "SUPER + Q", "desc": "Close Active Window" },
                                { "key": "SUPER + L", "desc": "Lock Session Screen" },
                                { "key": "SUPER + Arrows", "desc": "Navigate Tiled Windows" }
                            ]

                            delegate: DeloCard {
                                Layout.fillWidth: true
                                height: 38
                                cardRadius: Theme.radiusSmall
                                surfaceColor: Theme.colors.surfaceVariant
                                borderColor: Theme.colors.borderSubtle

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.space8
                                    spacing: 10

                                    Rectangle {
                                        implicitWidth: keyText.implicitWidth + 12
                                        implicitHeight: 22
                                        radius: 4
                                        color: Theme.colors.surfaceElevated
                                        border.color: Theme.colors.borderHighlight
                                        border.width: 1

                                        Text {
                                            id: keyText
                                            anchors.centerIn: parent
                                            text: modelData.key
                                            font.family: Theme.typography.terminalFont
                                            font.pixelSize: Theme.typography.scaleCaption.size
                                            font.weight: Font.DemiBold
                                            color: Theme.colors.accent
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.desc
                                        font.family: Theme.typography.fontFamily
                                        font.hintingPreference: Theme.hintingPreference
                                        font.pixelSize: 11
                                        renderType: Theme.renderType
                                        color: Theme.colors.text
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.colors.borderSubtle
            }

            // FOOTER: Back & Next / Finish Actions
            RowLayout {
                Layout.fillWidth: true

                // Back Button
                DeloButton {
                    visible: root.currentStep > 0
                    implicitWidth: 100
                    implicitHeight: 38
                    variant: "secondary"
                    text: I18n.tr("back_btn")
                    onClicked: if (root.currentStep > 0) root.currentStep--
                }

                Item { Layout.fillWidth: true }

                // Next or Complete Button
                DeloButton {
                    implicitWidth: 140
                    implicitHeight: 38
                    variant: "primary"
                    text: (root.currentStep < root.totalSteps - 1) ? I18n.tr("next_step") : I18n.tr("finish_start")
                    onClicked: {
                        if (root.currentStep < root.totalSteps - 1) {
                            root.currentStep++;
                        } else {
                            ConfigManager.completeSetup();
                            ShellState.closeSetupWizard();
                        }
                    }
                }
            }
        }
    }
}
