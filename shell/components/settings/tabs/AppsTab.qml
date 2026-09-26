// Apps — two sub-sections: Default Apps (the app for each role / file type, and the
// music player) and All Apps (every installed app: info, uninstall, per-app language).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
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

    // "defaults" | "all"
    property string section: ShellState.appInfoId !== "" ? "all" : "defaults"
    Connections {
        target: ShellState
        // "App Info" from an app menu opens All Apps on that app.
        function onAppInfoIdChanged() {
            if (ShellState.appInfoId === "" || root.section === "all") return;
            // From an app menu: show that app at the top of the list.
            root.section = "all";
            const e = DesktopEntries.byId(ShellState.appInfoId);
            allApps.query = e ? e.name : "";
        }
    }

    // A role row: what opens it now, and "Change" to pick another (the chooser folds out).
    component DefaultAppRow: ColumnLayout {
        id: row
        property string role: ""
        property string title: ""
        property string subtitle: ""
        property string icon: ""
        property bool expanded: false
        readonly property var current: {
            const id = DefaultApps.currentId(row.role);
            return DefaultApps.options(row.role).find(o => o.desktop.toLowerCase() === id) || null;
        }
        Layout.fillWidth: true
        spacing: 0

        SettingsRow {
            title: row.title
            subtitle: row.subtitle
            icon: row.icon
            showDivider: false
            clickable: true
            onClicked: row.expanded = !row.expanded

            RowLayout {
                spacing: Theme.space8
                AppIcon {
                    visible: !!row.current
                    source: row.current ? row.current.icon : ""
                    iconSize: 18
                }
                Text {
                    text: row.current ? row.current.name : I18n.tr("default_app_none")
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    Layout.maximumWidth: 200
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(12)
                    font.weight: Font.DemiBold
                    renderType: Theme.renderType
                    color: row.current ? Theme.notchText : Theme.notchTextTertiary
                }
                Rectangle {
                    implicitHeight: 26
                    implicitWidth: changeText.implicitWidth + Theme.space16
                    radius: 13
                    color: row.expanded ? Theme.notchSurfaceActive : (changeMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                    border.width: 1
                    border.color: changeMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle
                    Text {
                        id: changeText
                        anchors.centerIn: parent
                        text: row.expanded ? I18n.tr("default_app_done") : I18n.tr("default_app_change")
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(11)
                        renderType: Theme.renderType
                        color: Theme.notchText
                    }
                    MouseArea {
                        id: changeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: row.expanded = !row.expanded
                    }
                }
            }
        }

        DefaultAppChooser {
            visible: row.expanded
            Layout.fillWidth: true
            Layout.leftMargin: Theme.space16
            Layout.rightMargin: Theme.space16
            Layout.bottomMargin: Theme.space12
            role: row.role
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

        // ── Sub-sections ─────────────────────────────────────────────
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitHeight: 38
            implicitWidth: segRow.implicitWidth + 8
            radius: height / 2
            color: Theme.notchSurface
            border.width: 1
            border.color: Theme.notchBorderSubtle

            RowLayout {
                id: segRow
                anchors.centerIn: parent
                spacing: 4
                Repeater {
                    model: [
                        { id: "defaults", label: I18n.tr("apps_section_defaults") },
                        { id: "all", label: I18n.tr("apps_section_all") }
                    ]
                    delegate: Rectangle {
                        id: seg
                        required property var modelData
                        readonly property bool selected: root.section === seg.modelData.id
                        implicitHeight: 30
                        implicitWidth: segText.implicitWidth + Theme.space24
                        radius: height / 2
                        color: seg.selected ? Theme.inverseSurface : (segMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                        Text {
                            id: segText
                            anchors.centerIn: parent
                            text: seg.modelData.label
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(12)
                            font.weight: seg.selected ? Font.DemiBold : Font.Normal
                            renderType: Theme.renderType
                            color: seg.selected ? Theme.inverseText : Theme.notchTextSecondary
                        }
                        MouseArea {
                            id: segMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.section = seg.modelData.id
                        }
                    }
                }
            }
        }

        // ── All Apps ─────────────────────────────────────────────────
        AllAppsList {
            id: allApps
            visible: root.section === "all"
            Layout.fillWidth: true
        }

        // ── Default Apps ─────────────────────────────────────────────
        SettingsSection {
            visible: root.section === "defaults"
            title: I18n.tr("apps_section_defaults")

            // One row per role; the choices come from DefaultApps (same catalog as
            // install.sh and the Setup Wizard). Not-installed choices install on click.
            Repeater {
                model: [
                    { role: "browser", icon: "applications-internet-symbolic", title: I18n.tr("web_browser"),
                      subtitle: I18n.isRTL ? "يفتح الروابط وصفحات الويب" : "Opens web links and pages" },
                    { role: "terminal", icon: "utilities-terminal-symbolic", title: I18n.tr("terminal_emulator"),
                      subtitle: I18n.isRTL ? "يفتح بـ Super+Return ومن سطح المكتب" : "Opened by Super+Return and from the desktop" },
                    { role: "fileManager", icon: "system-file-manager-symbolic", title: I18n.tr("file_manager"),
                      subtitle: I18n.isRTL ? "يفتح المجلدات والملفات" : "Opens folders and files" },
                    { role: "editor", icon: "accessories-text-editor-symbolic", title: I18n.tr("text_editor"),
                      subtitle: I18n.tr("text_editor_desc") },
                    { role: "monitor", icon: "utilities-system-monitor-symbolic", title: I18n.tr("system_monitor"),
                      subtitle: I18n.isRTL ? "يفتح بـ Ctrl+Shift+Esc" : "Opened by Ctrl+Shift+Esc" },
                    { role: "image", icon: "image-x-generic-symbolic", title: I18n.tr("image_viewer"),
                      subtitle: I18n.tr("image_viewer_desc") },
                    { role: "video", icon: "video-x-generic-symbolic", title: I18n.tr("video_player"),
                      subtitle: I18n.tr("video_player_desc") },
                    { role: "pdf", icon: "x-office-document-symbolic", title: I18n.tr("pdf_viewer"),
                      subtitle: I18n.tr("pdf_viewer_desc") }
                ]

                delegate: DefaultAppRow {
                    required property var modelData
                    role: modelData.role
                    title: modelData.title
                    subtitle: modelData.subtitle
                    icon: modelData.icon
                }
            }
        }

        SettingsSection {
            visible: root.section === "defaults"
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
                subtitle: I18n.isRTL ? "تحديد رابط URL يدوي أو تشغيل كنافذة تطبيق مستقلة (" + I18n.ltr("--app") + ")" : "Define a custom URL or standalone app mode (--app)"
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
                            text: I18n.isRTL ? "تطبيق مستقل (" + I18n.ltr("--app") + ")" : "Web App (--app)"
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
