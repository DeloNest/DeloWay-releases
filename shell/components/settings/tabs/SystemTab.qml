import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../../theme"
import "../../../services"
import "../common"
import "../../"

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
                showDivider: true

                Text {
                    text: ConfigManager.defaultFileManager || "thunar"
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(11)
                    color: Theme.notchTextSecondary
                }
            }

            // Preferred Music Player
            SettingsRow {
                title: I18n.isRTL ? "مشغّل الموسيقى المفضّل" : "Preferred Music Player"
                subtitle: I18n.isRTL ? "المشغّل المعروض عند تعدد المشغّلات النشطة (افتراضي: الأحدث)" : "Player prioritized when multiple players are active (default: latest)"
                icon: "applications-multimedia-symbolic"
                showDivider: true

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: {
                            var list = [{ id: "auto", label: I18n.isRTL ? "تلقائي (الأحدث)" : "Auto (Latest)" }];
                            var seen = new Set(["auto"]);
                            var current = ConfigManager.musicPreferredPlayer || "auto";

                            if (Mpris.players && Mpris.players.values) {
                                for (var i = 0; i < Mpris.players.values.length; i++) {
                                    var p = Mpris.players.values[i];
                                    if (!p) continue;
                                    var pId = (p.desktopEntry || p.identity || "").toLowerCase().replace(/\.desktop$/, "");
                                    if (!pId || seen.has(pId)) continue;
                                    seen.add(pId);
                                    list.push({ id: pId, label: p.identity || p.desktopEntry || pId });
                                }
                            }

                            if (current !== "auto" && !seen.has(current.toLowerCase().replace(/\.desktop$/, ""))) {
                                var cleanCur = current.toLowerCase().replace(/\.desktop$/, "");
                                seen.add(cleanCur);
                                list.push({ id: cleanCur, label: cleanCur });
                            }

                            return list;
                        }

                        delegate: Rectangle {
                            id: playerPill
                            required property var modelData
                            readonly property bool isSelected: (ConfigManager.musicPreferredPlayer || "auto") === modelData.id

                            height: 28
                            implicitWidth: playerText.implicitWidth + Theme.space16
                            radius: 14
                            color: playerPill.isSelected ? Theme.notchSurfaceActive : (playerMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: playerPill.isSelected ? Theme.notchBorderHighlight : (playerMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                id: playerText
                                anchors.centerIn: parent
                                text: playerPill.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: playerPill.isSelected ? Font.DemiBold : Font.Normal
                                color: playerPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: playerMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConfigManager.setMusicPreferredPlayer(playerPill.modelData.id)
                            }
                        }
                    }
                }
            }

            // Music Launch Target
            SettingsRow {
                title: I18n.isRTL ? "هدف تشغيل الموسيقى" : "Music Launch Target"
                subtitle: I18n.isRTL ? "التطبيق أو الرابط الذي يُفتح عند النقر على ودجت الموسيقى الخامل" : "Application or URL opened when clicking idle music widget"
                icon: "media-optical-audio-symbolic"
                showDivider: false

                ColumnLayout {
                    spacing: Theme.space8
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    // Target Type selector (App vs URL)
                    RowLayout {
                        spacing: Theme.space4
                        LayoutMirroring.enabled: I18n.isRTL
                        LayoutMirroring.childrenInherit: true

                        Repeater {
                            model: [
                                { id: "app", label: I18n.isRTL ? "تطبيق" : "Application" },
                                { id: "url", label: I18n.isRTL ? "رابط ويب" : "Web URL" }
                            ]
                            delegate: Rectangle {
                                id: typePill
                                required property var modelData
                                readonly property bool isSelected: ((ConfigManager.musicLaunchTarget && ConfigManager.musicLaunchTarget.type) || "app") === modelData.id

                                height: 26
                                implicitWidth: typeText.implicitWidth + Theme.space16
                                radius: 13
                                color: typePill.isSelected ? Theme.notchSurfaceActive : (typeMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                                border.color: typePill.isSelected ? Theme.notchBorderHighlight : (typeMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                                Text {
                                    id: typeText
                                    anchors.centerIn: parent
                                    text: typePill.modelData.label
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(11)
                                    font.weight: typePill.isSelected ? Font.DemiBold : Font.Normal
                                    color: typePill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                                }

                                MouseArea {
                                    id: typeMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var cur = Object.assign({}, ConfigManager.musicLaunchTarget || {});
                                        cur.type = typePill.modelData.id;
                                        if (cur.type === "url" && (!cur.value || cur.value.length < 5)) {
                                            cur.value = "https://music.youtube.com";
                                        }
                                        ConfigManager.setMusicLaunchTarget(cur);
                                    }
                                }
                            }
                        }
                    }

                    // Value selector depending on type
                    RowLayout {
                        spacing: Theme.space8
                        LayoutMirroring.enabled: I18n.isRTL
                        LayoutMirroring.childrenInherit: true

                        // If App: show quick buttons for installed players + custom text field
                        RowLayout {
                            visible: ((ConfigManager.musicLaunchTarget && ConfigManager.musicLaunchTarget.type) || "app") === "app"
                            spacing: Theme.space4

                            Repeater {
                                model: [
                                    { id: "spotify", label: "Spotify" },
                                    { id: "com.pocoguy.Muse", label: "Muse" },
                                    { id: "io.github.celluloid_player.Celluloid", label: "Celluloid" },
                                    { id: "mpv", label: "MPV" }
                                ]
                                delegate: Rectangle {
                                    id: appPill
                                    required property var modelData
                                    readonly property bool isSelected: ((ConfigManager.musicLaunchTarget && ConfigManager.musicLaunchTarget.value) || "spotify") === modelData.id
                                    readonly property bool isInstalled: ApplicationManager.isInstalled(modelData.id)

                                    visible: isInstalled || modelData.id === "spotify"
                                    height: 26
                                    implicitWidth: appText.implicitWidth + Theme.space12
                                    radius: 13
                                    color: appPill.isSelected ? Theme.notchSurfaceActive : (appMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                                    border.color: appPill.isSelected ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                                    border.width: 1

                                    Text {
                                        id: appText
                                        anchors.centerIn: parent
                                        text: appPill.modelData.label
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(10)
                                        font.weight: appPill.isSelected ? Font.DemiBold : Font.Normal
                                        color: appPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                                    }

                                    MouseArea {
                                        id: appMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var cur = Object.assign({}, ConfigManager.musicLaunchTarget || {});
                                            cur.type = "app";
                                            cur.value = appPill.modelData.id;
                                            ConfigManager.setMusicLaunchTarget(cur);
                                        }
                                    }
                                }
                            }

                            DeloTextField {
                                id: customAppInput
                                implicitWidth: 140
                                implicitHeight: 28
                                fontPixelSize: Theme.fontSize(11)
                                placeholderText: I18n.isRTL ? "أو اسم التطبيق..." : "or app ID..."
                                text: {
                                    var val = (ConfigManager.musicLaunchTarget && ConfigManager.musicLaunchTarget.value) || "";
                                    if (val === "spotify" || val === "com.pocoguy.Muse" || val === "io.github.celluloid_player.Celluloid" || val === "mpv") return "";
                                    return val;
                                }
                                onAccepted: {
                                    if (text.trim().length > 0) {
                                        var cur = Object.assign({}, ConfigManager.musicLaunchTarget || {});
                                        cur.type = "app";
                                        cur.value = text.trim();
                                        ConfigManager.setMusicLaunchTarget(cur);
                                    }
                                }
                            }
                        }

                        // If URL: show URL text input + webApp checkbox
                        RowLayout {
                            visible: (ConfigManager.musicLaunchTarget && ConfigManager.musicLaunchTarget.type) === "url"
                            spacing: Theme.space8

                            DeloTextField {
                                id: urlInput
                                implicitWidth: 220
                                implicitHeight: 28
                                fontPixelSize: Theme.fontSize(11)
                                placeholderText: "https://music.youtube.com"
                                text: (ConfigManager.musicLaunchTarget && ConfigManager.musicLaunchTarget.value) || "https://music.youtube.com"
                                onAccepted: {
                                    var cur = Object.assign({}, ConfigManager.musicLaunchTarget || {});
                                    cur.type = "url";
                                    cur.value = text.trim() || "https://music.youtube.com";
                                    ConfigManager.setMusicLaunchTarget(cur);
                                }
                            }

                            Rectangle {
                                id: webAppToggle
                                height: 26
                                implicitWidth: webAppText.implicitWidth + Theme.space16
                                radius: 13
                                readonly property bool isEnabled: (ConfigManager.musicLaunchTarget && ConfigManager.musicLaunchTarget.webApp) === true
                                color: isEnabled ? Theme.notchSurfaceActive : (webAppMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                                border.color: isEnabled ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                                border.width: 1

                                Text {
                                    id: webAppText
                                    anchors.centerIn: parent
                                    text: I18n.isRTL ? "تطبيق مستقل (--app)" : "Web App (--app)"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(10)
                                    font.weight: webAppToggle.isEnabled ? Font.DemiBold : Font.Normal
                                    color: webAppToggle.isEnabled ? Theme.notchText : Theme.notchTextSecondary
                                }

                                MouseArea {
                                    id: webAppMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var cur = Object.assign({}, ConfigManager.musicLaunchTarget || {});
                                        cur.type = "url";
                                        cur.webApp = !cur.webApp;
                                        ConfigManager.setMusicLaunchTarget(cur);
                                    }
                                }
                            }
                        }
                    }
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
