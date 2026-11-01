// UpdatesTab.qml — DeloWay System Updates and GitHub Sync
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
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

        // ── 1. Hero Status Card ──────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: heroLayout.implicitHeight + (Theme.space20 * 2)
            radius: Theme.radiusLarge
            color: Theme.notchSurfaceElevated
            border.color: UpdateService.hasUpdate ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
            border.width: 1

            Behavior on border.color { ColorAnimation { duration: Theme.motionNormal } }

            RowLayout {
                id: heroLayout
                anchors.fill: parent
                anchors.margins: Theme.space20
                spacing: Theme.space16
                LayoutMirroring.enabled: I18n.isRTL
                LayoutMirroring.childrenInherit: true

                // Status Icon with optional rotation while busy
                Item {
                    id: iconContainer
                    implicitWidth: 44
                    implicitHeight: 44
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: 22
                        color: UpdateService.hasUpdate ? Theme.notchSurfaceActive : Theme.notchSurface
                        border.color: UpdateService.hasUpdate ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                        border.width: 1

                        SymbolicIcon {
                            id: statusIcon
                            anchors.centerIn: parent
                            iconSize: 20
                            source: {
                                if (UpdateService.isBusy) return "view-refresh-symbolic";
                                if (UpdateService.hasUpdate) return "software-update-available-symbolic";
                                if (UpdateService.status === "error") return "dialog-warning-symbolic";
                                return "emblem-ok-symbolic";
                            }
                            iconColor: {
                                if (UpdateService.status === "error") return Theme.colors.urgent;
                                if (UpdateService.hasUpdate) return Theme.notchText;
                                return Theme.notchTextSecondary;
                            }

                            RotationAnimation on rotation {
                                running: UpdateService.isBusy
                                from: 0
                                to: 360
                                loops: Animation.Infinite
                                duration: 1000
                            }
                        }
                    }
                }

                // Text Description
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Theme.space4

                    RowLayout {
                        spacing: Theme.space8
                        LayoutMirroring.enabled: I18n.isRTL
                        LayoutMirroring.childrenInherit: true

                        // Small status dot (semantic color <= 8px)
                        Rectangle {
                            implicitWidth: 7
                            implicitHeight: 7
                            radius: 3.5
                            color: {
                                if (UpdateService.status === "error") return Theme.colors.urgent;
                                if (UpdateService.hasUpdate) return Theme.colors.warning;
                                if (UpdateService.status === "up_to_date") return Theme.colors.success;
                                return Theme.notchTextSecondary;
                            }
                        }

                        Text {
                            text: {
                                if (UpdateService.status === "checking") return I18n.tr("updates_checking");
                                if (UpdateService.status === "updating") return I18n.tr("updates_installing");
                                if (UpdateService.hasUpdate) return I18n.tr("updates_available_title");
                                if (UpdateService.status === "error") return I18n.tr("updates_error_title");
                                return I18n.tr("updates_up_to_date_title");
                            }
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(15)
                            font.weight: Font.DemiBold
                            color: Theme.notchText
                        }
                    }

                    Text {
                        text: {
                            if (UpdateService.status === "checking" || UpdateService.status === "updating")
                                return I18n.tr("updates_restart_note");
                            if (UpdateService.hasUpdate)
                                return UpdateService.commitsBehind + " " + I18n.tr("updates_available_desc");
                            if (UpdateService.status === "error")
                                return UpdateService.errorMessage || I18n.tr("updates_error_network");
                            return I18n.tr("updates_up_to_date_desc");
                        }
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(12)
                        color: Theme.notchTextSecondary
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        visible: UpdateService.lastChecked !== ""
                        text: I18n.tr("updates_last_checked") + " " + UpdateService.lastChecked
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(11)
                        color: Theme.notchTextTertiary
                    }
                }

                // Action Buttons
                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Theme.space8

                    // Primary Action (Update & Install Now when available)
                    Rectangle {
                        visible: UpdateService.hasUpdate && !UpdateService.isBusy
                        height: 32
                        implicitWidth: installBtnText.implicitWidth + Theme.space24
                        radius: 16
                        color: installMa.pressed ? Theme.primaryHover : Theme.inverseSurface
                        border.color: Theme.inverseSurface
                        border.width: 1

                        Text {
                            id: installBtnText
                            anchors.centerIn: parent
                            text: I18n.tr("updates_install_now")
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            font.weight: Font.DemiBold
                            color: Theme.inverseText
                        }

                        MouseArea {
                            id: installMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: UpdateService.applyUpdate()
                        }
                    }

                    // Check for Updates Button
                    Rectangle {
                        height: 32
                        implicitWidth: checkBtnText.implicitWidth + Theme.space24
                        radius: 16
                        color: checkMa.pressed ? Theme.notchSurfaceActive : (checkMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurface)
                        border.color: checkMa.containsMouse ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                        border.width: 1
                        enabled: !UpdateService.isBusy
                        opacity: enabled ? 1.0 : 0.5

                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                        Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                        Text {
                            id: checkBtnText
                            anchors.centerIn: parent
                            text: UpdateService.isBusy ? I18n.tr("updates_checking") : I18n.tr("updates_check_now")
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            font.weight: Font.Medium
                            color: Theme.notchText
                        }

                        MouseArea {
                            id: checkMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: UpdateService.checkForUpdates()
                        }
                    }
                }
            }
        }

        // ── 2. Update Channel Section ────────────────────────────────
        SettingsSection {
            title: I18n.tr("updates_channel_title")

            SettingsRow {
                title: I18n.tr("updates_channel_title")
                subtitle: I18n.tr("updates_channel_desc")
                icon: "preferences-system-symbolic"
                showDivider: false

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [
                            { id: "dev",    label: I18n.tr("updates_channel_dev") },
                            { id: "stable", label: I18n.tr("updates_channel_stable") }
                        ]
                        delegate: Rectangle {
                            id: channelPill
                            required property var modelData
                            readonly property bool isSelected: (ConfigManager.updateChannel || "dev") === modelData.id

                            height: 28
                            implicitWidth: pillText.implicitWidth + Theme.space20
                            radius: 14
                            color: isSelected ? Theme.notchSurfaceActive : (pillMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: isSelected ? Theme.notchBorderHighlight : (pillMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                id: pillText
                                anchors.centerIn: parent
                                text: channelPill.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: channelPill.isSelected ? Font.DemiBold : Font.Normal
                                color: channelPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: pillMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConfigManager.setUpdateChannel(channelPill.modelData.id)
                            }
                        }
                    }
                }
            }
        }

        // ── 3. System Version & Build Info ───────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "معلومات النسخة الحالية" : "Current Build Info"

            SettingsRow {
                title: I18n.tr("updates_current_version")
                subtitle: UpdateService.currentVersion + " (" + (UpdateService.currentCommitMsg || "Latest") + ")"
                icon: "dialog-information-symbolic"
                showDivider: true

                Rectangle {
                    height: 24
                    implicitWidth: verBadge.implicitWidth + 16
                    radius: 12
                    color: Theme.notchSurfaceActive
                    border.color: Theme.notchBorderHighlight
                    border.width: 1

                    Text {
                        id: verBadge
                        anchors.centerIn: parent
                        text: UpdateService.currentCommit ? ("#" + UpdateService.currentCommit) : "master"
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(10)
                        font.weight: Font.DemiBold
                        color: Theme.notchText
                    }
                }
            }

            SettingsRow {
                title: I18n.isRTL ? "مسار التحديث والمستودع" : "Repository Source"
                subtitle: UpdateService.repositoryUrl || "https://github.com/DeloNest/DeloWay-releases.git"
                icon: "emblem-synchronizing-symbolic"
                showDivider: false
            }
        }

        // ── 4. Changelog Section ─────────────────────────────────────
        SettingsSection {
            title: I18n.tr("updates_changelog_title")
            visible: UpdateService.changelog && UpdateService.changelog.length > 0

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.space8

                Repeater {
                    model: UpdateService.changelog
                    delegate: Rectangle {
                        id: changeCard
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: changeRow.implicitHeight + (Theme.space12 * 2)
                        radius: Theme.radiusMedium
                        color: Theme.notchSurface
                        border.color: Theme.notchBorderSubtle
                        border.width: 1

                        RowLayout {
                            id: changeRow
                            anchors.fill: parent
                            anchors.margins: Theme.space12
                            spacing: Theme.space12
                            LayoutMirroring.enabled: I18n.isRTL
                            LayoutMirroring.childrenInherit: true

                            // Hash pill
                            Rectangle {
                                height: 20
                                implicitWidth: hashText.implicitWidth + 10
                                radius: 10
                                color: Theme.notchSurfaceActive
                                border.color: Theme.notchBorder
                                border.width: 1

                                Text {
                                    id: hashText
                                    anchors.centerIn: parent
                                    text: changeCard.modelData.hash || ""
                                    font.family: Theme.baseTypography.terminalFont || "JetBrainsMono Nerd Font"
                                    font.pixelSize: Theme.fontSize(9)
                                    color: Theme.notchTextSecondary
                                }
                            }

                            // Subject & author
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: changeCard.modelData.subject || ""
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(12)
                                    font.weight: Font.Medium
                                    color: Theme.notchText
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: (changeCard.modelData.author || "") + " • " + (changeCard.modelData.date || "")
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(10)
                                    color: Theme.notchTextTertiary
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
