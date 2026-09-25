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
    Connections {
        target: ShellState
        function onSetupWizardStepRequested(step) {
            root.currentStep = Math.max(0, Math.min(root.totalSteps - 1, step));
        }
    }

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
                    color: Theme.colors.surfaceElevated
                    border.color: Theme.colors.borderHighlight
                    border.width: 1

                    Grid {
                        anchors.centerIn: parent
                        columns: 2
                        rows: 2
                        spacing: 3

                        Repeater {
                            model: 4
                            Rectangle { width: 8; height: 8; radius: 1.5; color: Theme.colors.text }
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
                        font.pixelSize: Theme.fontSize(18)
                        font.weight: Font.DemiBold
                        renderType: Theme.renderType
                        color: Theme.colors.text
                    }
                    Text {
                        text: I18n.tr("setup_wizard_desc")
                        font.family: Theme.typography.fontFamily
                        font.hintingPreference: Theme.hintingPreference
                        font.pixelSize: Theme.fontSize(11)
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
                            color: (index === root.currentStep) ? Theme.inverseSurface : (index < root.currentStep ? Theme.colors.borderHighlight : Theme.colors.surfaceHover)
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
                        font.pixelSize: Theme.fontSize(14)
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
                                    color: ConfigManager.uiLanguage === "en" ? Theme.inverseSurface : Theme.colors.surfaceElevated

                                    Text {
                                        anchors.centerIn: parent
                                        text: "EN"
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(12)
                                        font.weight: Font.Bold
                                        color: ConfigManager.uiLanguage === "en" ? Theme.inverseText : Theme.colors.text
                                    }
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "English (United States)"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(13)
                                    font.weight: Font.DemiBold
                                    renderType: Theme.renderType
                                    color: Theme.colors.text
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Default desktop interface (LTR)"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(11)
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
                                    color: ConfigManager.uiLanguage === "ar" ? Theme.inverseSurface : Theme.colors.surfaceElevated

                                    Text {
                                        anchors.centerIn: parent
                                        text: "ع"
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(14)
                                        font.weight: Font.Bold
                                        color: ConfigManager.uiLanguage === "ar" ? Theme.inverseText : Theme.colors.text
                                    }
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "العربية (المملكة العربية السعودية)"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(13)
                                    font.weight: Font.DemiBold
                                    renderType: Theme.renderType
                                    color: Theme.colors.text
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "واجهة سطح مكتب عربية متكاملة (RTL)"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(11)
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
                        font.pixelSize: Theme.fontSize(14)
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
                                    iconColor: ConfigManager.themeMode === "dark" ? Theme.colors.text : Theme.colors.textSecondary
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: I18n.tr("wiz_theme_dark")
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(12)
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
                                    iconColor: ConfigManager.themeMode === "light" ? Theme.colors.text : Theme.colors.textSecondary
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: I18n.tr("wiz_theme_light")
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(12)
                                    font.weight: Font.DemiBold
                                    renderType: Theme.renderType
                                    color: Theme.colors.text
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
                        font.pixelSize: Theme.fontSize(14)
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
                                { "id": "clean", "title": I18n.tr("wiz_desk_clean"), "desc": I18n.tr("wiz_desk_clean_desc"), "icon": "applications-graphics-symbolic" },
                                { "id": "widgets", "title": I18n.tr("wiz_desk_widgets"), "desc": I18n.tr("wiz_desk_widgets_desc"), "icon": "preferences-system-symbolic" },
                                { "id": "traditional", "title": I18n.tr("wiz_desk_traditional"), "desc": I18n.tr("wiz_desk_traditional_desc"), "icon": "user-home-symbolic" }
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
                                        iconColor: dCard.isSelected ? Theme.colors.text : Theme.colors.textSecondary
                                    }

                                    Text {
                                        text: dCard.modelData.title
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(13)
                                        font.weight: Font.DemiBold
                                        renderType: Theme.renderType
                                        color: dCard.isSelected ? Theme.colors.text : Theme.colors.textSecondary
                                    }

                                    Text {
                                        horizontalAlignment: Text.AlignLeft   // reading start (mirrored in Arabic)
                                        Layout.fillWidth: true
                                        text: dCard.modelData.desc
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(11)
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
                        font.pixelSize: Theme.fontSize(14)
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
                                        text: I18n.tr("wiz_dock_autohide")
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(12)
                                        font.weight: Font.DemiBold
                                        renderType: Theme.renderType
                                        color: Theme.colors.text
                                    }
                                    Text {
                                        text: ConfigManager.dockAutoHide ? I18n.tr("wiz_dock_autohide_on") : I18n.tr("wiz_dock_autohide_off")
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
                                    color: ConfigManager.dockAutoHide ? Theme.inverseSurface : Theme.colors.surfaceHover

                                    Rectangle {
                                        // Anchored so "on" is at the reading end (mirrored in Arabic)
                                        anchors.left: parent.left
                                        anchors.leftMargin: ConfigManager.dockAutoHide ? 22 : 2
                                        y: 2
                                        width: 20
                                        height: 20
                                        radius: 10
                                        color: ConfigManager.dockAutoHide ? Theme.inverseText : Theme.colors.text
                                        Behavior on anchors.leftMargin { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
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
                                        text: I18n.tr("wiz_clock_format")
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(12)
                                        font.weight: Font.DemiBold
                                        renderType: Theme.renderType
                                        color: Theme.colors.text
                                    }
                                    Text {
                                        text: ConfigManager.clockFormat === "24h" ? I18n.tr("wiz_clock_24") : I18n.tr("wiz_clock_12")
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
                // STEP 4: DEFAULT APPLICATIONS
                // One real choice per role (DefaultApps: same catalog as install.sh and
                // Settings → Apps). Picking an app that is not installed installs it.
                // =============================================================
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12
                    visible: root.currentStep === 4

                    Text {
                        text: I18n.tr("step_apps")
                        font.family: Theme.typography.fontFamily
                        font.hintingPreference: Theme.hintingPreference
                        font.pixelSize: Theme.fontSize(14)
                        font.weight: Font.DemiBold
                        renderType: Theme.renderType
                        color: Theme.colors.text
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignLeft
                        wrapMode: Text.WordWrap
                        text: I18n.tr("step_apps_desc")
                        font.family: Theme.typography.fontFamily
                        font.hintingPreference: Theme.hintingPreference
                        font.pixelSize: Theme.typography.scaleCaption.size
                        renderType: Theme.renderType
                        color: Theme.colors.textSecondary
                    }

                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentHeight: rolesCol.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: rolesCol
                            width: parent.width
                            spacing: 14

                            Repeater {
                                model: [
                                    { role: "browser",     label: I18n.tr("web_browser") },
                                    { role: "terminal",    label: I18n.tr("terminal_emulator") },
                                    { role: "fileManager", label: I18n.tr("file_manager") },
                                    { role: "editor",      label: I18n.tr("text_editor") },
                                    { role: "monitor",     label: I18n.tr("system_monitor") }
                                ]

                                delegate: ColumnLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignLeft
                                        text: modelData.label
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(12)
                                        font.weight: Font.DemiBold
                                        renderType: Theme.renderType
                                        color: Theme.colors.text
                                    }

                                    DefaultAppChooser {
                                        Layout.fillWidth: true
                                        role: modelData.role
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
                        font.pixelSize: Theme.fontSize(14)
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
                                { "id": "compact", "title": I18n.tr("wiz_win_compact"), "gapsIn": 3, "gapsOut": 6, "rounding": 6, "desc": I18n.tr("wiz_win_compact_desc") },
                                { "id": "standard", "title": I18n.tr("wiz_win_standard"), "gapsIn": 5, "gapsOut": 10, "rounding": 10, "desc": I18n.tr("wiz_win_standard_desc") },
                                { "id": "spacious", "title": I18n.tr("wiz_win_spacious"), "gapsIn": 10, "gapsOut": 18, "rounding": 14, "desc": I18n.tr("wiz_win_spacious_desc") }
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
                                        font.pixelSize: Theme.fontSize(13)
                                        font.weight: Font.DemiBold
                                        renderType: Theme.renderType
                                        color: styleCard.isSelected ? Theme.colors.text : Theme.colors.textSecondary
                                    }

                                    Text {
                                        text: I18n.uiLine(I18n.tr("wiz_win_metrics")
                                              .replace("%1", I18n.ltr(styleCard.modelData.gapsIn + "/" + styleCard.modelData.gapsOut + "px"))
                                              .replace("%2", I18n.ltr(styleCard.modelData.rounding + "px")))
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(10)
                                        color: Theme.colors.textSecondary
                                    }

                                    Text {
                                        horizontalAlignment: Text.AlignLeft   // reading start (mirrored in Arabic)
                                        Layout.fillWidth: true
                                        text: styleCard.modelData.desc
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(11)
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
                        font.pixelSize: Theme.fontSize(14)
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
                                // The real binds (docs/KEYBINDINGS.md); apps follow the defaults chosen above.
                                { "key": "Super", "desc": I18n.tr("wiz_sc_start") },
                                { "key": "Super + Space", "desc": I18n.tr("wiz_sc_search") },
                                { "key": "Super + Return", "desc": I18n.tr("wiz_sc_terminal") },
                                { "key": "Super + E", "desc": I18n.tr("wiz_sc_files") },
                                { "key": "Super + I", "desc": I18n.tr("wiz_sc_settings") },
                                { "key": "Super + Shift + S", "desc": I18n.tr("wiz_sc_screenshot") },
                                { "key": "Super + Q", "desc": I18n.tr("wiz_sc_close") },
                                { "key": "Super + /", "desc": I18n.tr("wiz_sc_all") }
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
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: Theme.typography.scaleCaption.size
                                            font.weight: Font.DemiBold
                                            color: Theme.colors.text
                                        }
                                    }

                                    Text {
                                        horizontalAlignment: Text.AlignLeft   // reading start (mirrored in Arabic)
                                        Layout.fillWidth: true
                                        text: modelData.desc
                                        font.family: Theme.typography.fontFamily
                                        font.hintingPreference: Theme.hintingPreference
                                        font.pixelSize: Theme.fontSize(11)
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
