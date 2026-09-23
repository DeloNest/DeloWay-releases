// Apps — app details (App Info), default applications and music player behaviour.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
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
    property string realBrowser: ""
    property string realFileManager: ""

    Component.onCompleted: {
        sysInfoProc.running = true;
        defaultAppsSyncProc.running = true;
    }

    onVisibleChanged: {
        if (visible) {
            sysInfoProc.running = true;
            defaultAppsSyncProc.running = true;
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

    // Process to sync real system defaults from xdg-settings / xdg-mime
    Process {
        id: defaultAppsSyncProc
        command: ["sh", "-c", "echo \"$(xdg-settings get default-web-browser)|$(xdg-mime query default inode/directory)\""]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split("|");
                if (parts.length >= 2) {
                    root.realBrowser = parts[0].trim().replace(/\.desktop$/, "");
                    root.realFileManager = parts[1].trim().replace(/\.desktop$/, "");
                }
            }
        }
    }

    // Installed app helper functions
    function getInstalledBrowsers() {
        var list = [];
        var seen = new Set();
        if (ApplicationManager.allApps) {
            for (var i = 0; i < ApplicationManager.allApps.length; i++) {
                var app = ApplicationManager.allApps[i];
                if (!app || !app.id) continue;
                var id = app.id.toLowerCase().replace(/\.desktop$/, "");
                var cats = app.categories ? app.categories.join(" ") : "";
                if (cats.indexOf("WebBrowser") !== -1 || id.indexOf("browser") !== -1 || id === "zen" || id === "firefox" || id === "chromium" || id === "chrome") {
                    if (id !== "org.gnome.zenity" && !seen.has(id)) {
                        seen.add(id);
                        list.push({ id: id, name: app.name || id, icon: app.icon });
                    }
                }
            }
        }
        if (list.length === 0) {
            list = [
                { id: "brave", name: "Brave Browser", icon: "brave-browser" },
                { id: "zen", name: "Zen Browser", icon: "zen" }
            ];
        }
        return list;
    }

    function getInstalledTerminals() {
        var list = [];
        var seen = new Set();
        if (ApplicationManager.allApps) {
            for (var i = 0; i < ApplicationManager.allApps.length; i++) {
                var app = ApplicationManager.allApps[i];
                if (!app || !app.id) continue;
                var id = app.id.toLowerCase().replace(/\.desktop$/, "");
                var cats = app.categories ? app.categories.join(" ") : "";
                if (cats.indexOf("TerminalEmulator") !== -1 || id.indexOf("terminal") !== -1 || id === "kitty" || id === "alacritty" || id === "foot" || id === "wezterm") {
                    if (id !== "kitty-open" && !seen.has(id)) {
                        seen.add(id);
                        list.push({ id: id, name: app.name || id, icon: app.icon });
                    }
                }
            }
        }
        if (list.length === 0) {
            list = [
                { id: "kitty", name: "Kitty", icon: "kitty" }
            ];
        }
        return list;
    }

    function getInstalledFileManagers() {
        var list = [];
        var seen = new Set();
        if (ApplicationManager.allApps) {
            for (var i = 0; i < ApplicationManager.allApps.length; i++) {
                var app = ApplicationManager.allApps[i];
                if (!app || !app.id) continue;
                var id = app.id.toLowerCase().replace(/\.desktop$/, "");
                var cats = app.categories ? app.categories.join(" ") : "";
                if (cats.indexOf("FileManager") !== -1 || id === "thunar" || id === "nautilus" || id === "dolphin" || id === "yazi") {
                    if (id !== "thunar-bulk-rename" && id !== "thunar-settings" && id !== "nautilus-autorun-software" && !seen.has(id)) {
                        seen.add(id);
                        list.push({ id: id, name: app.name || id, icon: app.icon });
                    }
                }
            }
        }
        if (list.length === 0) {
            list = [
                { id: "thunar", name: "Thunar", icon: "system-file-manager" },
                { id: "org.gnome.nautilus", name: "Files", icon: "org.gnome.Nautilus" }
            ];
        }
        return list;
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

        // ── 1. App details (from the app menu → "App Info") ──────────
        SettingsSection {
            visible: ShellState.appInfoId !== ""
            title: I18n.tr("app_details")
            AppDetailsCard {}
        }

        // ── 2. Real Default Applications ─────────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "التطبيقات الافتراضية" : "Default Applications"

            // Default Browser
            SettingsRow {
                title: I18n.tr("web_browser")
                subtitle: I18n.isRTL ? "المتصفح المستخدم لفتح الروابط وصفحات الويب (xdg default)" : "Default browser for opening web links and html"
                icon: "applications-internet-symbolic"
                showDivider: true

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: root.getInstalledBrowsers()
                        delegate: Rectangle {
                            id: browserPill
                            required property var modelData
                            readonly property bool isSelected: (root.realBrowser || ConfigManager.defaultBrowser || "").toLowerCase().replace(/\.desktop$/, "") === modelData.id

                            height: 28
                            implicitWidth: browserRow.implicitWidth + Theme.space16
                            radius: 14
                            color: browserPill.isSelected ? Theme.notchSurfaceActive : (browserMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: browserPill.isSelected ? Theme.notchBorderHighlight : (browserMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                            RowLayout {
                                id: browserRow
                                anchors.centerIn: parent
                                spacing: 6

                                AppIcon {
                                    iconSize: 16
                                    source: browserPill.modelData.icon || "applications-internet"
                                }

                                Text {
                                    text: browserPill.modelData.name
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(11)
                                    font.weight: browserPill.isSelected ? Font.DemiBold : Font.Normal
                                    color: browserPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                                }
                            }

                            MouseArea {
                                id: browserMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.realBrowser = browserPill.modelData.id;
                                    ConfigManager.setDefaultApp("browser", browserPill.modelData.id);
                                }
                            }
                        }
                    }
                }
            }

            // Default Terminal
            SettingsRow {
                title: I18n.tr("terminal_emulator")
                subtitle: I18n.isRTL ? "برنامج الطرفية الافتراضي للسطر البرمجي والسكربتات" : "Terminal emulator used for command line tools"
                icon: "utilities-terminal-symbolic"
                showDivider: true

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: root.getInstalledTerminals()
                        delegate: Rectangle {
                            id: termPill
                            required property var modelData
                            readonly property bool isSelected: (ConfigManager.defaultTerminal || "").toLowerCase().replace(/\.desktop$/, "") === modelData.id

                            height: 28
                            implicitWidth: termRow.implicitWidth + Theme.space16
                            radius: 14
                            color: termPill.isSelected ? Theme.notchSurfaceActive : (termMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: termPill.isSelected ? Theme.notchBorderHighlight : (termMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                            RowLayout {
                                id: termRow
                                anchors.centerIn: parent
                                spacing: 6

                                AppIcon {
                                    iconSize: 16
                                    source: termPill.modelData.icon || "utilities-terminal"
                                }

                                Text {
                                    text: termPill.modelData.name
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(11)
                                    font.weight: termPill.isSelected ? Font.DemiBold : Font.Normal
                                    color: termPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                                }
                            }

                            MouseArea {
                                id: termMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConfigManager.setDefaultApp("terminal", termPill.modelData.id)
                            }
                        }
                    }
                }
            }

            // Default File Manager
            SettingsRow {
                title: I18n.tr("file_manager")
                subtitle: I18n.isRTL ? "تطبيق إدارة الملفات والمجلدات الافتراضي (inode/directory)" : "Default application for browsing folders and files"
                icon: "system-file-manager-symbolic"
                showDivider: false

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: root.getInstalledFileManagers()
                        delegate: Rectangle {
                            id: fmPill
                            required property var modelData
                            readonly property bool isSelected: (root.realFileManager || ConfigManager.defaultFileManager || "").toLowerCase().replace(/\.desktop$/, "") === modelData.id

                            height: 28
                            implicitWidth: fmRow.implicitWidth + Theme.space16
                            radius: 14
                            color: fmPill.isSelected ? Theme.notchSurfaceActive : (fmMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: fmPill.isSelected ? Theme.notchBorderHighlight : (fmMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                            RowLayout {
                                id: fmRow
                                anchors.centerIn: parent
                                spacing: 6

                                AppIcon {
                                    iconSize: 16
                                    source: fmPill.modelData.icon || "system-file-manager"
                                }

                                Text {
                                    text: fmPill.modelData.name
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(11)
                                    font.weight: fmPill.isSelected ? Font.DemiBold : Font.Normal
                                    color: fmPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                                }
                            }

                            MouseArea {
                                id: fmMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.realFileManager = fmPill.modelData.id;
                                    ConfigManager.setDefaultApp("fileManager", fmPill.modelData.id);
                                }
                            }
                        }
                    }
                }
            }
        }

        SettingsSection {
            title: I18n.isRTL ? "مشغّل الموسيقى" : "Music Player"

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

            // Quick Music Launch Target
            SettingsRow {
                title: I18n.isRTL ? "هدف تشغيل الموسيقى" : "Music Launch Target"
                subtitle: I18n.isRTL ? "التطبيق أو الخدمة التي تفتح عند النقر على كبسولة الموسيقى وهي خاملة" : "App or service launched when clicking idle music capsule"
                icon: "media-optical-audio-symbolic"
                showDivider: false

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [
                            { id: "spotify", type: "app", label: "Spotify", val: "spotify" },
                            { id: "ytm",     type: "url", label: "YouTube Music", val: "https://music.youtube.com" },
                            { id: "celluloid", type: "app", label: "Celluloid", val: "io.github.celluloid_player.Celluloid" },
                            { id: "mpv",     type: "app", label: "MPV", val: "mpv" }
                        ]
                        delegate: Rectangle {
                            id: targetPill
                            required property var modelData
                            readonly property bool isSelected: {
                                var cur = ConfigManager.musicLaunchTarget;
                                if (!cur) return modelData.id === "spotify";
                                if (modelData.type === "url") return cur.type === "url" && cur.value === modelData.val;
                                return cur.type === "app" && cur.value === modelData.val;
                            }

                            height: 28
                            implicitWidth: targetText.implicitWidth + Theme.space16
                            radius: 14
                            color: targetPill.isSelected ? Theme.notchSurfaceActive : (targetMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: targetPill.isSelected ? Theme.notchBorderHighlight : (targetMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                id: targetText
                                anchors.centerIn: parent
                                text: targetPill.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: targetPill.isSelected ? Font.DemiBold : Font.Normal
                                color: targetPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: targetMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var cur = Object.assign({}, ConfigManager.musicLaunchTarget || {});
                                    cur.type = targetPill.modelData.type;
                                    cur.value = targetPill.modelData.val;
                                    ConfigManager.setMusicLaunchTarget(cur);
                                }
                            }
                        }
                    }
                }
            }

            // Advanced Music Launch Target
            SettingsRow {
                title: I18n.isRTL ? "تخصيص رابط أو أمر تشغيل الموسيقى" : "Custom Music Target & Flag"
                subtitle: I18n.isRTL ? "تحديد رابط URL يدوي أو تشغيل كنافذة تطبيق مستقلة (--app)" : "Define a custom URL or standalone app mode (--app)"
                icon: "media-optical-audio-symbolic"
                showDivider: true

                RowLayout {
                    spacing: Theme.space8
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    DeloTextField {
                        id: customUrlInput
                        implicitWidth: 200
                        implicitHeight: 28
                        fontPixelSize: Theme.fontSize(11)
                        placeholderText: "https://music.youtube.com"
                        text: (ConfigManager.musicLaunchTarget && ConfigManager.musicLaunchTarget.value) || ""
                        onAccepted: {
                            if (text.trim().length > 0) {
                                var cur = Object.assign({}, ConfigManager.musicLaunchTarget || {});
                                cur.type = text.trim().startsWith("http") ? "url" : "app";
                                cur.value = text.trim();
                                ConfigManager.setMusicLaunchTarget(cur);
                            }
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
