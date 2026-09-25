import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../theme"
import "../../../services"
import "../../"

// App details (Settings → Apps), opened from the shared AppContextMenu → "App Info".
// Reads the live app state + the backend info (AppActions / deloway-app-info.py) and
// offers View in Store and Uninstall (with an inline confirmation).
ColumnLayout {
    id: root

    readonly property string desktopId: ShellState.appInfoId
    readonly property var app: desktopId ? AppActions.entryFor(desktopId) : null
    readonly property var info: AppActions.infoFor(desktopId)
    readonly property bool busy: AppActions.isUninstalling(desktopId)
    property bool confirming: false

    Layout.fillWidth: true
    spacing: 0
    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    onDesktopIdChanged: {
        confirming = false;
        if (desktopId) AppActions.requestInfo(desktopId);
    }
    Component.onCompleted: if (desktopId) AppActions.requestInfo(desktopId)

    // ── Header ───────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        Layout.margins: Theme.space16
        spacing: Theme.space16

        AppIcon {
            iconSize: 52
            source: root.app ? root.app.icon : ""
            Layout.alignment: Qt.AlignTop
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                Layout.fillWidth: true
                text: NotificationManager.bidi(root.app ? (root.app.name || root.app.id) : (root.info ? root.info.name : root.desktopId))
                textFormat: Text.PlainText
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(17)
                font.weight: Font.DemiBold
                color: Theme.notchText
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignLeft
                renderType: Theme.renderType
            }
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: NotificationManager.bidi(root.info ? (root.info.description || root.info.comment || "") : "")
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(12)
                color: Theme.notchTextMeta
                horizontalAlignment: Text.AlignLeft
                renderType: Theme.renderType
            }
            // Chips: source · version · running state
            Row {
                Layout.topMargin: 6
                spacing: 6
                Repeater {
                    model: {
                        const out = [];
                        if (root.info && root.info.ok) out.push(AppActions.sourceLabel(root.info));
                        if (root.info && root.info.version) out.push(root.info.version);
                        if (root.app && root.app.running) out.push(I18n.windowsCount(root.app.windowCount));
                        if (!root.info) out.push(I18n.tr("app_checking"));
                        return out;
                    }
                    delegate: Rectangle {
                        required property var modelData
                        height: 22
                        width: chipText.implicitWidth + 16
                        radius: 11
                        color: Theme.notchSurfaceHover
                        border.color: Theme.notchBorderSubtle
                        border.width: 1
                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: NotificationManager.bidi(String(parent.modelData))
                            textFormat: Text.PlainText
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            color: Theme.notchTextBody
                            renderType: Theme.renderType
                        }
                    }
                }
            }
        }
        // Close details
        Rectangle {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 28
            implicitHeight: 28
            radius: 14
            color: closeMa.containsMouse ? Theme.notchSurfaceHover : "transparent"
            SymbolicIcon {
                anchors.centerIn: parent
                source: "window-close-symbolic"
                iconSize: 13
                iconColor: closeMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
            }
            MouseArea {
                id: closeMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ShellState.appInfoId = ""
            }
        }
    }

    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.notchBorderSubtle }

    // ── Facts ────────────────────────────────────────────────────────────
    Repeater {
        model: {
            const i = root.info;
            if (!i || !i.ok) return [];
            const rows = [];
            if (i.package) rows.push({ k: "app_package", v: i.package });
            if (i.size) rows.push({ k: "app_size", v: i.size });
            if (i.installDate) rows.push({ k: "app_installed_on", v: i.installDate });
            if (i.url) rows.push({ k: "app_homepage", v: i.url, link: true });
            if (i.exec) rows.push({ k: "app_command", v: i.exec, mono: true });
            rows.push({ k: "app_launcher_file", v: i.desktopFile, mono: true });
            return rows;
        }
        delegate: RowLayout {
            id: factRow
            required property var modelData
            Layout.fillWidth: true
            Layout.leftMargin: Theme.space16
            Layout.rightMargin: Theme.space16
            Layout.topMargin: 7
            Layout.bottomMargin: 7
            spacing: Theme.space16

            Text {
                Layout.preferredWidth: 130
                text: I18n.tr(modelData.k)
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(12)
                color: Theme.notchTextMeta
                horizontalAlignment: Text.AlignLeft
                renderType: Theme.renderType
            }
            Text {
                Layout.fillWidth: true
                // Paths, commands and URLs are always LTR, even in the Arabic UI.
                text: modelData.v
                textFormat: Text.PlainText
                elide: Text.ElideMiddle
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(modelData.mono ? 11 : 12)
                font.underline: !!modelData.link && linkMa.containsMouse
                color: Theme.notchTextBody
                horizontalAlignment: Text.AlignLeft   // mirrored by LayoutMirroring
                renderType: Theme.renderType
                MouseArea {
                    id: linkMa
                    anchors.fill: parent
                    enabled: !!factRow.modelData.link
                    hoverEnabled: enabled
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: Quickshell.execDetached(["xdg-open", factRow.modelData.v])
                }
            }
        }
    }

    // Why it can't be uninstalled (protected / required / unmanaged)
    Text {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.space16
        Layout.rightMargin: Theme.space16
        Layout.topMargin: 4
        visible: !!(root.info && root.info.ok && !root.info.removable)
        text: NotificationManager.bidi(AppActions.uninstallSummary(root.info))
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        font.family: Theme.typography.fontFamily
        font.pixelSize: Theme.fontSize(11)
        color: Theme.notchTextMeta
        horizontalAlignment: Text.AlignLeft
        renderType: Theme.renderType
    }

    // ── Actions ──────────────────────────────────────────────────────────
    // Only what belongs on a details page: View in Store (pamac can show system and AUR
    // packages) and Uninstall. Open / Pin live in the Dock and App Drawer (click and
    // right-click menu), next to the icon they act on.
    readonly property bool canViewInStore: !!(root.info && (root.info.source === "pacman" || root.info.source === "aur"))
    readonly property bool canUninstall: !!(root.info && root.info.ok && root.info.removable)
    readonly property string storeIcon: IconResolver.has("external-link-symbolic") ? IconResolver.directional("external-link-symbolic")
                                                                                 : IconResolver.directional("go-jump-symbolic")

    RowLayout {
        Layout.fillWidth: true
        Layout.margins: Theme.space16
        spacing: Theme.space8
        visible: !root.confirming && (root.canViewInStore || root.canUninstall)

        ActionButton {
            visible: root.canViewInStore
            variant: "quiet"
            iconSource: root.storeIcon
            text: I18n.tr("app_view_in_store")
            onClicked: AppActions.openInSoftwareCenter(root.info)
        }
        Item { Layout.fillWidth: true }
        // Destructive action alone at the far end.
        ActionButton {
            visible: root.canUninstall
            variant: "standard"
            iconSource: "user-trash-symbolic"
            text: root.busy ? I18n.tr("app_uninstalling") : I18n.tr("app_uninstall")
            enabled: !root.busy
            onClicked: root.confirming = true
        }
    }

    // Inline confirmation: what will be removed + Cancel / Uninstall
    RowLayout {
        Layout.fillWidth: true
        Layout.margins: Theme.space16
        spacing: Theme.space8
        visible: root.confirming

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: -2
            Text {
                Layout.fillWidth: true
                text: NotificationManager.bidi(I18n.tr("app_uninstall_confirm").replace("%1", I18n.isolate(root.app ? (root.app.name || root.app.id) : "")))
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(13)
                font.weight: Font.DemiBold
                color: Theme.notchText
                horizontalAlignment: Text.AlignLeft
                renderType: Theme.renderType
            }
            Text {
                Layout.fillWidth: true
                text: NotificationManager.bidi(AppActions.uninstallSummary(root.info))
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(12)
                color: Theme.notchTextMeta
                horizontalAlignment: Text.AlignLeft
                renderType: Theme.renderType
            }
        }
        ActionButton {
            variant: "quiet"
            text: I18n.tr("app_cancel")
            onClicked: root.confirming = false
        }
        ActionButton {
            variant: "primary"
            iconSource: "user-trash-symbolic"
            text: I18n.tr("app_uninstall_action")
            onClicked: { root.confirming = false; AppActions.uninstall(root.app); }
        }
    }

    // Compact pill button built only from Notch tokens (matches the Settings pills and the
    // app menu): quiet = borderless, standard = 1px border, primary = inverted.
    component ActionButton: Rectangle {
        id: ab
        property string text: ""
        property string iconSource: ""
        property string variant: "standard"          // quiet | standard | primary
        signal clicked()

        readonly property bool isPrimary: variant === "primary"
        implicitHeight: 30
        implicitWidth: abRow.implicitWidth + 24
        radius: height / 2
        opacity: enabled ? 1 : 0.45
        color: ab.isPrimary ? (abMa.pressed ? Theme.notchTextSecondary : Theme.notchText)
             : abMa.pressed ? Theme.notchSurfaceActive
             : abMa.containsMouse ? Theme.notchSurfaceHover
             : (variant === "standard" ? Theme.notchSurface : "transparent")
        border.color: variant === "standard" ? (abMa.containsMouse ? Theme.notchBorderHighlight : Theme.notchBorder) : "transparent"
        border.width: 1
        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

        readonly property color fg: ab.isPrimary ? Theme.notchBackground
                                  : (abMa.containsMouse || variant === "standard") ? Theme.notchText
                                  : Theme.notchTextSecondary

        Row {
            id: abRow
            anchors.centerIn: parent
            spacing: 6
            SymbolicIcon {
                visible: ab.iconSource.length > 0
                anchors.verticalCenter: parent.verticalCenter
                source: ab.iconSource
                iconSize: 13
                iconColor: ab.fg
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ab.text
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(12)
                font.weight: ab.isPrimary ? Font.DemiBold : Font.Medium
                color: ab.fg
                renderType: Theme.renderType
            }
        }
        MouseArea {
            id: abMa
            anchors.fill: parent
            enabled: ab.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ab.clicked()
        }
    }
}
