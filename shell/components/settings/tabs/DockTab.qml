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
                        source: ConfigManager.wallpaper ? (ConfigManager.wallpaper.startsWith("file://") ? ConfigManager.wallpaper : ("file://" + ConfigManager.wallpaper)) : ""
                        fillMode: Image.PreserveAspectCrop
                        opacity: 0.45
                        cache: true
                    }

                    // Ambient vignette overlay
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.notchRadiusCard
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.25) }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.65) }
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
                        radius: Math.min(previewDockH / 2, 14)
                        color: Qt.rgba(0.06, 0.07, 0.10, 0.90)
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
                                    const sourceList = (ApplicationManager.pinnedAppIds && ApplicationManager.pinnedAppIds.length > 0)
                                        ? ApplicationManager.pinnedAppIds
                                        : ConfigManager.defaultPinnedApps;
                                    return sourceList.slice(0, miniDock.isHorizontal ? 5 : 4);
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

                                    // Active window indicator dot
                                    Rectangle {
                                        visible: ConfigManager.showUnderline && (previewItem.index < 2)
                                        // Physical x/y (like Dock.qml): conditional anchors flip at
                                        // runtime and are swapped by the tab's RTL mirroring.
                                        x: miniDock.isHorizontal ? Math.round((parent.width - width) / 2)
                                           : (ConfigManager.dockPosition === "left" ? parent.width - width : 0)
                                        y: miniDock.isHorizontal ? parent.height - height : Math.round((parent.height - height) / 2)
                                        width: 3
                                        height: 3
                                        radius: 1.5
                                        color: Theme.dockDot
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
                        color: Qt.rgba(0, 0, 0, 0.70)
                        border.color: Theme.notchBorderSubtle
                        border.width: 1

                        Text {
                            id: statusText
                            anchors.centerIn: parent
                            text: (ConfigManager.dockMode === "intellihide"
                                ? (I18n.isRTL ? "إخفاء ذكي" : "Intellihide")
                                : ConfigManager.dockAutoHide
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

        // ── 2. Dock Appearance & Behavior ────────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "إعدادات شريط المهام (Dock)" : "Dock Configuration"

            // Icon Size
            SettingsRow {
                title: I18n.tr("dock_icon_size")
                subtitle: I18n.tr("dock_icon_size_desc")
                icon: "preferences-desktop-font-symbolic"
                showDivider: true

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [
                            { val: 36, label: I18n.isRTL ? "صغير (36px)" : "Small (36px)" },
                            { val: 44, label: I18n.isRTL ? "متوسط (44px)" : "Medium (44px)" },
                            { val: 48, label: I18n.isRTL ? "قياسي (48px)" : "Standard (48px)" },
                            { val: 56, label: I18n.isRTL ? "كبير (56px)" : "Large (56px)" }
                        ]
                        delegate: Rectangle {
                            id: szPill
                            required property var modelData
                            readonly property bool isSelected: ConfigManager.dockIconSize === modelData.val

                            height: 28
                            implicitWidth: szText.implicitWidth + Theme.space16
                            radius: 14
                            color: szPill.isSelected ? Theme.notchSurfaceActive : (szMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: szPill.isSelected ? Theme.notchBorderHighlight : (szMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                id: szText
                                anchors.centerIn: parent
                                text: szPill.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: szPill.isSelected ? Font.DemiBold : Font.Normal
                                color: szPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: szMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConfigManager.setDockIconSize(szPill.modelData.val)
                            }
                        }
                    }
                }
            }

            // Dock Position
            SettingsRow {
                title: I18n.tr("dock_position")
                subtitle: I18n.tr("dock_position_desc")
                icon: "view-fullscreen-symbolic"
                showDivider: true

                // Physical screen edges: laid out Left · Bottom · Right in both languages
                // (mirroring put "Right" on the left in Arabic).
                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: false
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [
                            { val: "left",   label: I18n.isRTL ? "اليسار" : "Left" },
                            { val: "bottom", label: I18n.isRTL ? "أسفل الشاشة" : "Bottom" },
                            { val: "right",  label: I18n.isRTL ? "اليمين" : "Right" }
                        ]
                        delegate: Rectangle {
                            id: posPill
                            required property var modelData
                            readonly property bool isSelected: ConfigManager.dockPosition === modelData.val

                            height: 28
                            implicitWidth: posText.implicitWidth + Theme.space16
                            radius: 14
                            color: posPill.isSelected ? Theme.notchSurfaceActive : (posMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: posPill.isSelected ? Theme.notchBorderHighlight : (posMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                id: posText
                                anchors.centerIn: parent
                                text: posPill.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: posPill.isSelected ? Font.DemiBold : Font.Normal
                                color: posPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: posMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConfigManager.setDockPosition(posPill.modelData.val)
                            }
                        }
                    }
                }
            }

            // Dock Display Mode (Always / Auto-Hide / Disabled)
            SettingsRow {
                title: I18n.isRTL ? "وضع عرض شريط المهام" : "Dock Display Mode"
                subtitle: {
                    if (ConfigManager.dockMode === "disabled")
                        return I18n.isRTL ? "معطل تماماً ولا يستهلك أي موارد" : "Completely disabled, zero resource usage";
                    if (ConfigManager.dockMode === "intellihide")
                        return I18n.isRTL ? "يختفي فقط عندما تغطيه نافذة، ويظهر عند الاقتراب من الحافة"
                                          : "Hides only when a window overlaps it; reveal at the screen edge";
                    if (ConfigManager.dockMode === "autohide")
                        return I18n.isRTL ? "يختفي تلقائياً ويتمدد سطح المكتب لكامل الشاشة" : "Auto-hides, windows expand to full screen";
                    return I18n.isRTL ? "ظاهر دائماً مع حجز مساحة حقيقي للنوافذ" : "Always visible with reserved screen space";
                }
                icon: "settings-symbolic"
                showDivider: true

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [
                            { id: "always",   label: I18n.isRTL ? "دائماً" : "Always" },
                            { id: "autohide", label: I18n.isRTL ? "إخفاء تلقائي" : "Auto-Hide" },
                            { id: "intellihide", label: I18n.isRTL ? "إخفاء ذكي" : "Intellihide" },
                            { id: "disabled", label: I18n.isRTL ? "معطل" : "Disabled" }
                        ]
                        delegate: Rectangle {
                            id: modePill
                            required property var modelData
                            readonly property bool isSelected: (ConfigManager.dockMode || "always") === modelData.id

                            height: 28
                            implicitWidth: modeText.implicitWidth + Theme.space16
                            radius: 14
                            color: modePill.isSelected ? Theme.notchSurfaceActive : (modeMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: modePill.isSelected ? Theme.notchBorderHighlight : (modeMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                id: modeText
                                anchors.centerIn: parent
                                text: modePill.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: modePill.isSelected ? Font.DemiBold : Font.Normal
                                color: modePill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                                renderType: Theme.renderType
                            }

                            MouseArea {
                                id: modeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConfigManager.setDockMode(modePill.modelData.id)
                            }
                        }
                    }
                }
            }

            // Active Window Underline
            SettingsRow {
                title: I18n.tr("dock_underline")
                subtitle: I18n.tr("dock_underline_desc")
                icon: "display-brightness-symbolic"
                showDivider: false
                clickable: true
                onClicked: ConfigManager.setShowUnderline(!ConfigManager.showUnderline)

                SettingsToggle {
                    checked: ConfigManager.showUnderline
                    onToggled: ch => ConfigManager.setShowUnderline(ch)
                }
            }
        }

        // ── 3. Pinned Applications ───────────────────────────────────
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
                            ConfigManager.setPinnedApps(ConfigManager.defaultPinnedApps);
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
                        color: unpinMa.pressed ? Qt.rgba(0.9, 0.2, 0.2, 0.35) : (unpinMa.containsMouse ? Qt.rgba(0.9, 0.2, 0.2, 0.18) : Theme.notchSurfaceElevated)
                        border.color: unpinMa.containsMouse ? Qt.rgba(0.9, 0.2, 0.2, 0.5) : Theme.notchBorderSubtle
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                        SymbolicIcon {
                            anchors.centerIn: parent
                            iconSize: 14
                            source: "user-trash-symbolic"
                            iconColor: unpinMa.containsMouse ? Theme.urgent : Theme.notchTextSecondary
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
