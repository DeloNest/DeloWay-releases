// Wallpaper — custom image and bundled gallery.
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

    property var wallpapersList: []

    Component.onCompleted: {
        wallpapersScanProc.running = true;
    }

    onVisibleChanged: {
        if (visible) wallpapersScanProc.running = true;
    }

    // Process to scan real wallpapers from disk
    Process {
        id: wallpapersScanProc
        command: ["python3", ConfigManager.projectDir + "/scripts/deloway-wallpapers-list.py"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var arr = JSON.parse(data.trim());
                    if (Array.isArray(arr) && arr.length > 0) {
                        root.wallpapersList = arr;
                    }
                } catch (e) {}
            }
        }
    }

    // Process to browse and pick a wallpaper
    Process {
        id: wallpaperBrowseProc
        command: ["python3", ConfigManager.projectDir + "/scripts/deloway-wallpaper.py", "--browse"]
        onExited: wallpapersScanProc.running = true
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

        // ── 1. Desktop: what it shows, and whether it shows it ──────
        // (The right-click menu has the show/hide switch; choosing icons or widgets
        // lives here, where "Desktop Settings…" leads.)
        SettingsSection {
            title: I18n.isRTL ? "سطح المكتب" : "Desktop"

            SettingsRow {
                title: I18n.isRTL ? "إظهار عناصر سطح المكتب" : "Show Desktop Items"
                subtitle: I18n.isRTL ? "عند الإيقاف يبقى سطح المكتب فارغاً، الخلفية وحدها"
                                     : "When off, the desktop stays empty — just the wallpaper"
                icon: ConfigManager.showDesktopContent ? "view-reveal-symbolic" : "view-conceal-symbolic"
                showDivider: true
                clickable: true
                onClicked: ConfigManager.setShowDesktopContent(!ConfigManager.showDesktopContent)

                SettingsToggle {
                    checked: ConfigManager.showDesktopContent
                    onToggled: ch => ConfigManager.setShowDesktopContent(ch)
                }
            }

            SettingsRow {
                title: I18n.isRTL ? "محتوى سطح المكتب" : "Desktop Content"
                subtitle: I18n.isRTL ? "أيقونات الملفات والمجلدات، أو بطاقات الأدوات"
                                     : "File and folder icons, or widget cards"
                icon: "preferences-desktop-symbolic"
                showDivider: ConfigManager.desktopMode === "traditional"

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [
                            { id: "traditional", label: I18n.isRTL ? "الأيقونات" : "Icons" },
                            { id: "widgets",     label: I18n.isRTL ? "الأدوات" : "Widgets" }
                        ]
                        delegate: Rectangle {
                            id: modePill
                            required property var modelData
                            readonly property bool isSelected: ConfigManager.desktopMode === modelData.id

                            height: 28
                            implicitWidth: modeText.implicitWidth + Theme.space16
                            radius: 14
                            color: modePill.isSelected ? Theme.notchSurfaceActive : (modeMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: modePill.isSelected ? Theme.notchBorderHighlight : (modeMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                id: modeText
                                anchors.centerIn: parent
                                text: modePill.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: modePill.isSelected ? Font.DemiBold : Font.Normal
                                color: modePill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: modeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConfigManager.setDesktopMode(modePill.modelData.id)
                            }
                        }
                    }
                }
            }

            SettingsRow {
                visible: ConfigManager.desktopMode === "traditional"
                title: I18n.isRTL ? "المحاذاة للشبكة" : "Align to Grid"
                subtitle: I18n.isRTL ? "تستقر الأيقونات على شبكة منتظمة عند إفلاتها"
                                     : "Icons settle on an even grid when dropped"
                icon: "snap-symbolic"
                showDivider: false
                clickable: true
                onClicked: ConfigManager.setDesktopSnapToGrid(!ConfigManager.desktopSnapToGrid)

                SettingsToggle {
                    checked: ConfigManager.desktopSnapToGrid
                    onToggled: ch => ConfigManager.setDesktopSnapToGrid(ch)
                }
            }
        }

        // ── 2. Desktop Wallpapers ────────────────────────────────
        SettingsSection {
            title: I18n.tr("wallpaper_title")

            SettingsRow {
                title: I18n.isRTL ? "خلفية مخصصة" : "Custom Wallpaper"
                subtitle: I18n.isRTL ? "استعراض واختيار صورة من جهازك" : "Browse and choose an image from storage"
                icon: "view-app-grid-symbolic"
                showDivider: true

                Rectangle {
                    height: 32
                    implicitWidth: btnRow.implicitWidth + Theme.space24
                    radius: 16
                    color: browseMa.pressed ? Theme.notchSurfaceActive : (browseMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceElevated)
                    border.color: Theme.notchBorder
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                    RowLayout {
                        id: btnRow
                        anchors.centerIn: parent
                        spacing: Theme.space8

                        SymbolicIcon {
                            source: "system-search-symbolic"
                            iconSize: 14
                            iconColor: Theme.notchText
                        }

                        Text {
                            text: I18n.tr("browse_wallpaper")
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(12)
                            font.weight: Font.Medium
                            color: Theme.notchText
                        }
                    }

                    MouseArea {
                        id: browseMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: wallpaperBrowseProc.running = true
                    }
                }
            }

            // Thumbnail Gallery
            Item {
                id: galleryContainer
                Layout.fillWidth: true
                implicitHeight: {
                    if (!root.wallpapersList || root.wallpapersList.length === 0) return 60;
                    var availW = galleryContainer.width > 0 ? galleryContainer.width : 500;
                    var cardW = 140;
                    var gap = Theme.space16;
                    var cols = Math.max(1, Math.floor((availW - (gap * 2) + gap) / (cardW + gap)));
                    var rows = Math.ceil(root.wallpapersList.length / cols);
                    return (rows * 88) + (Math.max(0, rows - 1) * gap) + (gap * 2);
                }
                Layout.preferredHeight: implicitHeight
                height: implicitHeight

                Text {
                    visible: root.wallpapersList.length === 0
                    anchors.centerIn: parent
                    text: I18n.isRTL ? "جارٍ البحث عن الخلفيات..." : "Scanning wallpapers..."
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(12)
                    color: Theme.notchTextTertiary
                }

                Flow {
                    id: wpFlow
                    visible: root.wallpapersList.length > 0
                    anchors.fill: parent
                    anchors.margins: Theme.space16
                    spacing: Theme.space16
                    // Default LeftToRight + mirroring = RightToLeft in Arabic (a RightToLeft
                    // layoutDirection on top of mirroring flipped it back to LTR).
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true
                    Repeater {
                        model: root.wallpapersList
                        delegate: Rectangle {
                            id: wpCard
                            required property var modelData
                            readonly property bool isSelected: {
                                if (!ConfigManager.wallpaper || !modelData.path) return false;
                                var current = ConfigManager.wallpaper.replace(/^file:\/\//, "").replace(/\/+$/, "");
                                var itemPath = modelData.path.replace(/^file:\/\//, "").replace(/\/+$/, "");
                                return current === itemPath;
                            }

                            width: 140
                            height: 88
                            radius: Theme.notchRadiusCard
                            color: Theme.notchSurfaceElevated
                            border.color: wpCard.isSelected ? Theme.inverseSurface : (wpMa.containsMouse ? Theme.notchBorderHighlight : Theme.notchBorderSubtle)
                            border.width: wpCard.isSelected ? 2 : 1
                            clip: true
                            LayoutMirroring.enabled: I18n.isRTL
                            LayoutMirroring.childrenInherit: true

                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Image {
                                anchors.fill: parent
                                anchors.margins: wpCard.isSelected ? 2 : 0
                                source: ConfigManager.fileUrl(wpCard.modelData.path)
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(280, 176)   // 2× the 140×88 card
                                cache: true
                                asynchronous: true
                            }

                            // Active Checkmark Badge
                            Rectangle {
                                visible: wpCard.isSelected
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 6
                                width: 20
                                height: 20
                                radius: 10
                                color: Theme.inverseSurface

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(11)
                                    font.weight: Font.Bold
                                    color: Theme.inverseText
                                }
                            }

                            // Bottom title bar
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 24
                                color: Theme.captionScrim   // light scrim in light mode: its text stays readable

                                Text {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.space8
                                    anchors.rightMargin: Theme.space8
                                    text: wpCard.modelData.name
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(10)
                                    font.weight: Font.Medium
                                    color: wpCard.isSelected ? Theme.notchText : Theme.notchTextSecondary
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignLeft
                                }
                            }

                            MouseArea {
                                id: wpMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConfigManager.setWallpaper(wpCard.modelData.path)
                            }
                        }
                    }
                }
            }
        }
    }
}
