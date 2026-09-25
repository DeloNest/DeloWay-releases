import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../services"

PanelWindow {
    id: root
    // Descriptions follow the UI language; every row mirrors a real bind in config/hyprland.conf.
    function t(ar, en) { return I18n.isRTL ? ar : en; }

    required property ShellScreen targetScreen
    screen: targetScreen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    WlrLayershell.namespace: "deloway:cheatsheet"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: ShellState.cheatSheetOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    visible: ShellState.cheatSheetOpen || cheatSheetCard.opacity > 0.01

    Shortcut {
        sequence: "Escape"
        enabled: ShellState.cheatSheetOpen
        onActivated: ShellState.closeCheatSheet()
    }

    Shortcut {
        sequence: "Super+/"
        enabled: ShellState.cheatSheetOpen
        onActivated: ShellState.closeCheatSheet()
    }

    Shortcut {
        sequence: "Super+Shift+/"
        enabled: ShellState.cheatSheetOpen
        onActivated: ShellState.closeCheatSheet()
    }

    // Dimmed Backdrop
    Rectangle {
        anchors.fill: parent
        color: Theme.modalScrim
        opacity: ShellState.cheatSheetOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }

        MouseArea {
            anchors.fill: parent
            onClicked: ShellState.closeCheatSheet()
        }
    }

    // Main Window with DeloWindowChrome
    DeloWindowChrome {
        id: cheatSheetCard
        anchors.centerIn: parent
        width: Math.min(1360, parent.width - Theme.space48)
        height: Math.min(780, parent.height - Theme.space48)
        title: I18n.tr("cs_title")
        iconSource: "help-browser-symbolic"
        showCloseButton: true
        onCloseClicked: ShellState.closeCheatSheet()

        opacity: ShellState.cheatSheetOpen ? 1.0 : 0.0
        scale: ShellState.cheatSheetOpen ? 1.0 : 0.95
        Behavior on opacity { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
        Behavior on scale { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }

        MouseArea {
            anchors.fill: parent
            onClicked: {} // Prevent dismiss on card click
        }

        Item {
            anchors.fill: parent
            anchors.margins: Theme.space24

            // 4 Columns Grid Container
            RowLayout {
                anchors.fill: parent
                spacing: Theme.space24

                // ── Column 1: Shell + Utilities ──────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignTop
                    spacing: Theme.space16

                    SectionBox {
                        title: I18n.tr("cs_shell")
                        items: [
                            { keys: ["Super"], desc: root.t("قائمة ابدأ (نقرة)", "Start menu (tap)") },
                            { keys: ["Super", "A"], desc: root.t("درج التطبيقات", "App Drawer") },
                            { keys: ["Super", "Space"], desc: root.t("البحث", "Search") },
                            { keys: ["Super", "N"], desc: root.t("الإعدادات السريعة", "Quick Settings") },
                            { keys: ["Super", "M"], desc: root.t("الإعدادات السريعة", "Quick Settings") },
                            { keys: ["Super", "Alt", "N"], desc: root.t("النوتش", "Smart Notch") },
                            { keys: ["Super", "I"], desc: root.t("إعدادات DeloWay", "DeloWay Settings") },
                            { keys: ["Super", "V"], desc: root.t("سجل الحافظة", "Clipboard history") },
                            { keys: ["Super", "/"], desc: root.t("دليل الاختصارات", "Keyboard shortcuts") },
                            { keys: ["Super", "Shift", "F"], desc: root.t("إخفاء/إظهار الشريط والـDock", "Hide / show bar & dock") },
                            { keys: ["Super", "K"], desc: root.t("لوحة المفاتيح على الشاشة", "On-screen keyboard") },
                            { keys: ["Ctrl", "Alt", "Delete"], desc: root.t("قائمة الجلسة", "Session menu") },
                            { keys: ["Ctrl", "Super", "T"], desc: root.t("تغيير الخلفية", "Change wallpaper") },
                            { keys: ["Ctrl", "Super", "R"], desc: root.t("إعادة تشغيل الواجهة", "Restart the shell") }
                        ]
                    }

                    SectionBox {
                        title: I18n.tr("cs_utilities")
                        items: [
                            { keys: ["Super", "Shift", "S"], desc: root.t("لقطة لجزء من الشاشة", "Screenshot a region") },
                            { keys: ["Print"], desc: root.t("لقطة للشاشة كاملة", "Screenshot full screen") },
                            { keys: ["Super", "Shift", "C"], desc: root.t("التقاط لون (Hex) إلى الحافظة", "Pick color (Hex) to clipboard") },
                            { keys: ["Super", "Alt", "R"], desc: root.t("تسجيل منطقة (بدون صوت)", "Record region (no sound)") },
                            { keys: ["Super", "Shift", "Alt", "R"], desc: root.t("تسجيل منطقة (مع الصوت)", "Record region (with sound)") },
                            { keys: ["Super", "- / ="], desc: root.t("تكبير المؤشر: إلغاء / تكبير", "Cursor zoom: reset / zoom") }
                        ]
                    }

                    Item { Layout.fillHeight: true }
                }

                // ── Column 2: Window management ──────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignTop
                    spacing: Theme.space16

                    SectionBox {
                        title: I18n.tr("cs_window")
                        items: [
                            { keys: ["Super", "LMB"], desc: root.t("تحريك", "Move") },
                            { keys: ["Super", "RMB"], desc: root.t("تغيير الحجم", "Resize") },
                            { keys: ["Super", "←/↑/→/↓"], desc: root.t("التركيز باتجاه", "Focus in direction") },
                            { keys: ["Super", "Shift", "←/↑/→/↓"], desc: root.t("نقل باتجاه", "Move in direction") },
                            { keys: ["Super", "Alt", "←/↑/→/↓"], desc: root.t("تغيير الحجم", "Resize") },
                            { keys: ["Super", "Q"], desc: root.t("إغلاق", "Close") },
                            { keys: ["Super", "Shift", "Alt", "Q"], desc: root.t("إنهاء نافذة بالقوة", "Force-kill a window") },
                            { keys: ["Super", "; / '"], desc: root.t("نسبة التقسيم", "Adjust split ratio") },
                            { keys: ["Super", "\\"], desc: root.t("تبديل اتجاه التقسيم", "Toggle split direction") },
                            { keys: ["Super", "Alt", "Space"], desc: root.t("عائمة / مرصوفة", "Float / tile") },
                            { keys: ["Super", "D"], desc: root.t("تكبير", "Maximize") },
                            { keys: ["Super", "F"], desc: root.t("ملء الشاشة", "Fullscreen") },
                            { keys: ["Super", "Alt", "F"], desc: root.t("ملء شاشة وهمي", "Fake fullscreen") },
                            { keys: ["Super", "P"], desc: root.t("تثبيت فوق الكل", "Pin") },
                            { keys: ["Super", "G"], desc: root.t("تجميع / فك التجميع", "Group / ungroup") },
                            { keys: ["Super", "Tab"], desc: root.t("النافذة التالية في المجموعة", "Next window in group") },
                            { keys: ["Super", "Alt", "#"], desc: root.t("إرسال إلى مساحة العمل #", "Send to workspace #") },
                            { keys: ["Super", "Shift", "Page_↑/↓"], desc: root.t("إرسال إلى المساحة السابقة/التالية", "Send to previous / next workspace") },
                            { keys: ["Super", "Alt", "S"], desc: root.t("إرسال إلى المساحة المخفية", "Send to scratchpad") }
                        ]
                    }


                    Item { Layout.fillHeight: true }
                }

                // ── Column 3: Apps, General, Workspaces ──────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignTop
                    spacing: Theme.space16

                    SectionBox {
                        title: I18n.tr("cs_apps")
                        items: [
                            { keys: ["Super", "Return"], desc: root.t("الطرفية", "Terminal") },
                            { keys: ["Super", "E"], desc: root.t("مدير الملفات", "File manager") },
                            { keys: ["Super", "W"], desc: root.t("المتصفح", "Browser") },
                            { keys: ["Super", "C"], desc: root.t("محرر الشيفرة", "Code editor") },
                            { keys: ["Super", "Shift", "W"], desc: root.t("حزمة المكتب", "Office suite") },
                            { keys: ["Super", "X"], desc: root.t("محرر النصوص", "Text editor") },
                            { keys: ["Ctrl", "Shift", "Escape"], desc: root.t("مراقب النظام", "System monitor") },
                            { keys: ["Ctrl", "Super", "V"], desc: root.t("التحكم بالصوت", "Volume control") }
                        ]
                    }

                    SectionBox {
                        title: I18n.tr("cs_general")
                        items: [
                            { keys: ["Super", "L"], desc: root.t("قفل الشاشة", "Lock screen") },
                            { keys: ["Super", "Shift", "L"], desc: root.t("سكون", "Suspend") }
                        ]
                    }

                    SectionBox {
                        title: I18n.tr("cs_workspace")
                        items: [
                            { keys: ["Super", "#"], desc: root.t("الانتقال إلى مساحة العمل #", "Go to workspace #") },
                            { keys: ["Ctrl", "Super", "←/→"], desc: root.t("المساحة السابقة / التالية", "Previous / next workspace") },
                            { keys: ["Super", "Page_↑/↓"], desc: root.t("المساحة السابقة / التالية", "Previous / next workspace") },
                            { keys: ["Super", "Scroll ↑/↓"], desc: root.t("المساحة السابقة / التالية", "Previous / next workspace") },
                            { keys: ["Super", "S"], desc: root.t("إظهار المساحة المخفية", "Toggle scratchpad") }
                        ]
                    }

                    Item { Layout.fillHeight: true }
                }

                // ── Column 4: Media & System Keys ────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignTop
                    spacing: Theme.space16

                    SectionBox {
                        title: I18n.tr("cs_media")
                        items: [
                            { keys: ["Super", "Shift", "P"], desc: root.t("تشغيل / إيقاف مؤقت", "Play / pause") },
                            { keys: ["Super", "Shift", "N"], desc: root.t("المقطع التالي", "Next track") },
                            { keys: ["Super", "Shift", "B"], desc: root.t("المقطع السابق", "Previous track") },
                            { keys: ["XF86AudioMute"], desc: root.t("كتم / إلغاء كتم الصوت", "Mute / unmute") },
                            { keys: ["XF86AudioLowerVolume"], desc: root.t("خفض الصوت", "Lower volume") },
                            { keys: ["XF86AudioRaiseVolume"], desc: root.t("رفع الصوت", "Raise volume") },
                            { keys: ["XF86AudioPlay"], desc: root.t("تشغيل / إيقاف مؤقت", "Play / pause") },
                            { keys: ["XF86AudioNext"], desc: root.t("المقطع التالي", "Next track") },
                            { keys: ["XF86AudioPrev"], desc: root.t("المقطع السابق", "Previous track") },
                            { keys: ["XF86MonBrightnessUp"], desc: root.t("رفع السطوع", "Brightness up") },
                            { keys: ["XF86MonBrightnessDown"], desc: root.t("خفض السطوع", "Brightness down") }
                        ]
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }

    // ── Reusable Component: Section Box ──────────────────────────────────────
    component SectionBox: ColumnLayout {
        id: secRoot
        property string title: ""
        property var items: []

        Layout.fillWidth: true
        spacing: Theme.space8

        Text {
            text: secRoot.title
            font.family: Theme.typography.fontFamily
            font.hintingPreference: Theme.hintingPreference
            font.pixelSize: Theme.typography.scaleTitle.size
            font.weight: Font.DemiBold
            renderType: Theme.renderType
            color: Theme.colors.text
        }

        Repeater {
            model: secRoot.items

            delegate: RowLayout {
                id: rowDel
                required property var modelData
                Layout.fillWidth: true
                spacing: Theme.space8

                // Key Combo (badges with '+' between them)
                RowLayout {
                    spacing: 3

                    Repeater {
                        model: rowDel.modelData.keys

                        delegate: RowLayout {
                            id: keyDel
                            required property string modelData
                            required property int index
                            spacing: 3

                            // Key Pill Badge
                            Rectangle {
                                implicitHeight: 22
                                implicitWidth: (keyDel.modelData === "Super" || keyDel.modelData === "Win")
                                               ? 26
                                               : Math.max(22, keyText.implicitWidth + Theme.space8)
                                radius: Theme.radiusSmall
                                color: Theme.colors.surfaceElevated
                                border.color: Theme.hairline
                                border.width: 1

                                // If Super key: render Windows logo
                                Item {
                                    anchors.centerIn: parent
                                    width: 11
                                    height: 11
                                    visible: keyDel.modelData === "Super" || keyDel.modelData === "Win"

                                    Grid {
                                        anchors.centerIn: parent
                                        columns: 2
                                        spacing: 1.5
                                        Repeater {
                                            model: 4
                                            Rectangle {
                                                width: 4
                                                height: 4
                                                radius: 0.8
                                                color: Theme.colors.text
                                            }
                                        }
                                    }
                                }

                                // Text for other keys
                                Text {
                                    id: keyText
                                    anchors.centerIn: parent
                                    visible: keyDel.modelData !== "Super" && keyDel.modelData !== "Win"
                                    text: keyDel.modelData
                                    font.family: Theme.typography.fontFamily
                                    font.hintingPreference: Theme.hintingPreference
                                    font.pixelSize: Theme.fontSize(11)
                                    font.weight: Font.Medium
                                    renderType: Theme.renderType
                                    color: Theme.colors.text
                                }
                            }

                            // '+' separator between keys
                            Text {
                                visible: keyDel.index < rowDel.modelData.keys.length - 1
                                text: "+"
                                font.family: Theme.typography.fontFamily
                                font.hintingPreference: Theme.hintingPreference
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: Font.Normal
                                renderType: Theme.renderType
                                color: Theme.colors.textTertiary
                            }
                        }
                    }
                }

                // Description Text
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignLeft   // reading start in both languages
                    text: rowDel.modelData.desc
                    font.family: Theme.typography.fontFamily
                    font.hintingPreference: Theme.hintingPreference
                    font.pixelSize: Theme.fontSize(11)
                    font.weight: Font.Normal
                    renderType: Theme.renderType
                    color: Theme.colors.textSecondary
                    elide: Text.ElideRight
                }
            }
        }
    }
}
