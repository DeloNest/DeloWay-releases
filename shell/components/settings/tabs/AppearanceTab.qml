import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../../theme"
import "../../../services"
import "../../"
import "../common"

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

        // ── 1. Theme Mode (Dark / Light) ──────────────────────────
        SettingsSection {
            title: I18n.tr("theme_mode")

            SettingsRow {
                title: I18n.isRTL ? "المظهر الداكن (Dark Mode)" : "Dark Mode"
                subtitle: ConfigManager.themeMode === "dark"
                          ? (I18n.isRTL ? "مفعّل — أسطح داكنة نقية لتقليل استهلاك الطاقة وإراحة العين" : "Enabled — Deep dark surfaces for low eye strain")
                          : (I18n.isRTL ? "معطّل — أسطح فاتحة ناصعة (Light Mode)" : "Disabled — Clean light surfaces (Light Mode)")
                icon: ConfigManager.themeMode === "dark" ? "weather-clear-night-symbolic" : "weather-sunny-symbolic"
                showDivider: true
                clickable: true
                onClicked: ConfigManager.setThemeMode(ConfigManager.themeMode === "dark" ? "light" : "dark")

                SettingsToggle {
                    checked: ConfigManager.themeMode === "dark"
                    onToggled: ch => ConfigManager.setThemeMode(ch ? "dark" : "light")
                }
            }

            SettingsRow {
                title: I18n.tr("apply_system_theme")
                subtitle: I18n.tr("apply_system_theme_desc")
                icon: "preferences-desktop-theme-symbolic"
                showDivider: false
                clickable: true
                onClicked: ConfigManager.setApplySystemTheme(!ConfigManager.applySystemTheme)

                SettingsToggle {
                    checked: ConfigManager.applySystemTheme
                    onToggled: ch => ConfigManager.setApplySystemTheme(ch)
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
                    layoutDirection: I18n.isRTL ? Qt.RightToLeft : Qt.LeftToRight
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
                            border.color: wpCard.isSelected ? Theme.colors.accent : (wpMa.containsMouse ? Theme.notchBorderHighlight : Theme.notchBorderSubtle)
                            border.width: wpCard.isSelected ? 2 : 1
                            clip: true
                            LayoutMirroring.enabled: I18n.isRTL
                            LayoutMirroring.childrenInherit: true

                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Image {
                                anchors.fill: parent
                                anchors.margins: wpCard.isSelected ? 2 : 0
                                source: "file://" + wpCard.modelData.path
                                fillMode: Image.PreserveAspectCrop
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
                                color: Theme.colors.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(11)
                                    font.weight: Font.Bold
                                    color: "#ffffff"
                                }
                            }

                            // Bottom title bar
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 24
                                color: Qt.rgba(0, 0, 0, 0.75)

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

        // ── 3. Window Styling & Performance ───────────────────────
        SettingsSection {
            title: I18n.isRTL ? "تخصيص النوافذ والأداء" : "Window Styling & Performance"

            // Corner Radius
            SettingsRow {
                title: I18n.tr("corner_radius")
                subtitle: I18n.tr("corner_radius_desc")
                icon: "view-fullscreen-symbolic"
                showDivider: true

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [
                            { val: 4,  label: I18n.isRTL ? "حادة (4px)" : "Sharp (4px)" },
                            { val: 8,  label: I18n.isRTL ? "قياسية (8px)" : "Standard (8px)" },
                            { val: 14, label: I18n.isRTL ? "دائرية (14px)" : "Rounded (14px)" }
                        ]
                        delegate: Rectangle {
                            id: radPill
                            required property var modelData
                            readonly property bool isSelected: ConfigManager.elementRadius === modelData.val

                            height: 28
                            implicitWidth: radText.implicitWidth + Theme.space16
                            radius: 14
                            color: radPill.isSelected ? Theme.notchSurfaceActive : (radMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: radPill.isSelected ? Theme.notchBorderHighlight : (radMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                id: radText
                                anchors.centerIn: parent
                                text: radPill.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: radPill.isSelected ? Font.DemiBold : Font.Normal
                                color: radPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: radMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConfigManager.setElementRadius(radPill.modelData.val)
                            }
                        }
                    }
                }
            }

            // Font Scale
            SettingsRow {
                title: I18n.isRTL ? "حجم الخط" : "Font Size"
                subtitle: I18n.isRTL ? "ضبط مقياس حجم الخطوط في الواجهة" : "Adjust user interface text scaling"
                icon: "preferences-desktop-font-symbolic"
                showDivider: true

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [
                            { val: 0.85, label: I18n.isRTL ? "صغير" : "Small" },
                            { val: 1.0,  label: I18n.isRTL ? "قياسي" : "Standard" },
                            { val: 1.15, label: I18n.isRTL ? "كبير" : "Large" }
                        ]
                        delegate: Rectangle {
                            id: fontPill
                            required property var modelData
                            readonly property bool isSelected: Math.abs(ConfigManager.fontSizeScale - modelData.val) < 0.05

                            height: 28
                            implicitWidth: fontText.implicitWidth + Theme.space16
                            radius: 14
                            color: fontPill.isSelected ? Theme.notchSurfaceActive : (fontMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: fontPill.isSelected ? Theme.notchBorderHighlight : (fontMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                id: fontText
                                anchors.centerIn: parent
                                text: fontPill.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: fontPill.isSelected ? Font.DemiBold : Font.Normal
                                color: fontPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: fontMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConfigManager.setFontSizeScale(fontPill.modelData.val)
                            }
                        }
                    }
                }
            }

            // Performance Tier
            SettingsRow {
                title: I18n.isRTL ? "مستوى التأثيرات الرسومية" : "Graphics & Visual Effects"
                subtitle: I18n.isRTL ? "التحكم بتأثيرات الزجاج والبلور والظلال وسلاسة الحركة" : "Control blur, acrylic glass, and layered shadow fidelity"
                icon: "power-profile-balanced-symbolic"
                showDivider: false

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [
                            { val: 0, label: I18n.isRTL ? "خفيف" : "Efficient" },
                            { val: 1, label: I18n.isRTL ? "متوازن" : "Balanced" },
                            { val: 2, label: I18n.isRTL ? "فائق" : "High" }
                        ]
                        delegate: Rectangle {
                            id: tierPill
                            required property var modelData
                            readonly property bool isSelected: ConfigManager.performanceTier === modelData.val

                            height: 28
                            implicitWidth: tierText.implicitWidth + Theme.space16
                            radius: 14
                            color: tierPill.isSelected ? Theme.notchSurfaceActive : (tierMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: tierPill.isSelected ? Theme.notchBorderHighlight : (tierMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                id: tierText
                                anchors.centerIn: parent
                                text: tierPill.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: tierPill.isSelected ? Font.DemiBold : Font.Normal
                                color: tierPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: tierMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConfigManager.setPerformanceTier(tierPill.modelData.val)
                            }
                        }
                    }
                }
            }
        }
    }
}
