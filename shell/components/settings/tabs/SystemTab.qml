import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../theme"
import "../../../services"
import "../common"

Item {
    id: root

    implicitWidth: 500
    implicitHeight: mainCol.implicitHeight + (Theme.space24 * 2)
    width: parent ? parent.width : implicitWidth
    height: implicitHeight
    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    property string osKernel: ""
    property string osHostname: ""
    property bool confirmReset: false

    Component.onCompleted: {
        sysInfoProc.running = true;
    }

    onVisibleChanged: {
        if (visible) {
            sysInfoProc.running = true;
            root.confirmReset = false;
        }
    }

    // Process to fetch kernel and hostname
    Process {
        id: sysInfoProc
        command: ["sh", "-c", "echo \"$(uname -r)|$(uname -n)\""]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split("|");
                if (parts.length >= 2) {
                    root.osKernel = parts[0];
                    root.osHostname = parts[1];
                }
            }
        }
    }

    ColumnLayout {
        id: mainCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.space24
        spacing: Theme.space24
        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        // ── 1. Localization & Language ───────────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "اللغة والإدخال" : "Language & Input"

            SettingsRow {
                title: I18n.tr("ui_language_title")
                subtitle: I18n.tr("ui_language_desc")
                icon: "preferences-desktop-locale-symbolic"
                showDivider: false

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [
                            { id: "ar", label: "العربية" },
                            { id: "en", label: "English" }
                        ]
                        delegate: Rectangle {
                            id: langPill
                            required property var modelData
                            readonly property bool isSelected: (ConfigManager.uiLanguage || "ar") === modelData.id

                            height: 28
                            implicitWidth: langText.implicitWidth + Theme.space16
                            radius: 14
                            color: langPill.isSelected ? Theme.notchSurfaceActive : (langMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: langPill.isSelected ? Theme.notchBorderHighlight : (langMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                id: langText
                                anchors.centerIn: parent
                                text: langPill.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: langPill.isSelected ? Font.DemiBold : Font.Normal
                                color: langPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: langMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConfigManager.setUiLanguage(langPill.modelData.id)
                            }
                        }
                    }
                }
            }
        }

        // ── 2. Power & Performance ───────────────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "نمط الطاقة" : "Power Profile"

            SettingsRow {
                title: I18n.isRTL ? "وضع استهلاك الطاقة" : "Power Management Profile"
                subtitle: I18n.isRTL ? "الموازنة بين أداء المعالج وسرعة النظام وعمر البطارية" : "Balance CPU throughput, system responsiveness, and battery life"
                icon: "power-profile-balanced-symbolic"
                showDivider: false

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [
                            { id: "power-saver", label: I18n.isRTL ? "توفير الطاقة" : "Saver" },
                            { id: "balanced",    label: I18n.isRTL ? "متوازن" : "Balanced" },
                            { id: "performance", label: I18n.isRTL ? "أداء فائق" : "Performance" }
                        ]
                        delegate: Rectangle {
                            id: pwrPill
                            required property var modelData
                            readonly property bool isSelected: (ConfigManager.powerProfile || "balanced") === modelData.id

                            height: 28
                            implicitWidth: pwrText.implicitWidth + Theme.space16
                            radius: 14
                            color: pwrPill.isSelected ? Theme.notchSurfaceActive : (pwrMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: pwrPill.isSelected ? Theme.notchBorderHighlight : (pwrMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                id: pwrText
                                anchors.centerIn: parent
                                text: pwrPill.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: pwrPill.isSelected ? Font.DemiBold : Font.Normal
                                color: pwrPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: pwrMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ConfigManager.powerProfile = pwrPill.modelData.id;
                                    ConfigManager.saveConfig();
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── 3. Default Applications ──────────────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "التطبيقات الافتراضية" : "Default Applications"

            // Default Browser
            SettingsRow {
                title: I18n.tr("web_browser")
                subtitle: ConfigManager.defaultBrowser || "Brave Browser"
                icon: "applications-internet-symbolic"
                showDivider: true

                Text {
                    text: ConfigManager.defaultBrowser || "brave"
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(11)
                    color: Theme.notchTextSecondary
                }
            }

            // Default Terminal
            SettingsRow {
                title: I18n.tr("terminal_emulator")
                subtitle: ConfigManager.defaultTerminal || "Kitty"
                icon: "utilities-terminal-symbolic"
                showDivider: true

                Text {
                    text: ConfigManager.defaultTerminal || "kitty"
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(11)
                    color: Theme.notchTextSecondary
                }
            }

            // Default File Manager
            SettingsRow {
                title: I18n.tr("file_manager")
                subtitle: ConfigManager.defaultFileManager || "Thunar"
                icon: "system-file-manager-symbolic"
                showDivider: false

                Text {
                    text: ConfigManager.defaultFileManager || "thunar"
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(11)
                    color: Theme.notchTextSecondary
                }
            }
        }

        // ── 4. About DeloWay Shell & System ──────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "حول النظام وشل DeloWay" : "About System & DeloWay"

            SettingsRow {
                title: "DeloWay Desktop Shell"
                subtitle: (I18n.isRTL ? "نواة لينكس: " : "Linux Kernel: ") + (root.osKernel || "Arch Linux") + " • " + (root.osHostname || "localhost")
                icon: "distributor-logo-symbolic"
                showDivider: true

                Rectangle {
                    height: 24
                    implicitWidth: verText.implicitWidth + 16
                    radius: 12
                    color: Theme.notchSurfaceActive
                    border.color: Theme.notchBorderHighlight
                    border.width: 1

                    Text {
                        id: verText
                        anchors.centerIn: parent
                        text: "v2.0 OLED"
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(10)
                        font.weight: Font.DemiBold
                        color: Theme.notchText
                    }
                }
            }

            // Keyboard Shortcuts Cheat Sheet Launcher
            SettingsRow {
                title: I18n.isRTL ? "دليل اختصارات لوحة المفاتيح" : "Keyboard Shortcuts Cheat Sheet"
                subtitle: I18n.isRTL ? "استعراض كافة اختصارات النظام ومجموعات المفاتيح (Super + ?)" : "View all desktop keybindings and commands (Super + ?)"
                icon: "preferences-desktop-keyboard-shortcuts-symbolic"
                showDivider: false
                clickable: true
                onClicked: ShellState.toggleCheatSheet()

                Rectangle {
                    height: 28
                    implicitWidth: csBtnText.implicitWidth + Theme.space24
                    radius: 14
                    color: csMa.pressed ? Theme.notchSurfaceActive : (csMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceElevated)
                    border.color: csMa.containsMouse ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                    Text {
                        id: csBtnText
                        anchors.centerIn: parent
                        text: I18n.isRTL ? "فتح الدليل" : "Open Guide"
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(11)
                        font.weight: Font.DemiBold
                        color: csMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                    }

                    MouseArea {
                        id: csMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ShellState.toggleCheatSheet()
                    }
                }
            }
        }

        // ── 5. Advanced Settings (Collapsible) ────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "إعدادات متقدمة (Advanced)" : "Advanced Settings"
            collapsible: true
            isExpanded: false

            // Screen Sleep Timeout
            SettingsRow {
                title: I18n.isRTL ? "مهلة سكون الشاشة" : "Screen Sleep Timeout"
                subtitle: I18n.isRTL ? "إيقاف تشغيل الشاشات تلقائياً عند انعدام النشاط" : "Automatically turn off displays when idle"
                icon: "preferences-system-time-symbolic"
                showDivider: true

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [
                            { min: 15, label: I18n.isRTL ? "15 دقيقة" : "15m" },
                            { min: 30, label: I18n.isRTL ? "30 دقيقة" : "30m" },
                            { min: 60, label: I18n.isRTL ? "ساعة" : "1h" },
                            { min: 0,  label: I18n.isRTL ? "مطلقاً" : "Never" }
                        ]
                        delegate: Rectangle {
                            id: slpPill
                            required property var modelData
                            readonly property bool isSelected: (ConfigManager.sleepTimeout !== undefined ? ConfigManager.sleepTimeout : 30) === modelData.min

                            height: 28
                            implicitWidth: slpText.implicitWidth + Theme.space16
                            radius: 14
                            color: slpPill.isSelected ? Theme.notchSurfaceActive : (slpMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: slpPill.isSelected ? Theme.notchBorderHighlight : (slpMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                id: slpText
                                anchors.centerIn: parent
                                text: slpPill.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: slpPill.isSelected ? Font.DemiBold : Font.Normal
                                color: slpPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: slpMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ConfigManager.sleepTimeout = slpPill.modelData.min;
                                    ConfigManager.saveConfig();
                                }
                            }
                        }
                    }
                }
            }

            // Dangerous Action: Factory Reset
            SettingsRow {
                title: I18n.isRTL ? "إعادة ضبط إعدادات DeloWay" : "Reset DeloWay Settings"
                subtitle: root.confirmReset
                    ? (I18n.isRTL ? "هل أنت متأكد؟ سيتم استعادة كافة الإعدادات إلى قيم المصنع" : "Are you sure? All user settings will be reverted to defaults")
                    : (I18n.isRTL ? "استعادة كافة خيارات السمة والشريط والنوافذ للافتراضي" : "Revert all theme, dock, and window options to defaults")
                icon: "dialog-warning-symbolic"
                iconColor: Theme.colors.urgent
                showDivider: false

                RowLayout {
                    spacing: Theme.space8
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    // Cancel confirmation if active
                    Rectangle {
                        visible: root.confirmReset
                        height: 28
                        implicitWidth: cancelText.implicitWidth + Theme.space16
                        radius: 14
                        color: cancelMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceElevated
                        border.color: Theme.notchBorderSubtle
                        border.width: 1

                        Text {
                            id: cancelText
                            anchors.centerIn: parent
                            text: I18n.isRTL ? "إلغاء" : "Cancel"
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            color: Theme.notchTextSecondary
                        }

                        MouseArea {
                            id: cancelMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.confirmReset = false
                        }
                    }

                    // Reset / Confirm Button
                    Rectangle {
                        height: 28
                        implicitWidth: resetBtnText.implicitWidth + Theme.space24
                        radius: 14
                        color: root.confirmReset
                            ? (resetMa.pressed ? Qt.rgba(0.9, 0.2, 0.2, 0.4) : Qt.rgba(0.9, 0.2, 0.2, 0.2))
                            : (resetMa.pressed ? Theme.notchSurfaceActive : (resetMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceElevated))
                        border.color: root.confirmReset ? Theme.colors.urgent : (resetMa.containsMouse ? Theme.notchBorderHighlight : Theme.notchBorderSubtle)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                        Text {
                            id: resetBtnText
                            anchors.centerIn: parent
                            text: root.confirmReset ? (I18n.isRTL ? "تأكيد الاستعادة" : "Confirm Reset") : (I18n.isRTL ? "استعادة الافتراضي" : "Reset to Defaults")
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            font.weight: Font.DemiBold
                            color: root.confirmReset ? Theme.colors.urgent : (resetMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary)
                        }

                        MouseArea {
                            id: resetMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!root.confirmReset) {
                                    root.confirmReset = true;
                                } else {
                                    // Reset settings
                                    ConfigManager.themeMode = "dark";
                                    ConfigManager.fontSizeScale = 1.0;
                                    ConfigManager.elementRadius = 8;
                                    ConfigManager.performanceTier = 1;
                                    ConfigManager.dockMode = "always";
                                    ConfigManager.dockPosition = "bottom";
                                    ConfigManager.dockIconSize = 44;
                                    ConfigManager.windowGapsIn = 6;
                                    ConfigManager.windowGapsOut = 10;
                                    ConfigManager.followMouse = true;
                                    ConfigManager.dimInactive = false;
                                    ConfigManager.notificationsDnd = false;
                                    ConfigManager.notificationsSound = false;
                                    ConfigManager.notificationsTimeout = 5000;
                                    ConfigManager.saveConfig();
                                    root.confirmReset = false;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
