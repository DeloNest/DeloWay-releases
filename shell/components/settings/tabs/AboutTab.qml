// About — system information, shortcuts guide and reset.
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

        SettingsSection {
            title: I18n.isRTL ? "إعادة الضبط" : "Reset"

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
                                    // Reset through the real setters (applies Hyprland/GTK/theme, not just JSON)
                                    ConfigManager.resetToDefaults();
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
