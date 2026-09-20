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
        left: true
    }

    readonly property real earRadius: 18
    readonly property real bottomRadius: 26
    readonly property real capsuleGap: 10

    margins {
        top: root.isExpanded ? 0 : 10
        left: root.isExpanded ? 0 : 10
    }

    color: "transparent"
    visible: ConfigManager.timeCapsuleEnabled

    WlrLayershell.namespace: "deloway:time-capsule"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: root.isExpanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    // ── Outside Click & Escape Dismissal ──────────────────────────────────
    HyprlandFocusGrab {
        windows: [ root ]
        active: root.isExpanded
        onCleared: ShellState.closeTimeCapsule()
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
    readonly property real expandedWidth: 440
    readonly property real expandedHeight: ConfigManager.timeCapsuleShowHardware ? 486 : 374

    property real currentWidth: root.isExpanded ? root.expandedWidth : root.compactWidth
    property real currentHeight: root.isExpanded ? root.expandedHeight : root.compactHeight

    Behavior on currentWidth  { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
    Behavior on currentHeight { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }

    implicitWidth:  Math.round(root.currentWidth + (root.isExpanded ? root.earRadius * 2 : 0))
    implicitHeight: Math.round(root.currentHeight + 8)

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
        return Qt.formatDateTime(d, "h:mm ap");
    }

    readonly property string formattedExpandedTime: {
        const d = sysClock.date;
        if (!d) return "--:--:--";
        const withSec = ConfigManager.timeCapsuleShowSeconds;
        if (ConfigManager.clockFormat === "24h") {
            return Qt.formatDateTime(d, withSec ? "hh:mm:ss" : "hh:mm");
        }
        return Qt.formatDateTime(d, withSec ? "h:mm:ss" : "h:mm");
    }

    readonly property string formattedAmPm: {
        const d = sysClock.date;
        if (!d || ConfigManager.clockFormat === "24h") return "";
        return Qt.formatDateTime(d, "ap");
    }

    readonly property string formattedShortDate: {
        const d = sysClock.date;
        if (!d) return "";
        const dayIdx = d.getDay();
        const monthIdx = d.getMonth();
        const dateNum = d.getDate();

        if (I18n.isRTL) {
            return (arDays[dayIdx] || "") + "، " + dateNum + " " + (arMonths[monthIdx] || "");
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

        if (I18n.isRTL) {
            return (arDays[dayIdx] || "") + "، " + dateNum + " " + (arMonths[monthIdx] || "") + " " + yearNum;
        }
        return (enDays[dayIdx] || "") + ", " + (enMonths[monthIdx] || "") + " " + dateNum + ", " + yearNum;
    }

    // ── Calendar Navigation State ─────────────────────────────────────────
    property int viewYear: sysClock.date ? sysClock.date.getFullYear() : 2026
    property int viewMonth: sysClock.date ? sysClock.date.getMonth() : 8

    onIsExpandedChanged: {
        if (root.isExpanded) {
            root.resetToCurrentMonth();
        }
    }

    readonly property bool isViewingDifferentMonth: {
        const d = sysClock.date;
        if (!d) return false;
        return (root.viewYear !== d.getFullYear() || root.viewMonth !== d.getMonth());
    }

    function resetToCurrentMonth() {
        const d = sysClock.date || new Date();
        root.viewYear = d.getFullYear();
        root.viewMonth = d.getMonth();
    }

    function prevMonth() {
        if (root.viewMonth === 0) {
            root.viewMonth = 11;
            root.viewYear--;
        } else {
            root.viewMonth--;
        }
    }

    function nextMonth() {
        if (root.viewMonth === 11) {
            root.viewMonth = 0;
            root.viewYear++;
        } else {
            root.viewMonth++;
        }
    }

    readonly property string calendarMonthYearTitle: {
        if (I18n.isRTL) {
            return (arMonths[root.viewMonth] || "") + " " + root.viewYear;
        }
        return (enMonths[root.viewMonth] || "") + " " + root.viewYear;
    }

    readonly property var weekdayHeaders: {
        const ws = ConfigManager.timeCapsuleWeekStart;
        if (I18n.isRTL) {
            if (ws === "sunday") {
                return ["أحد", "اثنين", "ثلاثاء", "أربعاء", "خميس", "جمعة", "سبت"];
            } else if (ws === "monday") {
                return ["اثنين", "ثلاثاء", "أربعاء", "خميس", "جمعة", "سبت", "أحد"];
            }
            return ["سبت", "أحد", "اثنين", "ثلاثاء", "أربعاء", "خميس", "جمعة"];
        } else {
            if (ws === "sunday") {
                return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
            } else if (ws === "monday") {
                return ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
            }
            return ["Sat", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri"];
        }
    }

    readonly property var calendarCells: {
        const now = sysClock.date || new Date();
        const nowY = now.getFullYear();
        const nowM = now.getMonth();
        const nowD = now.getDate();

        const curDays = new Date(root.viewYear, root.viewMonth + 1, 0).getDate();
        const prevDays = new Date(root.viewYear, root.viewMonth, 0).getDate();
        const firstDay = new Date(root.viewYear, root.viewMonth, 1).getDay(); // 0=Sun..6=Sat

        const ws = ConfigManager.timeCapsuleWeekStart;
        let offset = 0;
        if (ws === "saturday") offset = (firstDay + 1) % 7;
        else if (ws === "monday") offset = (firstDay + 6) % 7;
        else offset = firstDay; // sunday

        const cells = [];
        for (let i = 0; i < 42; i++) {
            if (i < offset) {
                cells.push({
                    day: prevDays - offset + i + 1,
                    current: false,
                    today: false
                });
            } else if (i < offset + curDays) {
                const d = i - offset + 1;
                const isToday = (root.viewYear === nowY && root.viewMonth === nowM && d === nowD);
                cells.push({
                    day: d,
                    current: true,
                    today: isToday
                });
            } else {
                cells.push({
                    day: i - (offset + curDays) + 1,
                    current: false,
                    today: false
                });
            }
        }
        return cells;
    }

    // ── Load Color Helper ─────────────────────────────────────────────────
    function getLoadColor(usageFraction, tempC) {
        if (usageFraction >= 0.90 || (tempC !== null && tempC !== undefined && tempC >= 85)) {
            return Theme.colors.danger;
        }
        if (usageFraction >= 0.70 || (tempC !== null && tempC !== undefined && tempC >= 75)) {
            return Theme.colors.warning;
        }
        return Theme.colors.accent;
    }

    // ── Outer Shape & Notch Framing ───────────────────────────────────────
    NotchFrame {
        id: notchFrame
        anchors.fill: parent
        isExpanded: root.isExpanded
        currentWidth: root.currentWidth
        currentHeight: root.currentHeight
        earRadius: root.earRadius
        bottomRadius: root.bottomRadius

        // ═══════════════════════════════════════════════════════════════════
        // COMPACT VIEW: Time & Date side-by-side
        // ═══════════════════════════════════════════════════════════════════
        Rectangle {
            anchors.fill: parent
            radius: root.bottomRadius
            color: compactMa.containsMouse ? Theme.notchSurfaceHover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
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
                }
            }

            MouseArea {
                id: compactMa
                anchors.fill: parent
                hoverEnabled: true
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
                        color: Theme.colors.accent
                        renderType: Theme.renderType
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
            // 2. MONTHLY CALENDAR
            // ─────────────────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.space8
                LayoutMirroring.enabled: I18n.isRTL
                LayoutMirroring.childrenInherit: true

                // Month Nav Bar: [<] [ الشهر والسنة ] [>]
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space8
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    // Prev Month
                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: Theme.radiusSmall
                        color: prevMonthMa.containsMouse ? Theme.notchSurfaceHover : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: I18n.isRTL ? "›" : "‹"
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(16)
                            font.weight: Font.Bold
                            color: Theme.notchText
                            renderType: Theme.renderType
                        }

                        MouseArea {
                            id: prevMonthMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.prevMonth()
                        }
                    }

                    // Month & Year title (clickable to reset to today's month)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        radius: Theme.radiusSmall
                        color: monthTitleMa.containsMouse ? Theme.notchSurfaceHover : "transparent"

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Theme.space4

                            Text {
                                text: root.calendarMonthYearTitle
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(13)
                                font.weight: Font.DemiBold
                                color: Theme.notchText
                                renderType: Theme.renderType
                            }

                            Rectangle {
                                visible: root.isViewingDifferentMonth
                                Layout.preferredWidth: 6
                                Layout.preferredHeight: 6
                                radius: 3
                                color: Theme.colors.accent
                            }
                        }

                        MouseArea {
                            id: monthTitleMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.resetToCurrentMonth()
                        }
                    }

                    // Next Month
                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: Theme.radiusSmall
                        color: nextMonthMa.containsMouse ? Theme.notchSurfaceHover : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: I18n.isRTL ? "‹" : "›"
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(16)
                            font.weight: Font.Bold
                            color: Theme.notchText
                            renderType: Theme.renderType
                        }

                        MouseArea {
                            id: nextMonthMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.nextMonth()
                        }
                    }
                }

                // Weekday Headers
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: root.weekdayHeaders
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 20

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: Font.DemiBold
                                color: Theme.notchTextTertiary
                                renderType: Theme.renderType
                            }
                        }
                    }
                }

                // 6x7 Day Cells Grid
                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    columnSpacing: 2
                    rowSpacing: 2
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: root.calendarCells

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24
                            radius: Theme.radiusSmall
                            color: modelData.today ? Theme.colors.accent : (cellMa.containsMouse ? Theme.notchSurfaceHover : "transparent")

                            Text {
                                anchors.centerIn: parent
                                text: modelData.day
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: modelData.today ? Font.Bold : (modelData.current ? Font.Normal : Font.Light)
                                color: modelData.today ? "#ffffff" : (modelData.current ? Theme.notchText : Theme.notchTextTertiary)
                                opacity: modelData.today ? 1.0 : (modelData.current ? 1.0 : 0.35)
                                renderType: Theme.renderType
                            }

                            MouseArea {
                                id: cellMa
                                anchors.fill: parent
                                hoverEnabled: true
                            }
                        }
                    }
                }
            }

            // Divider (between Calendar & Hardware)
            Rectangle {
                visible: ConfigManager.timeCapsuleShowHardware
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.notchBorder
                opacity: 0.35
            }

            // ─────────────────────────────────────────────────────────────
            // 3. HARDWARE TELEMETRY CARDS (CPU, RAM, GPU)
            // ─────────────────────────────────────────────────────────────
            RowLayout {
                visible: ConfigManager.timeCapsuleShowHardware
                Layout.fillWidth: true
                spacing: Theme.space8
                LayoutMirroring.enabled: I18n.isRTL
                LayoutMirroring.childrenInherit: true

                // ── CPU Card ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 82
                    radius: Theme.radiusMedium
                    color: Theme.notchSurfaceElevated
                    border.color: Theme.notchBorderSubtle
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.space8
                        spacing: 4
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
                                text: SystemMonitor.cpuPercentText
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: Font.Bold
                                color: root.getLoadColor(SystemMonitor.cpuUsage, 45)
                                renderType: Theme.renderType
                            }
                        }

                        // Temp / subtext
                        Text {
                            text: "45°C" // CPU temp from hwmon discovered in Phase 0 (wired dynamically in Phase 3)
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(10)
                            font.weight: Font.Normal
                            color: Theme.notchTextTertiary
                            renderType: Theme.renderType
                        }

                        Item { Layout.fillHeight: true }

                        // Load bar
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 3
                            radius: 1.5
                            color: Theme.notchBorderSubtle

                            Rectangle {
                                width: Math.max(2, Math.round(parent.width * SystemMonitor.cpuUsage))
                                height: parent.height
                                radius: 1.5
                                color: root.getLoadColor(SystemMonitor.cpuUsage, 45)
                            }
                        }
                    }
                }

                // ── RAM Card ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 82
                    radius: Theme.radiusMedium
                    color: Theme.notchSurfaceElevated
                    border.color: Theme.notchBorderSubtle
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.space8
                        spacing: 4
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
                                text: Math.round(SystemMonitor.ramUsage * 100) + "%"
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: Font.Bold
                                color: root.getLoadColor(SystemMonitor.ramUsage, null)
                                renderType: Theme.renderType
                            }
                        }

                        // Memory used / total
                        Text {
                            text: SystemMonitor.ramText
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(10)
                            font.weight: Font.Normal
                            color: Theme.notchTextTertiary
                            renderType: Theme.renderType
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Item { Layout.fillHeight: true }

                        // Load bar
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 3
                            radius: 1.5
                            color: Theme.notchBorderSubtle

                            Rectangle {
                                width: Math.max(2, Math.round(parent.width * SystemMonitor.ramUsage))
                                height: parent.height
                                radius: 1.5
                                color: root.getLoadColor(SystemMonitor.ramUsage, null)
                            }
                        }
                    }
                }

                // ── GPU Card ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 82
                    radius: Theme.radiusMedium
                    color: Theme.notchSurfaceElevated
                    border.color: Theme.notchBorderSubtle
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.space8
                        spacing: 4
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
                                text: "—" // Populated dynamically in Phase 3
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: Font.Bold
                                color: Theme.notchTextTertiary
                                renderType: Theme.renderType
                            }
                        }

                        // GPU subtext (temp or VRAM)
                        Text {
                            text: "—" // Populated dynamically in Phase 3
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(10)
                            font.weight: Font.Normal
                            color: Theme.notchTextTertiary
                            renderType: Theme.renderType
                        }

                        Item { Layout.fillHeight: true }

                        // Load bar placeholder
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 3
                            radius: 1.5
                            color: Theme.notchBorderSubtle
                        }
                    }
                }
            }
        }
    }
}
