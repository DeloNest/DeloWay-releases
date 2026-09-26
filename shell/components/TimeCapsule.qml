import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"
import "./timecapsule"

// TimeCapsule — Top-left status capsule for DeloWay Smart TopBar.
// Compact mode: Crisp bold time + localized short date powered by SystemClock.
// Expanded mode (Phase 2): Big time + full date + Hijri date, monthly calendar, and hardware telemetry.
// Lives inside the unified TopBar window (TopBar.qml) as a plain Item, so its frame is
// composed in the same buffer as the Notch: reflow is a pure scene-graph animation with
// no layer-shell margins, no cross-surface repaint timing and no collision.
Item {
    id: root

    required property ShellScreen targetScreen
    anchors.fill: parent
    visible: ConfigManager.timeCapsuleEnabled

    // Exposed to TopBar for the unified input mask.
    readonly property alias maskItem: notchFrame

    readonly property real earRadius: Theme.notchEarRadius
    readonly property real bottomRadius: 26
    readonly property real capsuleGap: Theme.capsuleGap

    // Distance from the screen centre to this capsule's frame edge. Tracks the Notch's
    // live outer width every animation frame, clamped so the capsule never leaves the screen.
    readonly property real notchSlotOffset: {
        const desired = ShellState.smartNotchCurrentWidth / 2 + root.capsuleGap;
        const maxOffset = root.width / 2 - Theme.capsuleEdgeMargin - notchFrame.width;
        return Math.round(Math.max(0, Math.min(desired, maxOffset)));
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

    // ── Dashboard geometry ────────────────────────────────────────────────
    // Width adapts to the room left of the Notch (400..500px); height is the exact sum of
    // the visible sections so the frame animation lands on the final size with no jump.
    readonly property real expandedWidth: Math.round(Math.max(400, Math.min(500,
        root.width / 2 - ShellState.smartNotchCurrentWidth / 2 - root.capsuleGap
        - Theme.capsuleEdgeMargin - root.earRadius * 2)))

    readonly property int dashPad: 14
    readonly property int dashGap: 8
    readonly property int hProgress: 2

    // Exact content height from the layout itself (expandedCol never goes invisible, it
    // only fades), so the frame always opens to precisely the size of its sections.
    readonly property real expandedHeight: Math.ceil(expandedCol.implicitHeight + root.dashPad * 2)

    // ── Tabs ──────────────────────────────────────────────────────────────
    // Tab index lives in ShellState (survives collapse, drivable over IPC).
    // Both pages stay instantiated; only one is "current". The page viewport height is a
    // single animated number (pageHeight) so switching tabs morphs the frame height in
    // lock-step with the cross-slide — no Loader churn, no relayout jumps.
    readonly property int tab: ShellState.timeCapsuleTab
    readonly property real activePageHeight: root.tab === 0 ? utilPage.implicitHeight : sysPage.implicitHeight
    property real pageHeight: activePageHeight
    Behavior on pageHeight {
        enabled: root.isExpanded
        NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter }
    }
    readonly property real slideSign: I18n.isRTL ? -1 : 1
    readonly property int slideDistance: 28

    // Day-granular "today" (the seconds clock must not re-evaluate 42 calendar cells/s).
    readonly property string todayKey: TimeKeeperService.dateKey(sysClock.date || new Date())
    property date todayDate: new Date()
    onTodayKeyChanged: root.todayDate = new Date()

    Shortcut {
        sequence: "Ctrl+Tab"
        enabled: root.isExpanded
        onActivated: ShellState.setTimeCapsuleTab(root.tab === 0 ? 1 : 0)
    }

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

    // Qt's "h"/"hh" never produce 12-hour digits without an AP marker in the same format,
    // so "h:mm" showed "13:19 م". The I18n helpers compute 12h digits explicitly.
    readonly property string formattedTime: I18n.clockText(sysClock.date, false)

    readonly property string formattedExpandedTime: I18n.clockText(sysClock.date, ConfigManager.timeCapsuleShowSeconds)

    readonly property string expandedClockDigits: {
        const d = sysClock.date;
        if (!d) return "--:--";
        const hh = (ConfigManager.clockFormat === "24h") ? String(d.getHours()).padStart(2, "0") : String(d.getHours() % 12 || 12);
        const ss = ConfigManager.timeCapsuleShowSeconds ? ":" + String(d.getSeconds()).padStart(2, "0") : "";
        return I18n.digits(hh + ":" + String(d.getMinutes()).padStart(2, "0") + ss);
    }

    readonly property string formattedAmPm: I18n.meridiem(sysClock.date)

    readonly property string formattedShortDate: {
        const d = sysClock.date;
        if (!d) return "";
        const dayIdx = d.getDay();
        const monthIdx = d.getMonth();
        const dateNum = d.getDate();
        const useAr = I18n.arabicDigits;
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
        const useAr = I18n.arabicDigits;
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

    // ── Clock extras ──
    readonly property real dayProgress: {
        const d = sysClock.date;
        if (!d) return 0;
        return (d.getHours() * 3600 + d.getMinutes() * 60 + d.getSeconds()) / 86400;
    }

    // ── Outer Shape & Notch Framing ───────────────────────────────────────
    NotchFrame {
        id: notchFrame
        // Fixed side, the same in every language: left of the Notch unless Settings → Top
        // Bar swaps the capsules. The edge facing the Notch stays notchSlotOffset px from
        // the screen centre either way.
        x: ConfigManager.clockOnRight ? Math.round(root.width / 2 + root.notchSlotOffset)
                                      : Math.round(root.width / 2 - root.notchSlotOffset - width)
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

                // Live timer / ringing alarm pill (only when something is running)
                Rectangle {
                    readonly property bool ringing: TimeKeeperService.alarmRinging
                    visible: ringing || TimeKeeperService.timerRunning || TimeKeeperService.timerFinished
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: liveRow.implicitWidth + 14
                    implicitHeight: 22
                    radius: 11
                    color: Theme.notchSurfaceActive

                    Row {
                        id: liveRow
                        anchors.centerIn: parent
                        spacing: 4
                        SymbolicIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            iconSize: 11
                            source: "alarm-symbolic"
                            iconColor: Theme.notchText
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: TimeKeeperService.alarmRinging
                                  ? I18n.tr("tk_ringing", "Ringing")
                                  : TimeKeeperService.formatClock(TimeKeeperService.timerRemainingSec)
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            font.weight: Font.Bold
                            font.features: { "tnum": 1 }
                            color: Theme.notchText
                            renderType: Theme.renderType
                        }
                    }
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
                    if (wheel.angleDelta.y < 0) {
                        ShellState.openTimeCapsule();
                    } else if (wheel.angleDelta.y > 0) {
                        ShellState.closeTimeCapsule();
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════════
        // EXPANDED VIEW: Header + Monthly Calendar + Hardware Cards
        // ═══════════════════════════════════════════════════════════════════
        MouseArea {
            anchors.fill: parent
            enabled: root.isExpanded
            acceptedButtons: Qt.NoButton
            onWheel: (wheel) => {
                wheel.accepted = true;
                if (wheel.angleDelta.y < 0) {
                    ShellState.openTimeCapsule();
                } else if (wheel.angleDelta.y > 0) {
                    ShellState.closeTimeCapsule();
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════════
        // EXPANDED VIEW — tabbed mini-dashboard
        //   Header   : clock · date · Hijri · [Time | System] switcher · collapse
        //   Hairline : day progress
        //   Viewport : UtilitiesPage (calendar, reminders, alarm, timer)
        //              SystemPage    (gauges, cores, trend, net/disk, processes)
        // ═══════════════════════════════════════════════════════════════════
        ColumnLayout {
            id: expandedCol
            anchors.fill: parent
            anchors.margins: root.dashPad
            spacing: root.dashGap
            enabled: root.isExpanded
            opacity: root.isExpanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
            LayoutMirroring.enabled: I18n.isRTL
            LayoutMirroring.childrenInherit: true

            // ── HEADER ───────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space12

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0

                    RowLayout {
                        spacing: Theme.space6
                        // Mirrors: the digits are one Text (always LTR by bidi); the
                        // ص/م marker goes to the reading end, as in the compact capsule.

                        Text {
                            text: root.expandedClockDigits
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(26)
                            font.weight: Font.Bold
                            font.features: { "tnum": 1 }
                            color: Theme.notchText
                            renderType: Theme.renderType
                        }
                        Text {
                            text: root.formattedAmPm
                            visible: text.length > 0
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(12)
                            font.weight: Font.DemiBold
                            color: Theme.notchTextSecondary
                            renderType: Theme.renderType
                            Layout.alignment: Qt.AlignBaseline
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.formattedFullDate
                              + (ConfigManager.timeCapsuleShowHijri ? "  ·  " + root.formattedHijriDate : "")
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignLeft
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(11)
                        color: Theme.notchTextSecondary
                        renderType: Theme.renderType
                    }
                }

                TabSwitcher {
                    Layout.alignment: Qt.AlignVCenter
                    currentIndex: root.tab
                    tabs: [
                        { label: I18n.tr("tk_tab_time", "Time"),     icon: "x-office-calendar-symbolic" },
                        { label: I18n.tr("tk_tab_system", "System"), icon: "utilities-system-monitor-symbolic" }
                    ]
                    onActivated: (i) => ShellState.setTimeCapsuleTab(i)
                }

                // Collapse
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 26
                    implicitHeight: 26
                    radius: 13
                    color: tcCollapseMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurface
                    border.color: Theme.notchBorderSubtle
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 2
                        text: "⌃"
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(13)
                        font.weight: Font.Bold
                        color: tcCollapseMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                    }
                    MouseArea {
                        id: tcCollapseMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ShellState.closeTimeCapsule()
                    }
                }
            }

            // ── DAY PROGRESS ─────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.hProgress

                Rectangle { anchors.fill: parent; radius: 1; color: Theme.notchBorderSubtle }
                Rectangle {
                    anchors.left: parent.left
                    height: parent.height
                    width: Math.round(parent.width * root.dayProgress)
                    radius: 1
                    color: Theme.notchTextTertiary
                    Behavior on width { NumberAnimation { duration: Theme.motionBase } }
                }
            }

            // ── PAGE VIEWPORT ────────────────────────────────────────────
            Item {
                id: pageViewport
                Layout.fillWidth: true
                Layout.preferredHeight: root.pageHeight
                clip: true

                UtilitiesPage {
                    id: utilPage
                    readonly property bool current: root.tab === 0
                    width: pageViewport.width
                    dashGap: root.dashGap
                    today: root.todayDate
                    enabled: current
                    x: current ? 0 : -root.slideSign * root.slideDistance
                    opacity: current ? 1 : 0
                    Behavior on x { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
                    Behavior on opacity { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
                }

                SystemPage {
                    id: sysPage
                    readonly property bool current: root.tab === 1
                    width: pageViewport.width
                    dashGap: root.dashGap
                    live: root.isExpanded && current
                    enabled: current
                    x: current ? 0 : root.slideSign * root.slideDistance
                    opacity: current ? 1 : 0
                    Behavior on x { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
                    Behavior on opacity { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
                }
            }
        }
    }
}
