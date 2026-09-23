import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services"
import ".."
import "../timecapsule"

// NotificationCard — the ONE notification renderer used by every surface.
//
//   variant "banner"  one line inside the compact Notch pill (44px tall):
//                     [icon] [summary]  [body……]            [✕]
//   variant "card"    history list / toast / expanded Notch:
//                     [icon] app · time                      [✕]
//                            summary (≤2 lines)
//                            body    (≤maxBodyLines)
//
// RTL rules applied everywhere:
//   • Layout order follows the UI direction (LayoutMirroring) — icon on the reading-start
//     side, dismiss on the reading-end side.
//   • Every Text sets horizontalAlignment explicitly → edges align to the UI start
//     regardless of the string's language (no jagged mixed-language cards).
//   • Paragraph direction is decided per string by NotificationManager.bidi() (RLM for
//     any Arabic), so "report.pdf تم التنزيل" reads correctly right-to-left.
//   • PlainText only (eliding works; no markup metric jumps); no letterSpacing
//     (it breaks Arabic joining).
Item {
    id: root

    property var notif: null
    property string variant: "card"
    property bool closable: true
    property bool alwaysShowClose: false
    property int maxBodyLines: 3
    property real iconSize: variant === "banner" ? 24 : 36
    property real progress: -1              // 0..1 → hairline countdown; <0 hides it
    property bool showTime: true

    readonly property bool hovered: hover.hovered
    signal closeRequested()
    signal activated()

    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    readonly property string appName: notif && notif.appName ? notif.appName : ""
    readonly property string summary: notif ? NotificationManager.bidi(notif.summary || "") : ""
    readonly property string body: notif ? NotificationManager.bidi(
        root.variant === "banner" ? NotificationManager.plainText(notif.body || "", true) : (notif.body || "")) : ""
    readonly property string timeText: notif && root.showTime ? NotificationManager.timeLabel(notif.timestamp) : ""
    readonly property bool critical: notif ? notif.urgency === 2 : false

    implicitWidth: variant === "banner" ? bannerRow.implicitWidth : 320
    implicitHeight: variant === "banner" ? 44 : cardCol.implicitHeight + (progress >= 0 ? 6 : 0)

    HoverHandler { id: hover }
    TapHandler { onTapped: root.activated() }

    // ── Shared dismiss button (reading-end side) ─────────────────────────
    component CloseButton: Rectangle {
        id: cb
        property real diameter: 22
        implicitWidth: diameter
        implicitHeight: diameter
        radius: diameter / 2
        color: cbMa.pressed ? Theme.notchSurfaceActive : (cbMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.motionFast } }

        SymbolicIcon {
            anchors.centerIn: parent
            iconSize: Math.round(cb.diameter * 0.5)
            source: "window-close-symbolic"
            iconColor: cbMa.containsMouse ? Theme.notchText : Theme.notchTextTertiary
        }
        MouseArea {
            id: cbMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closeRequested()
        }
    }

    // ═════════════════════════════════════════════════════════════════════
    // BANNER — single line, vertically centred in the 44px pill
    // ═════════════════════════════════════════════════════════════════════
    RowLayout {
        id: bannerRow
        visible: root.variant === "banner"
        anchors.fill: parent
        // Pill ends are 22px radii: keep content clear of the curve on both sides.
        anchors.leftMargin: 11
        anchors.rightMargin: 11
        spacing: 10

        NotificationIcon {
            Layout.alignment: Qt.AlignVCenter
            size: root.iconSize
            source: root.notif ? (root.notif.iconSource || "") : ""
        }

        Text {
            id: bannerSummary
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: Math.round(bannerRow.width * 0.42)
            text: root.summary.length > 0 ? root.summary : root.appName
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideRight
            maximumLineCount: 1
            font.family: Theme.typography.fontFamily
            font.pixelSize: Theme.fontSize(13)
            font.weight: Font.Bold
            color: Theme.notchText
            renderType: Theme.renderType
        }

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            visible: root.body.length > 0
            text: root.body
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideRight
            maximumLineCount: 1
            font.family: Theme.typography.fontFamily
            font.pixelSize: Theme.fontSize(12)
            color: Theme.notchTextBody
            font.weight: Font.Medium
            renderType: Theme.renderType
        }
        Item { Layout.fillWidth: true; visible: root.body.length === 0 }

        StatusDot { level: root.critical ? 2 : 0; Layout.alignment: Qt.AlignVCenter }

        CloseButton {
            visible: root.closable
            diameter: 22
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // ═════════════════════════════════════════════════════════════════════
    // CARD — icon column + text column, top-aligned
    // ═════════════════════════════════════════════════════════════════════
    ColumnLayout {
        id: cardCol
        visible: root.variant !== "banner"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            NotificationIcon {
                Layout.alignment: Qt.AlignTop
                size: root.iconSize
                source: root.notif ? (root.notif.iconSource || "") : ""
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 2

                // Meta row: app · time ··· [critical dot] [✕]
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        // Meta line follows the UI direction as one paragraph, so in Arabic the
                        // app name reads first (right) and the time second — even for Latin app names.
                        text: (I18n.isRTL ? "\u200F" : "")
                              + root.appName
                              + (root.timeText.length > 0 && root.appName.length > 0 ? "  ·  " : "")
                              + root.timeText
                        textFormat: Text.PlainText
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(11)
                        font.weight: Font.Medium
                        color: Theme.notchTextMeta
                        renderType: Theme.renderType
                    }

                    StatusDot { level: root.critical ? 2 : 0; Layout.alignment: Qt.AlignVCenter }

                    CloseButton {
                        visible: root.closable
                        diameter: 20
                        opacity: root.alwaysShowClose || root.hovered ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: root.summary
                    textFormat: Text.PlainText
                    horizontalAlignment: Text.AlignLeft
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(14)
                    font.weight: Font.Bold
                    color: Theme.notchText
                    renderType: Theme.renderType
                }

                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: root.body
                    textFormat: Text.PlainText
                    horizontalAlignment: Text.AlignLeft
                    wrapMode: Text.Wrap
                    maximumLineCount: root.maxBodyLines
                    elide: Text.ElideRight
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(13)
                    color: Theme.notchTextBody
                    font.weight: Font.Medium
                    renderType: Theme.renderType
                }
            }
        }

        // Screenshot preview (full width under the text)
        Rectangle {
            visible: Boolean(root.notif && root.notif.imagePath)
            Layout.fillWidth: true
            Layout.preferredHeight: 110
            radius: Theme.notchRadiusCard
            color: Theme.notchSurface
            border.color: Theme.notchBorderSubtle
            border.width: 1
            clip: true

            Image {
                anchors.fill: parent
                anchors.margins: 1
                source: (root.notif && root.notif.imagePath) ? "file://" + root.notif.imagePath : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
            }
        }
    }

    // Countdown hairline (reading direction: drains toward the start edge)
    Rectangle {
        visible: root.progress >= 0 && root.variant !== "banner"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 2
        radius: 1
        color: Theme.notchSurfaceHover

        Rectangle {
            anchors.left: parent.left
            height: parent.height
            width: Math.round(parent.width * Math.max(0, Math.min(1, root.progress)))
            radius: 1
            color: Theme.notchTextTertiary
        }
    }
}
