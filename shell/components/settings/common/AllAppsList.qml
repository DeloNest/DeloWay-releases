import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../theme"
import "../../../services"
import "../../"

// Settings → Apps → All Apps: every installed app, searchable. A row opens under itself
// the language the app runs in (the system's, Arabic or English — AppActions /
// deloway-app-language.py) and the app details card (info, View in Store, Uninstall with
// its confirmation). The bin button opens it straight at that confirmation.
ColumnLayout {
    id: root

    property string query: ""
    property string confirmFor: ""        // open the details card at "Uninstall?"

    Layout.fillWidth: true
    spacing: Theme.space12
    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    readonly property var apps: {
        const _r = ApplicationManager._entriesRevision;
        const q = root.query.trim().toLowerCase();
        return Array.from(DesktopEntries.applications.values)
            .filter(e => e && e.id && !e.noDisplay)
            .filter(e => !q || String(e.name).toLowerCase().indexOf(q) >= 0
                         || String(e.id).toLowerCase().indexOf(q) >= 0
                         || String(e.genericName || "").toLowerCase().indexOf(q) >= 0)
            .sort((a, b) => String(a.name).localeCompare(String(b.name)));
    }

    function toggle(desktopId, confirm) {
        root.confirmFor = confirm ? desktopId : "";
        if (confirm) ShellState.appInfoId = "";   // reload an open card at its confirmation
        ShellState.appInfoId = (ShellState.appInfoId === desktopId && !confirm) ? "" : desktopId;
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.space12

        DeloTextField {
            Layout.fillWidth: true
            implicitHeight: 38
            showSearchIcon: true
            placeholderText: I18n.tr("apps_search_placeholder")
            text: root.query
            onTextChanged: root.query = text
        }
        Text {
            text: I18n.appsCount(root.apps.length)
            font.family: Theme.typography.fontFamily
            font.pixelSize: Theme.fontSize(11)
            renderType: Theme.renderType
            color: Theme.notchTextSecondary
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: list.implicitHeight + Theme.space8
        radius: Theme.notchRadiusCard
        color: Theme.notchSurface
        border.width: 1
        border.color: Theme.notchBorderSubtle

        ColumnLayout {
            id: list
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: Theme.space4
            spacing: 0

            Text {
                visible: root.apps.length === 0
                Layout.alignment: Qt.AlignHCenter
                Layout.margins: Theme.space16
                text: I18n.tr("apps_search_none")
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(12)
                renderType: Theme.renderType
                color: Theme.notchTextTertiary
            }

            Repeater {
                model: root.apps

                delegate: ColumnLayout {
                    id: appRow
                    required property var modelData
                    required property int index
                    readonly property bool expanded: ShellState.appInfoId === appRow.modelData.id
                    readonly property string language: AppActions.appLanguage(appRow.modelData.id)
                    Layout.fillWidth: true
                    spacing: 0

                    Rectangle {
                        visible: appRow.index > 0
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.space16
                        Layout.rightMargin: Theme.space16
                        implicitHeight: 1
                        color: Theme.notchBorderSubtle
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 52
                        color: "transparent"

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 3
                            radius: Theme.notchRadiusCard - 4
                            color: appRow.expanded ? Theme.notchSurfaceActive
                                 : (rowMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                        }
                        MouseArea {
                            id: rowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggle(appRow.modelData.id, false)
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.space16
                            anchors.rightMargin: Theme.space12
                            spacing: Theme.space12

                            AppIcon {
                                source: appRow.modelData.icon || appRow.modelData.id
                                iconSize: 28
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    Layout.fillWidth: true
                                    text: appRow.modelData.name
                                    textFormat: Text.PlainText
                                    horizontalAlignment: Text.AlignLeft
                                    elide: Text.ElideRight
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(12)
                                    font.weight: Font.DemiBold
                                    renderType: Theme.renderType
                                    color: Theme.notchText
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                    text: appRow.modelData.genericName || appRow.modelData.comment || ""
                                    textFormat: Text.PlainText
                                    horizontalAlignment: Text.AlignLeft
                                    elide: Text.ElideRight
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(10)
                                    renderType: Theme.renderType
                                    color: Theme.notchTextTertiary
                                }
                            }
                            // Its own language, when it has one
                            Rectangle {
                                visible: appRow.language !== "system"
                                implicitHeight: 22
                                implicitWidth: langBadge.implicitWidth + Theme.space12
                                radius: 11
                                color: Theme.notchSurfaceElevated
                                border.width: 1
                                border.color: Theme.notchBorderSubtle
                                Text {
                                    id: langBadge
                                    anchors.centerIn: parent
                                    text: I18n.tr("app_language_" + appRow.language)
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(10)
                                    renderType: Theme.renderType
                                    color: Theme.notchText
                                }
                            }
                            Repeater {
                                model: [
                                    { icon: "info-symbolic", confirm: false },
                                    { icon: "user-trash-symbolic", confirm: true }
                                ]
                                delegate: Rectangle {
                                    id: rowBtn
                                    required property var modelData
                                    implicitWidth: 30
                                    implicitHeight: 30
                                    radius: 15
                                    color: btnMa.containsMouse ? Theme.notchSurfaceHover : "transparent"
                                    SymbolicIcon {
                                        anchors.centerIn: parent
                                        source: rowBtn.modelData.icon
                                        iconSize: 15
                                        iconColor: btnMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                                    }
                                    MouseArea {
                                        id: btnMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.toggle(appRow.modelData.id, rowBtn.modelData.confirm)
                                    }
                                }
                            }
                        }
                    }

                    // ── Opened: language + details ──
                    Loader {
                        Layout.fillWidth: true
                        active: appRow.expanded
                        visible: active
                        sourceComponent: ColumnLayout {
                            spacing: 0

                            SettingsRow {
                                title: I18n.tr("app_language")
                                subtitle: I18n.tr("app_language_note")
                                icon: "preferences-desktop-locale-symbolic"
                                showDivider: false

                                RowLayout {
                                    spacing: Theme.space4
                                    Repeater {
                                        model: ["system", "ar", "en"]
                                        delegate: Rectangle {
                                            id: langPill
                                            required property string modelData
                                            readonly property bool selected: appRow.language === langPill.modelData
                                            implicitHeight: 28
                                            implicitWidth: langText.implicitWidth + Theme.space16
                                            radius: 14
                                            color: langPill.selected ? Theme.inverseSurface
                                                 : (langMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                                            border.width: 1
                                            border.color: langPill.selected ? Theme.inverseSurface : Theme.notchBorderSubtle
                                            Text {
                                                id: langText
                                                anchors.centerIn: parent
                                                text: I18n.tr("app_language_" + langPill.modelData)
                                                font.family: Theme.typography.fontFamily
                                                font.pixelSize: Theme.fontSize(11)
                                                font.weight: langPill.selected ? Font.DemiBold : Font.Normal
                                                renderType: Theme.renderType
                                                color: langPill.selected ? Theme.inverseText : Theme.notchText
                                            }
                                            MouseArea {
                                                id: langMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: AppActions.setAppLanguage(appRow.modelData.id, langPill.modelData)
                                            }
                                        }
                                    }
                                }
                            }

                            AppDetailsCard {
                                Component.onCompleted: if (root.confirmFor === desktopId) confirming = true
                            }
                        }
                    }
                }
            }
        }
    }
}
