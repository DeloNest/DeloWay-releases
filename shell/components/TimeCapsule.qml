import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"

// TimeCapsule — Top-left status capsule for DeloWay Smart TopBar.
// Compact mode: Crisp bold time + localized short date powered by SystemClock.
// Expanded mode (Phase 2): Big time + full date + Hijri date, monthly calendar, and hardware telemetry.
PanelWindow {
    id: root

    required property ShellScreen targetScreen
    screen: targetScreen

    anchors {
        top: true
        right: true
    }

    readonly property real earRadius: 18
    readonly property real bottomRadius: 26
    readonly property real capsuleGap: 10

    // Fixed PanelWindow bounds to eliminate dynamic Wayland surface reallocations
    readonly property real fixedWindowWidth: 420
    readonly property real fixedWindowHeight: 530

    implicitWidth: fixedWindowWidth
    implicitHeight: fixedWindowHeight

    margins {
        top: 0
        right: Math.round(targetScreen.width / 2 + ShellState.smartNotchCurrentWidth / 2 + capsuleGap - earRadius)
    }

    color: "transparent"
    visible: ConfigManager.timeCapsuleEnabled

    WlrLayershell.namespace: "deloway:time-capsule"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: root.isExpanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    mask: Region {
        item: notchFrame
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.isExpanded
        onActivated: ShellState.closeTimeCapsule()
    }

    // ── Dimensions & State ────────────────────────────────────────────────
    readonly property bool isExpanded: ShellState.timeCapsuleExpanded
    readonly property real compactHeight: 44
    readonly property real compactWidth: Math.max(132, compactContentRow.implicitWidth + 36)
    readonly property real expandedWidth: 350
    readonly property real expandedHeight: root.hasVisibleHardware ? 284 : 172
    readonly property bool hasVisibleHardware: ConfigManager.timeCapsuleShowHardware && (ConfigManager.timeCapsuleShowCpu || ConfigManager.timeCapsuleShowRam || ConfigManager.timeCapsuleShowGpu)

    // Single unified motion driver (200ms open, 160ms close)
    property real expandProgress: root.isExpanded ? 1.0 : 0.0
    Behavior on expandProgress {
        NumberAnimation {
            duration: root.isExpanded ? 200 : 160
            easing.type: root.isExpanded ? Easing.OutCubic : Easing.OutQuad
        }
    }

    readonly property real currentWidth: Math.round(root.compactWidth + (root.expandedWidth - root.compactWidth) * root.expandProgress)
    readonly property real currentHeight: Math.round(root.compactHeight + (root.expandedHeight - root.compactHeight) * root.expandProgress)
    readonly property real currentY: Math.round(Theme.topBarMarginTop * (1.0 - root.expandProgress))


    // ── SystemClock: minute precision in compact, seconds in expanded ─────
    SystemClock {
        id: sysClock
        precision: (root.isExpanded && ConfigManager.timeCapsuleShowSeconds) ? SystemClock.Seconds : SystemClock.Minutes
    }

    // ── Localization & Date Helpers ───────────────────────────────────────
    readonly property var arDays: ["الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت"]
    readonly property var arMonths: [
        "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
        "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"
    ]
    readonly property var enDays: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    readonly property var enMonths: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    readonly property var hijriMonthsAr: [
        "محرم", "صفر", "ربيع الأول", "ربيع الآخر", "جمادى الأولى", "جمادى الآخرة",
        "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة"
    ]
    readonly property var hijriMonthsEn: [
        "Muharram", "Safar", "Rabi' I", "Rabi' II", "Jumada I", "Jumada II",
        "Rajab", "Sha'ban", "Ramadan", "Shawwal", "Dhu al-Qi'dah", "Dhu al-Hijjah"
    ]

    // Umm al-Qura astronomical month length bitmasks (1440-1455 AH)
    readonly property var ummAlQuraTable: ({
        1440: 698, 1441: 1461, 1442: 1450, 1443: 3413, 1444: 2714,
        1445: 2350, 1446: 622, 1447: 1373, 1448: 2778, 1449: 1748,
        1450: 1701, 1451: 2855, 1452: 2637, 1453: 1197, 1454: 1389, 1455: 2906
    })

    function toArabicDigits(num) {
        if (num === undefined || num === null) return "";
        return num.toString().replace(/\d/g, function(d) {
            return "٠١٢٣٤٥٦٧٨٩"[d];
        });
    }

    function calculateHijriDate(d) {
        if (!d) return { day: 1, month: 1, year: 1448 };
        const epoch = new Date(2018, 8, 11); // 11 Sep 2018 = 1 Muharram 1440
        let diffDays = Math.round((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - epoch) / 86400000);
        let y = 1440, m = 1;
        while (diffDays >= 0 && y <= 1455) {
            let mask = root.ummAlQuraTable[y] || 0;
            let daysInMonth = (mask & (1 << (m - 1))) ? 30 : 29;
            if (diffDays < daysInMonth) {
                return { day: diffDays + 1, month: m, year: y };
            }
            diffDays -= daysInMonth;
            m++;
            if (m > 12) {
                m = 1;
                y++;
            }
        }
        return { day: 1, month: 1, year: 1448 };
    }

    readonly property string formattedHijriDate: {
        const d = sysClock.date;
        if (!d) return "";
        const h = calculateHijriDate(d);
        if (I18n.isRTL) {
            return toArabicDigits(h.day) + " " + (hijriMonthsAr[h.month - 1] || "") + " " + toArabicDigits(h.year) + " هـ";
        }
        return (hijriMonthsEn[h.month - 1] || "") + " " + h.day + ", " + h.year + " AH";
    }

    readonly property string formattedTime: {
        const d = sysClock.date;
        if (!d) return "--:--";
        if (ConfigManager.clockFormat === "24h") {
            return Qt.formatDateTime(d, "hh:mm");
        }
        const timeStr = Qt.formatDateTime(d, "h:mm");
        if (I18n.isRTL) {
            const ap = d.getHours() < 12 ? "ص" : "م";
            return timeStr + " " + ap;
        }
        return Qt.formatDateTime(d, "h:mm ap");
    }

    readonly property string formattedExpandedTime: {
        const d = sysClock.date;
        if (!d) return "--:--:--";
        const withSec = ConfigManager.timeCapsuleShowSeconds;
        if (ConfigManager.clockFormat === "24h") {
            return Qt.formatDateTime(d, withSec ? "hh:mm:ss" : "hh:mm");
        }
        const timeStr = Qt.formatDateTime(d, withSec ? "h:mm:ss" : "h:mm");
        if (I18n.isRTL) {
            const ap = d.getHours() < 12 ? "ص" : "م";
            return timeStr + " " + ap;
        }
        return Qt.formatDateTime(d, withSec ? "h:mm:ss ap" : "h:mm ap");
    }

    readonly property string formattedAmPm: {
        const d = sysClock.date;
        if (!d || ConfigManager.clockFormat === "24h") return "";
        if (I18n.isRTL) {
            return d.getHours() < 12 ? "ص" : "م";
        }
        return Qt.formatDateTime(d, "ap");
    }

    readonly property string formattedShortDate: {
        const d = sysClock.date;
        if (!d) return "";
        const dayIdx = d.getDay();
        const monthIdx = d.getMonth();
        const dateNum = d.getDate();
        const useAr = I18n.isRTL && ConfigManager.timeCapsuleArabicDigits;
        const dNum = useAr ? root.toArabicDigits(dateNum) : dateNum;

        if (I18n.isRTL) {
            return (arDays[dayIdx] || "") + "، " + dNum + " " + (arMonths[monthIdx] || "");
        }
        return (enDays[dayIdx] || "").slice(0, 3) + ", " + (enMonths[monthIdx] || "").slice(0, 3) + " " + dateNum;
    }

    readonly property string formattedFullDate: {
        const d = sysClock.date;
        if (!d) return "";
        const dayIdx = d.getDay();
        const monthIdx = d.getMonth();
        const dateNum = d.getDate();
        const yearNum = d.getFullYear();
        const useAr = I18n.isRTL && ConfigManager.timeCapsuleArabicDigits;
        const dNum = useAr ? root.toArabicDigits(dateNum) : dateNum;
        const yNum = useAr ? root.toArabicDigits(yearNum) : yearNum;

        if (I18n.isRTL) {
            return (arDays[dayIdx] || "") + "، " + dNum + " " + (arMonths[monthIdx] || "") + " " + yNum;
        }
        return (enDays[dayIdx] || "") + ", " + (enMonths[monthIdx] || "") + " " + dateNum + ", " + yearNum;
    }

    onIsExpandedChanged: {
        if (root.isExpanded) {
            ShellState.closeSmartNotch();
            ShellState.closeQuickSettingsCapsule();
        }
    }

    // ── Calendar Strip Helper Functions (100% NotchHome / Smart Notch matching) ──
    function getMonthName() {
        const d = sysClock.date || new Date();
        return I18n.isRTL ? arMonths[d.getMonth()] : enMonths[d.getMonth()];
    }

    function getDaysStrip() {
        const days = [];
        const dayNamesEn = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
        const dayNamesAr = ["أحد", "إثنين", "ثلاثاء", "أربعاء", "خميس", "جمعة", "سبت"];
        const dayAbbrAr = ["أح", "إث", "ثل", "أر", "خم", "جم", "سب"];
        const now = sysClock.date || new Date();
        for (let offset = -3; offset <= 3; offset++) {
            const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() + offset);
            const dayIdx = d.getDay();
            days.push({
                dayOffset: offset,
                dayNumber: d.getDate(),
                dayName: I18n.isRTL ? dayNamesAr[dayIdx] : dayNamesEn[dayIdx],
                dayAbbr: I18n.isRTL ? dayAbbrAr[dayIdx] : dayNamesEn[dayIdx].substring(0, 1),
                isToday: offset === 0
            });
        }
        return days;
    }

    // ── Load Color Helper ─────────────────────────────────────────────────
    function getLoadColor(usageFraction, tempC) {
        if (usageFraction >= 0.90 || (tempC !== null && tempC !== undefined && tempC >= 85)) {
            return Theme.colors.danger;
        }
        if (usageFraction >= 0.70 || (tempC !== null && tempC !== undefined && tempC >= 75)) {
            return Theme.colors.warning;
        }
        return Theme.notchText;
    }

    // ── Outer Shape & Notch Framing ───────────────────────────────────────
    NotchFrame {
        id: notchFrame
        anchors.right: parent.right
        anchors.rightMargin: Math.round(root.earRadius * (1.0 - root.expandProgress))
        y: root.currentY
        isExpanded: root.isExpanded
        currentWidth: root.currentWidth
        currentHeight: root.currentHeight
        earRadius: root.earRadius
        bottomRadius: root.bottomRadius

        // ═══════════════════════════════════════════════════════════════════
        // COMPACT VIEW: Time & Date side-by-side (Zero hover effects)
        // ═══════════════════════════════════════════════════════════════════
        Rectangle {
            anchors.fill: parent
            radius: root.bottomRadius
            color: "transparent"
            visible: !root.isExpanded

            RowLayout {
                id: compactContentRow
                anchors.centerIn: parent
                spacing: Theme.space8
                LayoutMirroring.enabled: I18n.isRTL
                LayoutMirroring.childrenInherit: true

                // Bold Time
                Text {
                    text: root.formattedTime
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(13)
                    font.weight: Font.Bold
                    color: Theme.notchText
                    renderType: Theme.renderType
                    Layout.alignment: Qt.AlignVCenter
                }

                // Subtle vertical divider
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 14
                    Layout.alignment: Qt.AlignVCenter
                    color: Theme.notchBorder
                    opacity: 0.55
                    visible: ConfigManager.timeCapsuleShowShortDate
                }

                // Short Date
                Text {
                    text: root.formattedShortDate
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(11)
                    font.weight: Font.Normal
                    color: Theme.notchTextSecondary
                    renderType: Theme.renderType
                    Layout.alignment: Qt.AlignVCenter
                    visible: ConfigManager.timeCapsuleShowShortDate
                }
            }

            MouseArea {
                id: compactMa
                anchors.fill: parent
                hoverEnabled: false
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton
                onClicked: ShellState.toggleTimeCapsule()
                onWheel: (wheel) => {
                    wheel.accepted = true;
                    ShellState.toggleTimeCapsule();
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════════
        // EXPANDED VIEW: Header + Monthly Calendar + Hardware Cards
        // ═══════════════════════════════════════════════════════════════════
        ColumnLayout {
            id: expandedCol
            anchors.fill: parent
            anchors.topMargin: Theme.space16
            anchors.bottomMargin: Theme.space16
            anchors.leftMargin: Theme.space16
            anchors.rightMargin: Theme.space16
            spacing: Theme.space8
            visible: root.isExpanded
            opacity: root.isExpanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }
            LayoutMirroring.enabled: I18n.isRTL
            LayoutMirroring.childrenInherit: true

            // ─────────────────────────────────────────────────────────────
            // 1. HEADER: Big Time with seconds + Full Date + Hijri Date
            // ─────────────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space8
                LayoutMirroring.enabled: I18n.isRTL
                LayoutMirroring.childrenInherit: true

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    // Big Time Row
                    RowLayout {
                        spacing: Theme.space4
                        LayoutMirroring.enabled: false // Always LTR for digital time digits

                        Text {
                            text: root.formattedExpandedTime
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(26)
                            font.weight: Font.Bold
                            color: Theme.notchText
                            renderType: Theme.renderType
                        }

                        Text {
                            text: root.formattedAmPm
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(13)
                            font.weight: Font.DemiBold
                            color: Theme.notchTextSecondary
                            renderType: Theme.renderType
                            visible: ConfigManager.clockFormat !== "24h"
                            Layout.alignment: Qt.AlignBaseline
                        }
                    }

                    // Full Gregorian Date
                    Text {
                        text: root.formattedFullDate
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(12)
                        font.weight: Font.Normal
                        color: Theme.notchTextSecondary
                        renderType: Theme.renderType
                    }
                }

                // Hijri Date Pill
                Rectangle {
                    visible: ConfigManager.timeCapsuleShowHijri
                    Layout.alignment: Qt.AlignVCenter
                    radius: Theme.radiusSmall
                    color: Theme.notchSurface
                    border.color: Theme.notchBorderSubtle
                    border.width: 1
                    implicitWidth: hijriText.implicitWidth + Theme.space16
                    implicitHeight: hijriText.implicitHeight + Theme.space8

                    Text {
                        id: hijriText
                        anchors.centerIn: parent
                        text: root.formattedHijriDate
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(11)
                        font.weight: Font.Medium
                        color: Theme.notchTextSecondary
                        renderType: Theme.renderType
                    }
                }

                // Collapse Button
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 26
                    implicitHeight: 26
                    radius: 13
                    color: timeCollapseMa.containsMouse ? Theme.notchSurfaceHover : "transparent"
                    border.color: Theme.notchBorderSubtle
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "⌃"
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(14)
                        font.weight: Font.Bold
                        color: timeCollapseMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                    }

                    MouseArea {
                        id: timeCollapseMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ShellState.closeTimeCapsule()
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.notchBorder
                opacity: 0.35
            }

            // ─────────────────────────────────────────────────────────────
            // 2. CALENDAR STRIP (Matches Smart Notch / NotchHome reference)
            // ─────────────────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                LayoutMirroring.enabled: I18n.isRTL
                LayoutMirroring.childrenInherit: true

                // Top: Month name + Horizontal Days Strip
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Large Month Label (e.g. Jul / سبتمبر)
                    Text {
                        text: root.getMonthName()
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(22)
                        font.weight: Font.Bold
                        renderType: Theme.renderType
                        color: Theme.notchText
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // 7-Day Horizontal Strip
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: root.getDaysStrip()

                            delegate: ColumnLayout {
                                id: dayCol
                                required property var modelData
                                spacing: 2
                                Layout.alignment: Qt.AlignHCenter
                                Layout.fillWidth: true

                                // Day of week abbreviation
                                Text {
                                    text: dayCol.modelData.isToday ? dayCol.modelData.dayName.toUpperCase() : dayCol.modelData.dayAbbr.toUpperCase()
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(dayCol.modelData.isToday ? 9 : 8)
                                    font.weight: dayCol.modelData.isToday ? Font.Bold : Font.Normal
                                    color: dayCol.modelData.isToday ? Theme.notchText : Theme.notchTextTertiary
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                // Day Number
                                Text {
                                    text: (I18n.isRTL && ConfigManager.timeCapsuleArabicDigits) ? root.toArabicDigits(dayCol.modelData.dayNumber) : dayCol.modelData.dayNumber.toString()
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(dayCol.modelData.isToday ? 20 : 14)
                                    font.weight: dayCol.modelData.isToday ? Font.Bold : Font.Normal
                                    color: dayCol.modelData.isToday
                                           ? Theme.notchText
                                           : (dayCol.modelData.dayOffset === -2 ? Theme.calendarPast : (dayCol.modelData.dayOffset === 2 ? Theme.calendarFuture : Theme.notchTextTertiary))
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                    }
                }

                // Bottom: Calendar Icon + "Nothing for today" status
                RowLayout {
                    spacing: 6
                    Layout.alignment: Qt.AlignHCenter

                    SymbolicIcon {
                        iconSize: 13
                        source: "x-office-calendar-symbolic"
                        iconColor: Theme.notchTextTertiary
                    }

                    Text {
                        text: I18n.tr("notch_today_events")
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(11)
                        renderType: Theme.renderType
                        color: Theme.notchTextTertiary
                    }
                }
            }

            // Divider (between Calendar & Hardware)
            Rectangle {
                visible: root.hasVisibleHardware
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.notchBorder
                opacity: 0.35
            }

            // ─────────────────────────────────────────────────────────────
            // 3. HARDWARE TELEMETRY CARDS (CPU, RAM, GPU)
            // ─────────────────────────────────────────────────────────────
            RowLayout {
                visible: root.hasVisibleHardware
                Layout.fillWidth: true
                spacing: Theme.space8
                LayoutMirroring.enabled: I18n.isRTL
                LayoutMirroring.childrenInherit: true

                // ── CPU Card ──
                Rectangle {
                    visible: ConfigManager.timeCapsuleShowCpu
                    Layout.fillWidth: true
                    Layout.preferredHeight: 96
                    radius: Theme.radiusMedium
                    color: Theme.notchSurfaceElevated
                    border.color: Theme.notchBorderSubtle
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.space8
                        spacing: 3
                        LayoutMirroring.enabled: I18n.isRTL
                        LayoutMirroring.childrenInherit: true

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "CPU"
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: Font.DemiBold
                                color: Theme.notchTextSecondary
                                renderType: Theme.renderType
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: HardwareService.cpuPercentText
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: Font.Bold
                                color: root.getLoadColor(HardwareService.cpuUsage, HardwareService.cpuTemp)
                                renderType: Theme.renderType
                            }
                        }

                        // Temp
                        Text {
                            text: HardwareService.cpuTempText
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(10)
                            font.weight: Font.Normal
                            color: Theme.notchTextTertiary
                            renderType: Theme.renderType
                            visible: ConfigManager.timeCapsuleShowTemps
                        }

                        // Sparkline Canvas (~60s history)
                        Canvas {
                            id: cpuCanvas
                            Layout.fillWidth: true
                            Layout.preferredHeight: 20
                            property var history: HardwareService.cpuHistory
                            property color strokeColor: root.getLoadColor(HardwareService.cpuUsage, HardwareService.cpuTemp)
                            property color fillColor: Qt.rgba(strokeColor.r, strokeColor.g, strokeColor.b, 0.15)

                            onHistoryChanged: if (root.isExpanded) requestPaint()
                            onStrokeColorChanged: if (root.isExpanded) requestPaint()

                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                if (!history || history.length < 2) return;
                                const w = width;
                                const h = height;
                                const n = history.length;
                                const step = w / Math.max(1, n - 1);

                                ctx.beginPath();
                                for (let i = 0; i < n; i++) {
                                    const x = i * step;
                                    const y = h - 2 - (history[i] * (h - 4));
                                    if (i === 0) ctx.moveTo(x, y);
                                    else ctx.lineTo(x, y);
                                }
                                ctx.strokeStyle = strokeColor;
                                ctx.lineWidth = 1.5;
                                ctx.lineJoin = "round";
                                ctx.stroke();

                                ctx.lineTo(w, h);
                                ctx.lineTo(0, h);
                                ctx.closePath();
                                ctx.fillStyle = fillColor;
                                ctx.fill();
                            }
                        }

                        // Load bar
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 2
                            radius: 1
                            color: Theme.notchBorderSubtle

                            Rectangle {
                                width: Math.max(2, Math.round(parent.width * HardwareService.cpuUsage))
                                height: parent.height
                                radius: 1
                                color: root.getLoadColor(HardwareService.cpuUsage, HardwareService.cpuTemp)
                            }
                        }
                    }
                }

                // ── RAM Card ──
                Rectangle {
                    visible: ConfigManager.timeCapsuleShowRam
                    Layout.fillWidth: true
                    Layout.preferredHeight: 96
                    radius: Theme.radiusMedium
                    color: Theme.notchSurfaceElevated
                    border.color: Theme.notchBorderSubtle
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.space8
                        spacing: 3
                        LayoutMirroring.enabled: I18n.isRTL
                        LayoutMirroring.childrenInherit: true

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "RAM"
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: Font.DemiBold
                                color: Theme.notchTextSecondary
                                renderType: Theme.renderType
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: HardwareService.ramPercentText
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: Font.Bold
                                color: root.getLoadColor(HardwareService.ramUsage, null)
                                renderType: Theme.renderType
                            }
                        }

                        // Memory used / total
                        Text {
                            text: HardwareService.ramText
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(10)
                            font.weight: Font.Normal
                            color: Theme.notchTextTertiary
                            renderType: Theme.renderType
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        // Sparkline Canvas (~60s history)
                        Canvas {
                            id: ramCanvas
                            Layout.fillWidth: true
                            Layout.preferredHeight: 20
                            property var history: HardwareService.ramHistory
                            property color strokeColor: root.getLoadColor(HardwareService.ramUsage, null)
                            property color fillColor: Qt.rgba(strokeColor.r, strokeColor.g, strokeColor.b, 0.15)

                            onHistoryChanged: if (root.isExpanded) requestPaint()
                            onStrokeColorChanged: if (root.isExpanded) requestPaint()

                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                if (!history || history.length < 2) return;
                                const w = width;
                                const h = height;
                                const n = history.length;
                                const step = w / Math.max(1, n - 1);

                                ctx.beginPath();
                                for (let i = 0; i < n; i++) {
                                    const x = i * step;
                                    const y = h - 2 - (history[i] * (h - 4));
                                    if (i === 0) ctx.moveTo(x, y);
                                    else ctx.lineTo(x, y);
                                }
                                ctx.strokeStyle = strokeColor;
                                ctx.lineWidth = 1.5;
                                ctx.lineJoin = "round";
                                ctx.stroke();

                                ctx.lineTo(w, h);
                                ctx.lineTo(0, h);
                                ctx.closePath();
                                ctx.fillStyle = fillColor;
                                ctx.fill();
                            }
                        }

                        // Load bar
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 2
                            radius: 1
                            color: Theme.notchBorderSubtle

                            Rectangle {
                                width: Math.max(2, Math.round(parent.width * HardwareService.ramUsage))
                                height: parent.height
                                radius: 1
                                color: root.getLoadColor(HardwareService.ramUsage, null)
                            }
                        }
                    }
                }

                // ── GPU Card ──
                Rectangle {
                    visible: ConfigManager.timeCapsuleShowGpu
                    Layout.fillWidth: true
                    Layout.preferredHeight: 96
                    radius: Theme.radiusMedium
                    color: Theme.notchSurfaceElevated
                    border.color: Theme.notchBorderSubtle
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.space8
                        spacing: 3
                        LayoutMirroring.enabled: I18n.isRTL
                        LayoutMirroring.childrenInherit: true

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "GPU"
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: Font.DemiBold
                                color: Theme.notchTextSecondary
                                renderType: Theme.renderType
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: HardwareService.gpuPercentText
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: Font.Bold
                                color: HardwareService.hasGpu ? root.getLoadColor(HardwareService.gpuUsage || 0, HardwareService.gpuTemp) : Theme.notchTextTertiary
                                renderType: Theme.renderType
                            }
                        }

                        // GPU subtext (temp or VRAM)
                        Text {
                            text: {
                                if (!HardwareService.hasGpu) return "—";
                                if (ConfigManager.timeCapsuleShowTemps) {
                                    return HardwareService.gpuTempText + " • " + HardwareService.gpuVramText;
                                }
                                return HardwareService.gpuVramText;
                            }
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(10)
                            font.weight: Font.Normal
                            color: Theme.notchTextTertiary
                            renderType: Theme.renderType
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        // Sparkline Canvas (~60s history)
                        Canvas {
                            id: gpuCanvas
                            Layout.fillWidth: true
                            Layout.preferredHeight: 20
                            property var history: HardwareService.gpuHistory
                            property color strokeColor: HardwareService.hasGpu ? root.getLoadColor(HardwareService.gpuUsage || 0, HardwareService.gpuTemp) : Theme.notchTextTertiary
                            property color fillColor: Qt.rgba(strokeColor.r, strokeColor.g, strokeColor.b, 0.15)

                            onHistoryChanged: if (root.isExpanded) requestPaint()
                            onStrokeColorChanged: if (root.isExpanded) requestPaint()

                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                if (!history || history.length < 2) return;
                                const w = width;
                                const h = height;
                                const n = history.length;
                                const step = w / Math.max(1, n - 1);

                                ctx.beginPath();
                                for (let i = 0; i < n; i++) {
                                    const x = i * step;
                                    const y = h - 2 - (history[i] * (h - 4));
                                    if (i === 0) ctx.moveTo(x, y);
                                    else ctx.lineTo(x, y);
                                }
                                ctx.strokeStyle = strokeColor;
                                ctx.lineWidth = 1.5;
                                ctx.lineJoin = "round";
                                ctx.stroke();

                                ctx.lineTo(w, h);
                                ctx.lineTo(0, h);
                                ctx.closePath();
                                ctx.fillStyle = fillColor;
                                ctx.fill();
                            }
                        }

                        // Load bar
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 2
                            radius: 1
                            color: Theme.notchBorderSubtle

                            Rectangle {
                                width: Math.max(2, Math.round(parent.width * (HardwareService.gpuUsage || 0.0)))
                                height: parent.height
                                radius: 1
                                color: HardwareService.hasGpu ? root.getLoadColor(HardwareService.gpuUsage || 0, HardwareService.gpuTemp) : Theme.notchBorderSubtle
                            }
                        }
                    }
                }
            }
        }
    }
}
