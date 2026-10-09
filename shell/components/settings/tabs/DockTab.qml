// Dock — live preview, behaviour and pinned applications.
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

    ColumnLayout {
        id: mainCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.space24
        spacing: Theme.space24
        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        // ── 1. Live Interactive Dock Preview ─────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "المعاينة الحية لشريط المهام" : "Live Dock Preview"

            Item {
                Layout.fillWidth: true
                implicitHeight: 160
                clip: true

                // Mock Desktop Screen Area (Physical orientation: no mirroring)
                Rectangle {
                    id: mockDesktop
                    anchors.fill: parent
                    radius: Theme.notchRadiusCard
                    color: Theme.dockGlass
                    border.color: Theme.notchBorderSubtle
                    border.width: 1

                    // Subtle Desktop Wallpaper Preview
                    Image {
                        anchors.fill: parent
                        source: ConfigManager.fileUrl(ConfigManager.wallpaper)
                        fillMode: Image.PreserveAspectCrop
                        opacity: 0.45
                        sourceSize.width: Math.round(width * 2)   // preview card, not the full wallpaper
                        sourceSize.height: Math.round(height * 2)
                        cache: true
                        asynchronous: true
                    }

                    // Ambient vignette overlay
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.notchRadiusCard
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.imageScrimSoft }
                            GradientStop { position: 1.0; color: Theme.imageScrimStrong }
                        }
                    }

                    // Dynamic Mini Dock
                    Rectangle {
                        id: miniDock
                        readonly property bool isHorizontal: ConfigManager.dockPosition === "bottom"
                        readonly property int previewIconSz: isHorizontal
                            ? Math.max(20, Math.min(30, Math.round(ConfigManager.dockIconSize * 0.55)))
                            : 20
                        readonly property int previewDockH: previewIconSz + 12

                        implicitHeight: isHorizontal ? previewDockH : (miniDockLayout.implicitHeight + 14)
                        implicitWidth: isHorizontal ? (miniDockLayout.implicitWidth + 20) : previewDockH
                        width: implicitWidth
                        height: implicitHeight
                        radius: Math.min(previewDockH / 2, Theme.radiusDock)   // scales with the corner-radius setting, like the real Dock
                        color: Theme.dockGlass            // the real Dock's surface, in both modes
                        border.color: Theme.notchBorderHighlight
                        border.width: 1

                        // Absolute Physical Coordinates (immune to LayoutMirroring)
                        x: {
                            if (ConfigManager.dockPosition === "left") return 12;
                            if (ConfigManager.dockPosition === "right") return mockDesktop.width - width - 12;
                            return (mockDesktop.width - width) / 2;
                        }
                        y: {
                            if (ConfigManager.dockPosition === "bottom") return mockDesktop.height - height - 10;
                            return (mockDesktop.height - height) / 2;
                        }

                        opacity: ConfigManager.dockMode === "disabled" ? 0.25 : (ConfigManager.dockAutoHide ? 0.65 : 1.0)
                        Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }
                        Behavior on implicitWidth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Behavior on implicitHeight { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                        // Layout for icons (horizontal for bottom, vertical for left/right)
                        GridLayout {
                            id: miniDockLayout
                            anchors.centerIn: parent
                            columns: miniDock.isHorizontal ? 99 : 1
                            rows: miniDock.isHorizontal ? 1 : 99
                            rowSpacing: 4
                            columnSpacing: 6

                            Repeater {
                                model: {
                                    return ApplicationManager.pinnedAppIds.slice(0, miniDock.isHorizontal ? 5 : 4);
                                }

                                delegate: Item {
                                    id: previewItem
                                    required property var modelData
                                    required property int index

                                    implicitWidth: miniDock.previewIconSz
                                    implicitHeight: miniDock.previewIconSz + (miniDock.isHorizontal ? 6 : 0)

                                    Item {
                                        anchors.centerIn: parent
                                        width: miniDock.previewIconSz
                                        height: miniDock.previewIconSz

                                        AppIcon {
                                            anchors.fill: parent
                                            iconSize: miniDock.previewIconSz
                                            source: {
                                                const app = ApplicationManager.findApp(previewItem.modelData);
                                                return app && app.icon ? app.icon : previewItem.modelData;
                                            }
                                        }
                                    }

                                    // Running-app indicator, as the Dock draws it: the first two
                                    // preview apps are open, the first one active (longer dot).
                                    Rectangle {
                                        readonly property bool isActive: previewItem.index === 0
                                        visible: ConfigManager.dockIndicator === "all" ? previewItem.index < 2
                                               : (ConfigManager.dockIndicator === "active" && isActive)
                                        // Physical x/y (like Dock.qml): conditional anchors flip at
                                        // runtime and are swapped by the tab's RTL mirroring.
                                        x: miniDock.isHorizontal ? Math.round((parent.width - width) / 2)
                                           : (ConfigManager.dockPosition === "left" ? parent.width - width : 0)
                                        y: miniDock.isHorizontal ? parent.height - height : Math.round((parent.height - height) / 2)
                                        width: miniDock.isHorizontal && isActive ? 8 : 3
                                        height: !miniDock.isHorizontal && isActive ? 8 : 3
                                        radius: 1.5
                                        color: isActive ? Theme.dockIndicator : Theme.dockIndicatorIdle
                                        Behavior on width { NumberAnimation { duration: Theme.motionFast } }
                                    }
                                }
                            }

                            // Divider
                            Rectangle {
                                Layout.preferredWidth: miniDock.isHorizontal ? 1 : Math.round(miniDock.previewIconSz * 0.7)
                                Layout.preferredHeight: miniDock.isHorizontal ? Math.round(miniDock.previewIconSz * 0.7) : 1
                                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                                color: Theme.notchBorderHighlight
                            }

                            // App drawer launcher icon
                            Item {
                                implicitWidth: miniDock.previewIconSz
                                implicitHeight: miniDock.previewIconSz + (miniDock.isHorizontal ? 6 : 0)

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: miniDock.previewIconSz
                                    height: miniDock.previewIconSz
                                    radius: width / 2
                                    color: Theme.notchSurfaceActive

                                    SymbolicIcon {
                                        anchors.centerIn: parent
                                        iconSize: Math.round(miniDock.previewIconSz * 0.55)
                                        source: "view-app-grid"
                                        iconColor: Theme.notchText
                                    }
                                }
                            }

                            // Trash divider & icon preview
                            Rectangle {
                                visible: ConfigManager.dockShowTrash
                                Layout.preferredWidth: miniDock.isHorizontal ? 1 : Math.round(miniDock.previewIconSz * 0.7)
                                Layout.preferredHeight: miniDock.isHorizontal ? Math.round(miniDock.previewIconSz * 0.7) : 1
                                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                                color: Theme.notchBorderHighlight
                            }

                            Item {
                                visible: ConfigManager.dockShowTrash
                                implicitWidth: miniDock.previewIconSz
                                implicitHeight: miniDock.previewIconSz + (miniDock.isHorizontal ? 6 : 0)

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: miniDock.previewIconSz
                                    height: miniDock.previewIconSz
                                    radius: width / 2
                                    color: "transparent"

                                    SymbolicIcon {
                                        anchors.centerIn: parent
                                        iconSize: Math.round(miniDock.previewIconSz * 0.55)
                                        source: "user-trash-symbolic"
                                        iconColor: Theme.notchTextSecondary
                                    }
                                }
                            }
                        }
                    }

                    // Live Status Pill Badge (Top-Right of mock desktop)
                    Rectangle {
                        id: statusBadge
                        x: mockDesktop.width - width - 10
                        y: 10
                        height: 22
                        implicitWidth: statusText.implicitWidth + 16
                        width: implicitWidth
                        radius: 11
                        color: Theme.captionScrim
                        border.color: Theme.notchBorderSubtle
                        border.width: 1

                        Text {
                            id: statusText
                            anchors.centerIn: parent
                            text: (ConfigManager.dockAutoHide
                                ? (I18n.isRTL ? "إخفاء تلقائي" : "Auto-Hide")
                                : (I18n.isRTL ? "شريط ثابت" : "Fixed")) + " • " + (
                                ConfigManager.dockPosition === "bottom" ? (I18n.isRTL ? "أسفل" : "Bottom") :
                                ConfigManager.dockPosition === "left" ? (I18n.isRTL ? "يسار" : "Left") :
                                (I18n.isRTL ? "يمين" : "Right")
                            )
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(10)
                            font.weight: Font.Medium
                            color: Theme.notchTextSecondary
                        }
                    }
                }
            }
        }

        // ── 2. Look: size and screen edge ────────────────────────────
        SettingsSection {
            title: I18n.tr("dock_section_look")

            SettingsRow {
                title: I18n.tr("dock_icon_size")
                subtitle: I18n.tr("dock_icon_size_desc")
                icon: "zoom-in-symbolic"

                SettingsChoice {
                    options: [
                        { value: 36, label: I18n.tr("dock_size_small") },
                        { value: 44, label: I18n.tr("dock_size_medium") },
                        { value: 48, label: I18n.tr("dock_size_standard") },
                        { value: 56, label: I18n.tr("dock_size_large") }
                    ]
                    current: ConfigManager.dockIconSize
                    onChosen: v => ConfigManager.setDockIconSize(v)
                }
            }

            SettingsRow {
                title: I18n.tr("dock_position")
                subtitle: I18n.tr("dock_position_desc")
                icon: "view-fullscreen-symbolic"
                showDivider: false

                // Physical screen edges: Left · Bottom · Right in both languages
                SettingsChoice {
                    mirror: false
                    options: [
                        { value: "left",   label: I18n.tr("dock_edge_left") },
                        { value: "bottom", label: I18n.tr("dock_edge_bottom") },
                        { value: "right",  label: I18n.tr("dock_edge_right") }
                    ]
                    current: ConfigManager.dockPosition
                    onChosen: v => ConfigManager.setDockPosition(v)
                }
            }
        }

        // ── 3. Behaviour: when the Dock shows ────────────────────────
        SettingsSection {
            title: I18n.tr("dock_section_behavior")

            SettingsRow {
                title: I18n.tr("dock_mode")
                subtitle: I18n.tr("dock_mode_desc_" + (ConfigManager.dockMode || "always"))
                icon: "view-reveal-symbolic"
                showDivider: false

                SettingsChoice {
                    options: [
                        { value: "always",      label: I18n.tr("dock_mode_always") },
                        { value: "autohide",    label: I18n.tr("dock_mode_autohide") },
                        { value: "disabled",    label: I18n.tr("dock_mode_disabled") }
                    ]
                    current: ConfigManager.dockMode || "always"
                    onChosen: v => ConfigManager.setDockMode(v)
                }
            }
        }

        // ── 4. Contents: running-app indicator and trash ─────────────
        SettingsSection {
            visible: ConfigManager.dockMode !== "disabled"
            title: I18n.tr("dock_section_contents")

            SettingsRow {
                title: I18n.tr("dock_indicator")
                subtitle: I18n.tr("dock_indicator_desc_" + ConfigManager.dockIndicator)
                icon: "media-record-symbolic"

                SettingsChoice {
                    options: [
                        { value: "all",    label: I18n.tr("dock_indicator_all") },
                        { value: "active", label: I18n.tr("dock_indicator_active") },
                        { value: "none",   label: I18n.tr("dock_indicator_none") }
                    ]
                    current: ConfigManager.dockIndicator
                    onChosen: v => ConfigManager.setDockIndicator(v)
                }
            }

            SettingsRow {
                title: I18n.tr("dock_trash")
                subtitle: I18n.tr("dock_trash_desc")
                icon: "user-trash-symbolic"
                showDivider: false
                clickable: true
                onClicked: ConfigManager.setDockShowTrash(!ConfigManager.dockShowTrash)

                SettingsToggle {
                    checked: ConfigManager.dockShowTrash
                    onToggled: ch => ConfigManager.setDockShowTrash(ch)
                }
            }
        }

        // ── 5. Pinned Applications ───────────────────────────────────
        SettingsSection {
            title: (I18n.isRTL ? "إدارة التطبيقات المثبتة (" : "Pinned Applications (") +
                   (ApplicationManager.pinnedAppIds ? ApplicationManager.pinnedAppIds.length : 0) + ")"

            // Restore Defaults Action Row
            SettingsRow {
                title: I18n.isRTL ? "استعادة التطبيقات الافتراضية" : "Restore Default Pinned Apps"
                subtitle: I18n.isRTL ? "إعادة ضبط قائمة التطبيقات المثبتة إلى الإعدادات الأساسية" : "Reset pinned apps list to factory defaults"
                icon: "dialog-warning-symbolic"
                showDivider: ApplicationManager.pinnedAppIds && ApplicationManager.pinnedAppIds.length > 0

                Rectangle {
                    id: resetBtn
                    height: 28
                    implicitWidth: resetText.implicitWidth + Theme.space24
                    radius: 14
                    color: resetMa.pressed ? Theme.notchSurfaceActive : (resetMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceElevated)
                    border.color: resetMa.containsMouse ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                    Text {
                        id: resetText
                        anchors.centerIn: parent
                        text: I18n.isRTL ? "استعادة" : "Reset"
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(11)
                        font.weight: Font.DemiBold
                        color: resetMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                    }

                    MouseArea {
                        id: resetMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            ConfigManager.resetPinnedApps();
                        }
                    }
                }
            }

            // Pinned Apps List
            Repeater {
                model: ApplicationManager.pinnedAppIds
                delegate: SettingsRow {
                    id: appRow
                    required property var modelData
                    required property int index

                    readonly property var appInfo: ApplicationManager.findApp(modelData)
                    readonly property string appName: (appInfo && appInfo.name) ? appInfo.name : modelData
                    readonly property string appIconName: (appInfo && appInfo.icon) ? appInfo.icon : modelData
                    readonly property string appComment: (appInfo && appInfo.comment) ? appInfo.comment : (I18n.isRTL ? "تطبيق مثبت في الشريط" : "Pinned Application")

                    title: appName
                    subtitle: appComment
                    appIcon: appIconName
                    showDivider: index < (ApplicationManager.pinnedAppIds.length - 1)

                    // Unpin Action Button
                    Rectangle {
                        id: unpinBtn
                        height: 28
                        width: 28
                        radius: 14
                        color: unpinMa.pressed ? Theme.notchSurfaceActive : (unpinMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceElevated)
                        border.color: unpinMa.containsMouse ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                        SymbolicIcon {
                            anchors.centerIn: parent
                            iconSize: 14
                            source: "user-trash-symbolic"
                            iconColor: unpinMa.containsMouse ? Theme.danger : Theme.notchTextSecondary
                        }

                        MouseArea {
                            id: unpinMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                ApplicationManager.unpinApp(appRow.modelData);
                            }
                        }
                    }
                }
            }

            // Empty State
            SettingsRow {
                visible: !ApplicationManager.pinnedAppIds || ApplicationManager.pinnedAppIds.length === 0
                title: I18n.isRTL ? "لا توجد تطبيقات مثبتة حالياً" : "No Pinned Applications"
                subtitle: I18n.isRTL ? "يمكنك تثبيت التطبيقات من درج التطبيقات أو استعادة الافتراضي أعلاه" : "Pin apps from app drawer or restore defaults above"
                icon: "dialog-warning-symbolic"
                showDivider: false
            }
        }
    }
}
