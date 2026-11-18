// DeloWay Display & Monitor Settings Tab
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../"
import "../../../services"
import "../../../theme"
import "../common"

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

        // ── 1. Visual Monitor Identity & Overview Card ───────────────
        SettingsSection {
            title: I18n.tr("display_preview_title")

            Item {
                Layout.fillWidth: true
                implicitHeight: monitorCardCol.implicitHeight + (Theme.space16 * 2)

                ColumnLayout {
                    id: monitorCardCol

                    anchors.fill: parent
                    anchors.margins: Theme.space16
                    spacing: Theme.space16
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    // Multi-monitor selector if multiple displays are present
                    RowLayout {
                        visible: DisplayService.monitors.length > 1
                        Layout.fillWidth: true
                        spacing: Theme.space8
                        LayoutMirroring.enabled: I18n.isRTL
                        LayoutMirroring.childrenInherit: true

                        Repeater {
                            model: DisplayService.monitors

                            delegate: Rectangle {
                                id: monTab

                                required property var modelData
                                required property int index
                                readonly property bool isSelected: DisplayService.activeMonitorIndex === monTab.index

                                implicitHeight: 32
                                implicitWidth: monTabText.implicitWidth + Theme.space24
                                radius: 16
                                color: monTab.isSelected ? Theme.inverseSurface : (monTabMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                                border.width: 1
                                border.color: monTab.isSelected ? Theme.inverseSurface : (monTabMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)

                                Text {
                                    id: monTabText

                                    anchors.centerIn: parent
                                    text: (monTab.index + 1) + " · " + monTab.modelData.name
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(11)
                                    font.weight: monTab.isSelected ? Font.DemiBold : Font.Normal
                                    color: monTab.isSelected ? Theme.inverseText : Theme.notchTextSecondary
                                }

                                MouseArea {
                                    id: monTabMa

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: DisplayService.selectMonitor(monTab.index)
                                }

                            }

                        }

                    }

                    // Stylized Screen Representation: Multi-Monitor Canvas or Single Monitor Bezel
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: DisplayService.monitors.length > 1 ? 140 : 140
                        Layout.alignment: Qt.AlignHCenter

                        // Multi-Monitor Interactive Canvas
                        RowLayout {
                            visible: DisplayService.monitors.length > 1
                            anchors.centerIn: parent
                            spacing: Theme.space16
                            LayoutMirroring.enabled: false

                            Repeater {
                                model: DisplayService.monitors

                                delegate: Rectangle {
                                    id: multiMonBox

                                    required property var modelData
                                    required property int index
                                    readonly property bool isSelected: DisplayService.activeMonitorIndex === multiMonBox.index

                                    width: 160
                                    height: 100
                                    radius: 8
                                    color: multiMonBox.isSelected ? Theme.notchSurfaceActive : Theme.notchSurface
                                    border.color: multiMonBox.isSelected ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                                    border.width: multiMonBox.isSelected ? 2 : 1

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        // Number Badge
                                        Rectangle {
                                            Layout.alignment: Qt.AlignHCenter
                                            width: 24
                                            height: 24
                                            radius: 12
                                            color: multiMonBox.isSelected ? Theme.inverseSurface : Theme.notchSurfaceElevated
                                            border.color: multiMonBox.isSelected ? Theme.inverseSurface : Theme.notchBorderSubtle
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: String(multiMonBox.index + 1)
                                                font.family: Theme.typography.fontFamily
                                                font.pixelSize: Theme.fontSize(11)
                                                font.weight: Font.Bold
                                                color: multiMonBox.isSelected ? Theme.inverseText : Theme.notchText
                                            }

                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: multiMonBox.modelData.name
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: Theme.fontSize(11)
                                            font.weight: Font.DemiBold
                                            color: Theme.notchText
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: multiMonBox.modelData.width + " × " + multiMonBox.modelData.height
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: Theme.fontSize(10)
                                            color: Theme.notchTextSecondary
                                        }

                                        Rectangle {
                                            visible: !!multiMonBox.modelData.isPrimary
                                            Layout.alignment: Qt.AlignHCenter
                                            implicitWidth: primaryTag.implicitWidth + 8
                                            implicitHeight: 16
                                            radius: 3
                                            color: Theme.notchSurfaceElevated
                                            border.color: Theme.notchBorderSubtle
                                            border.width: 1

                                            Text {
                                                id: primaryTag

                                                anchors.centerIn: parent
                                                text: I18n.tr("display_primary")
                                                font.family: Theme.typography.fontFamily
                                                font.pixelSize: Theme.fontSize(8)
                                                font.weight: Font.DemiBold
                                                color: Theme.notchTextSecondary
                                            }

                                        }

                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: DisplayService.selectMonitor(multiMonBox.index)
                                    }

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.motionFast
                                        }

                                    }

                                    Behavior on border.color {
                                        ColorAnimation {
                                            duration: Theme.motionFast
                                        }

                                    }

                                }

                            }

                        }

                        // Single Screen Representation (when 1 monitor is connected)
                        ColumnLayout {
                            visible: DisplayService.monitors.length <= 1
                            anchors.centerIn: parent
                            spacing: 0

                            // Screen Bezel
                            Rectangle {
                                id: screenBezel

                                width: 240
                                height: 110
                                radius: 8
                                color: Theme.colors.background
                                border.color: Theme.notchBorderHighlight
                                border.width: 2

                                // Inner Display Glass
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    radius: 6
                                    color: Theme.notchSurface

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: DisplayService.activeMonitor ? (DisplayService.activeMonitor.width + " × " + DisplayService.activeMonitor.height) : "—"
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: Theme.fontSize(14)
                                            font.weight: Font.Bold
                                            color: Theme.notchText
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: DisplayService.activeMonitor ? (Math.round(DisplayService.activeMonitor.refreshRate) + " Hz") : "—"
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: Theme.fontSize(11)
                                            font.weight: Font.DemiBold
                                            color: Theme.notchTextSecondary
                                        }

                                        // Badges row
                                        RowLayout {
                                            Layout.alignment: Qt.AlignHCenter
                                            spacing: 4

                                            Rectangle {
                                                visible: DisplayService.activeMonitor && DisplayService.activeMonitor.width === 2560
                                                implicitWidth: b2kText.implicitWidth + 8
                                                implicitHeight: 18
                                                radius: 4
                                                color: Theme.notchSurfaceActive
                                                border.color: Theme.notchBorderSubtle
                                                border.width: 1

                                                Text {
                                                    id: b2kText

                                                    anchors.centerIn: parent
                                                    text: "2K QHD"
                                                    font.family: Theme.typography.fontFamily
                                                    font.pixelSize: Theme.fontSize(9)
                                                    font.weight: Font.DemiBold
                                                    color: Theme.notchText
                                                }

                                            }

                                            Rectangle {
                                                visible: DisplayService.hdrSupported && DisplayService.hdrEnabled
                                                implicitWidth: hdrBadgeText.implicitWidth + 8
                                                implicitHeight: 18
                                                radius: 4
                                                color: Theme.notchSurfaceActive
                                                border.color: Theme.notchBorderHighlight
                                                border.width: 1

                                                Text {
                                                    id: hdrBadgeText

                                                    anchors.centerIn: parent
                                                    text: "HDR10"
                                                    font.family: Theme.typography.fontFamily
                                                    font.pixelSize: Theme.fontSize(9)
                                                    font.weight: Font.Bold
                                                    color: Theme.notchText
                                                }

                                            }

                                            Rectangle {
                                                implicitWidth: b10Text.implicitWidth + 8
                                                implicitHeight: 18
                                                radius: 4
                                                color: Theme.notchSurfaceElevated
                                                border.color: Theme.notchBorderSubtle
                                                border.width: 1

                                                Text {
                                                    id: b10Text

                                                    anchors.centerIn: parent
                                                    text: "10-bit"
                                                    font.family: Theme.typography.fontFamily
                                                    font.pixelSize: Theme.fontSize(9)
                                                    font.weight: Font.Normal
                                                    color: Theme.notchTextSecondary
                                                }

                                            }

                                        }

                                    }

                                }

                            }

                            // Stand Neck
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 28
                                height: 12
                                color: Theme.notchSurfaceActive
                                border.color: Theme.notchBorderSubtle
                                border.width: 1
                            }

                            // Stand Base
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 80
                                height: 4
                                radius: 2
                                color: Theme.notchSurfaceActive
                                border.color: Theme.notchBorderSubtle
                                border.width: 1
                            }

                        }

                    }

                    // Monitor Info & Port Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space8
                        LayoutMirroring.enabled: I18n.isRTL
                        LayoutMirroring.childrenInherit: true

                        // Status dot (Semantic green <= 8px for online hardware)
                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: Theme.colors.success
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            LayoutMirroring.enabled: I18n.isRTL
                            LayoutMirroring.childrenInherit: true

                            Text {
                                text: DisplayService.activeMonitor ? ((DisplayService.activeMonitor.make ? (DisplayService.activeMonitor.make + " ") : "") + (DisplayService.activeMonitor.model || DisplayService.activeMonitor.name)) : "—"
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(13)
                                font.weight: Font.DemiBold
                                color: Theme.notchText
                                horizontalAlignment: Text.AlignLeft
                            }

                            Text {
                                text: DisplayService.activeMonitor ? (DisplayService.activeMonitor.name + " · " + I18n.tr("display_primary")) : "—"
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                color: Theme.notchTextSecondary
                                horizontalAlignment: Text.AlignLeft
                            }

                        }

                        // Identify Displays Button
                        Rectangle {
                            implicitHeight: 28
                            implicitWidth: identifyBtnText.implicitWidth + Theme.space24
                            radius: 14
                            color: identifyMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceActive
                            border.color: identifyMa.containsMouse ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                            border.width: 1
                            Layout.alignment: Qt.AlignVCenter

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                SymbolicIcon {
                                    source: "view-reveal-symbolic"
                                    iconSize: 12
                                    iconColor: Theme.notchText
                                }

                                Text {
                                    id: identifyBtnText

                                    text: I18n.tr("display_identify")
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(11)
                                    font.weight: Font.DemiBold
                                    color: Theme.notchText
                                }

                            }

                            MouseArea {
                                id: identifyMa

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: DisplayService.identifyDisplays()
                            }

                        }

                    }

                }

            }

        }

        // ── Multi-Monitor Arrangement & Alignment (visible when multiple monitors exist) ──
        SettingsSection {
            title: I18n.tr("display_mode")
            visible: DisplayService.isMultiMonitor

            // Display Mode: Extend vs Mirror
            SettingsRow {
                title: I18n.tr("display_mode")
                subtitle: I18n.tr("display_mode_desc")
                icon: "video-display-symbolic"
                showDivider: true

                SettingsChoice {
                    options: [{
                        "value": "extend",
                        "label": I18n.tr("display_mode_extend")
                    }, {
                        "value": "mirror",
                        "label": I18n.tr("display_mode_mirror")
                    }]
                    current: DisplayService.isMirrored ? "mirror" : "extend"
                    onChosen: (val) => {
                        DisplayService.setMirrorMode(val === "mirror");
                    }
                }

            }

            // Screen Placement (Only if not mirrored)
            SettingsRow {
                visible: !DisplayService.isMirrored
                title: I18n.tr("display_placement")
                subtitle: I18n.tr("display_placement_desc")
                icon: "transform-rotate-symbolic"
                showDivider: true

                SettingsChoice {
                    options: [{
                        "value": "right",
                        "label": I18n.tr("display_placement_right")
                    }, {
                        "value": "left",
                        "label": I18n.tr("display_placement_left")
                    }, {
                        "value": "above",
                        "label": I18n.tr("display_placement_above")
                    }, {
                        "value": "below",
                        "label": I18n.tr("display_placement_below")
                    }]
                    current: (DisplayService.activeMonitor && DisplayService.activeMonitor.placement) ? DisplayService.activeMonitor.placement : "right"
                    onChosen: (val) => {
                        DisplayService.setPlacement(val);
                    }
                }

            }

            // Primary Screen Toggle
            SettingsRow {
                title: I18n.tr("display_set_primary")
                subtitle: I18n.tr("display_set_primary_desc")
                icon: "starred-symbolic"
                showDivider: false

                Rectangle {
                    implicitHeight: 28
                    implicitWidth: primaryBtnText.implicitWidth + Theme.space20
                    radius: 14
                    color: DisplayService.isPrimary ? Theme.inverseSurface : (setPrimaryMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceActive)
                    border.color: DisplayService.isPrimary ? Theme.inverseSurface : Theme.notchBorderSubtle
                    border.width: 1

                    Text {
                        id: primaryBtnText

                        anchors.centerIn: parent
                        text: DisplayService.isPrimary ? I18n.tr("display_is_primary_badge") : I18n.tr("display_set_primary")
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(11)
                        font.weight: Font.DemiBold
                        color: DisplayService.isPrimary ? Theme.inverseText : Theme.notchText
                    }

                    MouseArea {
                        id: setPrimaryMa

                        anchors.fill: parent
                        enabled: !DisplayService.isPrimary
                        hoverEnabled: enabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: DisplayService.setAsPrimary()
                    }

                }

            }

        }

        // ── 2. Resolution & Refresh Rate ─────────────────────────────
        SettingsSection {
            title: I18n.tr("display_section_resolution")

            // Resolution Row
            SettingsRow {
                title: I18n.tr("display_resolution")
                subtitle: {
                    if (!DisplayService.activeMonitor)
                        return "—";

                    const w = DisplayService.activeMonitor.width;
                    const h = DisplayService.activeMonitor.height;
                    let desc = w + " × " + h;
                    if (w === 2560 && h === 1440)
                        desc += " (" + (I18n.isRTL ? "2K QHD · 16:9 - مستحسن" : "2K QHD · 16:9 - Recommended") + ")";
                    else if (w === 1920 && h === 1080)
                        desc += " (FHD · 16:9)";
                    return desc;
                }
                icon: "video-display-symbolic"
                showDivider: true

                // Primary Resolution Pills
                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: {
                            const res = DisplayService.resolutions || [];
                            if (res.length === 0) {
                                return [
                                    { "id": "2560x1440", "label": "2560 × 1440 (2K)" },
                                    { "id": "1920x1080", "label": "1920 × 1080 (FHD)" },
                                    { "id": "1280x720", "label": "1280 × 720 (HD)" }
                                ];
                            }
                            const list = [];
                            const seen = {};
                            // 1. Add native resolution first
                            for (let i = 0; i < res.length; i++) {
                                if (res[i].isNative) {
                                    list.push({
                                        "id": res[i].id,
                                        "label": res[i].width + " × " + res[i].height + (I18n.isRTL ? " (أصلي)" : " (Native)")
                                    });
                                    seen[res[i].id] = true;
                                    break;
                                }
                            }
                            // 2. Add common popular resolutions supported by the monitor
                            const common = ["3840x2160", "2560x1440", "1920x1200", "1920x1080", "1680x1050", "1600x900", "1280x720"];
                            for (let c of common) {
                                if (!seen[c] && res.some(r => r.id === c)) {
                                    const match = res.find(r => r.id === c);
                                    let tag = "";
                                    if (c === "3840x2160") tag = " (4K)";
                                    else if (c === "2560x1440") tag = " (2K)";
                                    else if (c === "1920x1080") tag = " (FHD)";
                                    else if (c === "1280x720") tag = " (HD)";
                                    list.push({ "id": match.id, "label": match.width + " × " + match.height + tag });
                                    seen[c] = true;
                                    if (list.length >= 4) break;
                                }
                            }
                            // 3. Ensure current resolution is always present
                            if (DisplayService.currentResolution && !seen[DisplayService.currentResolution]) {
                                const cur = res.find(r => r.id === DisplayService.currentResolution);
                                list.push({
                                    "id": DisplayService.currentResolution,
                                    "label": cur ? (cur.width + " × " + cur.height) : DisplayService.currentResolution
                                });
                            }
                            return list;
                        }

                        delegate: Rectangle {
                            id: resPill

                            required property var modelData
                            readonly property bool isSelected: DisplayService.currentResolution === resPill.modelData.id

                            implicitHeight: 28
                            implicitWidth: resPillText.implicitWidth + Theme.space16
                            radius: 14
                            color: resPill.isSelected ? Theme.inverseSurface : (resMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.width: 1
                            border.color: resPill.isSelected ? Theme.inverseSurface : (resMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)

                            Text {
                                id: resPillText

                                anchors.centerIn: parent
                                text: resPill.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: resPill.isSelected ? Font.DemiBold : Font.Normal
                                color: resPill.isSelected ? Theme.inverseText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: resMa

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!resPill.isSelected)
                                        DisplayService.setResolution(resPill.modelData.id);

                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.motionFast
                                }

                            }

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: Theme.motionFast
                                }

                            }

                        }

                    }

                }

            }

            // Refresh Rate (Hz) Row
            SettingsRow {
                title: I18n.tr("display_refresh_rate")
                subtitle: I18n.tr("display_refresh_rate_desc")
                icon: "speedometer-symbolic"
                showDivider: false

                // Hz Pills for Current Resolution
                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: DisplayService.availableRates

                        delegate: Rectangle {
                            id: ratePill

                            required property var modelData
                            required property int index
                            readonly property real rateNum: Number(modelData)
                            readonly property bool isSelected: Math.abs(DisplayService.currentRefreshRate - ratePill.rateNum) < 1

                            implicitHeight: 28
                            implicitWidth: rateText.implicitWidth + Theme.space16
                            radius: 14
                            color: ratePill.isSelected ? Theme.inverseSurface : (rateMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.width: 1
                            border.color: ratePill.isSelected ? Theme.inverseSurface : (rateMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)

                            Text {
                                id: rateText

                                anchors.centerIn: parent
                                text: {
                                    const base = Math.round(ratePill.rateNum) + " Hz";
                                    if (ratePill.index === 0 && DisplayService.availableRates.length > 1)
                                        return base + " · " + I18n.tr("display_rate_highest");

                                    if (Math.round(ratePill.rateNum) === 60 && DisplayService.availableRates.length > 1)
                                        return base + " · " + I18n.tr("display_rate_saving");

                                    return base;
                                }
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: ratePill.isSelected ? Font.DemiBold : Font.Normal
                                color: ratePill.isSelected ? Theme.inverseText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: rateMa

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!ratePill.isSelected)
                                        DisplayService.setRefreshRate(ratePill.rateNum);

                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.motionFast
                                }

                            }

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: Theme.motionFast
                                }

                            }

                        }

                    }

                }

            }

        }

        // ── 3. Color Depth & Dynamic Range (HDR) ─────────────────────
        SettingsSection {
            title: I18n.tr("display_section_color")

            // HDR Toggle Row
            SettingsRow {
                title: I18n.tr("display_hdr")
                subtitle: DisplayService.hdrSupported ? I18n.tr("display_hdr_desc_supported") : I18n.tr("display_hdr_desc_unsupported")
                icon: "video-display-symbolic"
                showDivider: true

                RowLayout {
                    spacing: Theme.space8
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    // Informational Hardware Status Badge
                    Rectangle {
                        implicitHeight: 24
                        implicitWidth: hdrTagText.implicitWidth + Theme.space12
                        radius: 12
                        color: DisplayService.hdrSupported ? Theme.notchSurfaceActive : Theme.notchSurfaceElevated
                        border.color: DisplayService.hdrSupported ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                        border.width: 1

                        Text {
                            id: hdrTagText

                            anchors.centerIn: parent
                            text: DisplayService.hdrSupported ? I18n.tr("display_hdr_badge_supported") : I18n.tr("display_hdr_badge_unsupported")
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(10)
                            font.weight: DisplayService.hdrSupported ? Font.DemiBold : Font.Normal
                            color: DisplayService.hdrSupported ? Theme.notchText : Theme.notchTextTertiary
                        }

                    }

                    // HDR Toggle Switch (Visible at all times; disabled if hardware unsupported)
                    SettingsToggle {
                        enabled: DisplayService.hdrSupported
                        checked: DisplayService.hdrSupported && DisplayService.hdrEnabled
                        onToggled: (chk) => {
                            DisplayService.setHdr(chk);
                        }
                    }

                }

            }

            // Color Depth / 10-bit format
            SettingsRow {
                title: I18n.tr("display_color_format")
                subtitle: I18n.tr("display_color_format_desc")
                icon: "applications-graphics-symbolic"
                showDivider: false

                Rectangle {
                    implicitHeight: 28
                    implicitWidth: fmtText.implicitWidth + Theme.space16
                    radius: 14
                    color: Theme.notchSurfaceActive
                    border.color: Theme.notchBorderHighlight
                    border.width: 1

                    Text {
                        id: fmtText

                        anchors.centerIn: parent
                        text: (DisplayService.currentFormat && DisplayService.currentFormat.length > 0) ? (DisplayService.currentFormat + " (10-bit · 1.07B)") : "10-bit Wide Color"
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(11)
                        font.weight: Font.DemiBold
                        color: Theme.notchText
                    }

                }

            }

        }

        // ── 4. Eye Comfort & Night Light ─────────────────────────────
        SettingsSection {
            title: I18n.tr("display_section_night_light")

            // Display Brightness Slider
            SettingsRow {
                title: I18n.isRTL ? "سطوع الشاشة" : "Display Brightness"
                subtitle: {
                    if (BrightnessService.brightnessBackend === "ddc") {
                        return I18n.isRTL ? "تحكم حقيقي عبر كابل الشاشة (DisplayPort / HDMI - DDC/CI)" : "Hardware DDC/CI control via DisplayPort / HDMI";
                    } else if (BrightnessService.brightnessBackend === "kernel") {
                        return I18n.isRTL ? "تحكم حقيقي عبر إضاءة الشاشة الخلفية (Hardware Backlight)" : "Native display hardware backlight";
                    } else {
                        return I18n.isRTL ? "ضبط شدة إضاءة شاشة العرض الحالية" : "Adjust display backlight and luminance";
                    }
                }
                icon: "display-brightness-symbolic"
                showDivider: true

                SettingsSlider {
                    implicitWidth: 160
                    value: BrightnessService.screenBrightness
                    onMoved: v => BrightnessService.setBrightness(v)
                }
            }

            // Night Light Master Toggle
            SettingsRow {
                title: I18n.tr("display_night_light")
                subtitle: I18n.tr("display_night_light_desc")
                icon: "weather-clear-night-symbolic"
                showDivider: DisplayService.nightLightEnabled
                clickable: true
                onClicked: DisplayService.toggleNightLight()

                SettingsToggle {
                    checked: DisplayService.nightLightEnabled
                    onToggled: (chk) => {
                        DisplayService.setNightLight(chk, DisplayService.nightLightTemp);
                    }
                }

            }

            // Color Temperature Pills
            SettingsRow {
                visible: DisplayService.nightLightEnabled
                title: I18n.tr("display_night_light_temp")
                subtitle: DisplayService.nightLightTemp + "K"
                icon: "display-brightness-symbolic"
                showDivider: false

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [{
                            "temp": 3500,
                            "label": I18n.tr("display_temp_warmest")
                        }, {
                            "temp": 4500,
                            "label": I18n.tr("display_temp_warm")
                        }, {
                            "temp": 5500,
                            "label": I18n.tr("display_temp_natural")
                        }]

                        delegate: Rectangle {
                            id: tempPill

                            required property var modelData
                            readonly property bool isSelected: DisplayService.nightLightTemp === modelData.temp

                            implicitHeight: 28
                            implicitWidth: tempText.implicitWidth + Theme.space16
                            radius: 14
                            color: tempPill.isSelected ? Theme.inverseSurface : (tempMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.width: 1
                            border.color: tempPill.isSelected ? Theme.inverseSurface : (tempMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)

                            Text {
                                id: tempText

                                anchors.centerIn: parent
                                text: tempPill.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: tempPill.isSelected ? Font.DemiBold : Font.Normal
                                color: tempPill.isSelected ? Theme.inverseText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: tempMa

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    DisplayService.setNightLight(true, tempPill.modelData.temp);
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.motionFast
                                }

                            }

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: Theme.motionFast
                                }

                            }

                        }

                    }

                }

            }

        }

        // ── 5. Scale & Orientation ───────────────────────────────────
        SettingsSection {
            title: I18n.tr("display_section_layout")

            // Display Scale
            SettingsRow {
                title: I18n.tr("display_scale")
                subtitle: I18n.tr("display_scale_desc")
                icon: "zoom-fit-best-symbolic"
                showDivider: true

                SettingsChoice {
                    options: [{
                        "value": 1,
                        "label": "100%"
                    }, {
                        "value": 1.25,
                        "label": "125%"
                    }, {
                        "value": 1.5,
                        "label": "150%"
                    }, {
                        "value": 1.75,
                        "label": "175%"
                    }, {
                        "value": 2,
                        "label": "200%"
                    }]
                    current: DisplayService.currentScale
                    onChosen: (val) => {
                        DisplayService.setScale(val);
                    }
                }

            }

            // Display Orientation
            SettingsRow {
                title: I18n.tr("display_orientation")
                subtitle: I18n.tr("display_orientation_desc")
                icon: "transform-rotate-symbolic"
                showDivider: false

                SettingsChoice {
                    options: [{
                        "value": 0,
                        "label": I18n.tr("display_orientation_standard")
                    }, {
                        "value": 1,
                        "label": I18n.tr("display_orientation_portrait")
                    }, {
                        "value": 2,
                        "label": I18n.tr("display_orientation_flipped")
                    }, {
                        "value": 3,
                        "label": I18n.tr("display_orientation_portrait_flipped")
                    }]
                    current: DisplayService.currentTransform
                    onChosen: (val) => {
                        DisplayService.setTransform(val);
                    }
                }

            }

        }

        // ── 5. Advanced Display Features ─────────────────────────────
        SettingsSection {
            title: I18n.tr("display_section_advanced")

            // Adaptive Sync (VRR)
            SettingsRow {
                title: I18n.tr("display_vrr")
                subtitle: I18n.tr("display_vrr_desc")
                icon: "speedometer-symbolic"
                showDivider: false

                SettingsToggle {
                    checked: DisplayService.vrrEnabled
                    onToggled: (chk) => {
                        DisplayService.setVrr(chk);
                    }
                }

            }

        }

    }

}
