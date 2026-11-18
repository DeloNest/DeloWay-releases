// About — system information, hardware profile, shortcuts guide and reset.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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

    property string osDistro: ""
    property string osKernel: ""
    property string osHostname: ""
    property string osCpu: ""
    property string osRam: ""
    property string osGpu: ""
    property string osUptime: ""
    property string osHyprland: ""
    property bool confirmReset: false

    Component.onCompleted: sysInfoProc.running = true

    onVisibleChanged: {
        if (visible) {
            sysInfoProc.running = true;
            root.confirmReset = false;
        }
    }

    // Process to fetch comprehensive system & hardware info
    Process {
        id: sysInfoProc
        command: [
            "sh", "-c",
            "distro=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '\"'); " +
            "[ -z \"$distro\" ] && distro=$(uname -s); " +
            "kernel=$(uname -r); " +
            "host=$(uname -n); " +
            "cpu=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs); " +
            "ram=$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}'); " +
            "gpu=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -1 | cut -d: -f3 | sed 's/([^)]*)//g' | xargs); " +
            "uptime=$(uptime -p 2>/dev/null); " +
            "hypr=$(hyprctl version 2>/dev/null | head -1 | awk '{print $1, $2}'); " +
            "echo \"$distro|$kernel|$host|$cpu|$ram|$gpu|$uptime|$hypr\""
        ]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split("|");
                if (parts.length >= 8) {
                    root.osDistro = parts[0];
                    root.osKernel = parts[1];
                    root.osHostname = parts[2];
                    root.osCpu = parts[3];
                    root.osRam = parts[4];
                    root.osGpu = parts[5];
                    root.osUptime = parts[6];
                    root.osHyprland = parts[7];
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

        // ── 1. OS & Desktop Environment ──────────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "نظام التشغيل والواجهة" : "OS & Desktop Environment"

            // DeloWay Shell
            SettingsRow {
                title: I18n.tr("about_shell_title")
                subtitle: I18n.isRTL
                    ? "واجهة مكتبية أحادية اللون لشاشات OLED مبنية على Quickshell"
                    : "OLED-first monochrome desktop shell built with Quickshell"
                icon: "applications-system-symbolic"
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

            // Linux Distribution
            SettingsRow {
                title: I18n.isRTL ? "توزيعة النظام" : "Distribution"
                subtitle: root.osDistro || "Arch Linux"
                icon: "system-symbolic"
                showDivider: true

                Rectangle {
                    height: 24
                    implicitWidth: archText.implicitWidth + 16
                    radius: 12
                    color: Theme.notchSurfaceElevated
                    border.color: Theme.notchBorderSubtle
                    border.width: 1

                    Text {
                        id: archText
                        anchors.centerIn: parent
                        text: "x86_64"
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(10)
                        font.weight: Font.Normal
                        color: Theme.notchTextSecondary
                    }
                }
            }

            // Linux Kernel
            SettingsRow {
                title: I18n.isRTL ? "نواة لينكس (Kernel)" : "Linux Kernel"
                subtitle: I18n.ltr(root.osKernel || "Linux")
                icon: "utilities-terminal-symbolic"
                showDivider: true
            }

            // Compositor / Window Manager
            SettingsRow {
                title: I18n.isRTL ? "مدير النوافذ (Compositor)" : "Window Compositor"
                subtitle: I18n.ltr(root.osHyprland || "Hyprland Wayland Compositor")
                icon: "preferences-system-symbolic"
                showDivider: true
            }

            // Hostname
            SettingsRow {
                title: I18n.isRTL ? "اسم الجهاز (Hostname)" : "Device Name"
                subtitle: I18n.ltr(root.osHostname || "localhost")
                icon: "network-server-symbolic"
                showDivider: false
            }
        }

        // ── 2. Hardware Specifications ────────────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "مواصفات العتاد والأجهزة" : "Hardware Specifications"

            // Processor (CPU)
            SettingsRow {
                title: I18n.isRTL ? "المعالج (CPU)" : "Processor (CPU)"
                subtitle: I18n.ltr(root.osCpu || "Multi-core Processor")
                icon: "computer-symbolic"
                showDivider: true
            }

            // Memory (RAM)
            SettingsRow {
                title: I18n.isRTL ? "الذاكرة العشوائية (RAM)" : "Memory (RAM)"
                subtitle: I18n.ltr(root.osRam ? (root.osRam + " Total") : "System Memory")
                icon: "device-symbolic"
                showDivider: true
            }

            // Graphics (GPU)
            SettingsRow {
                title: I18n.isRTL ? "بطاقة الرسوميات (GPU)" : "Graphics (GPU)"
                subtitle: I18n.ltr(root.osGpu || "Integrated / Dedicated Graphics")
                icon: "video-display-symbolic"
                showDivider: true
            }

            // System Uptime
            SettingsRow {
                title: I18n.isRTL ? "مدة التشغيل" : "System Uptime"
                subtitle: I18n.ltr(root.osUptime || "Running")
                icon: "preferences-system-time-symbolic"
                showDivider: false
            }
        }

        // ── 3. Reset ─────────────────────────────────────────────────
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
                            ? (resetMa.pressed ? Theme.primaryHover : Theme.inverseSurface)
                            : (resetMa.pressed ? Theme.notchSurfaceActive : (resetMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceElevated))
                        border.color: root.confirmReset ? Theme.inverseSurface : (resetMa.containsMouse ? Theme.notchBorderHighlight : Theme.notchBorderSubtle)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                        Text {
                            id: resetBtnText
                            anchors.centerIn: parent
                            text: root.confirmReset ? (I18n.isRTL ? "تأكيد الاستعادة" : "Confirm Reset") : (I18n.isRTL ? "استعادة الافتراضي" : "Reset to Defaults")
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            font.weight: Font.DemiBold
                            color: root.confirmReset ? Theme.inverseText : (resetMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary)
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
