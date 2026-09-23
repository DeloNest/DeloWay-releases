import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services"

// MonthCalendar — full month grid (always 6 rows → constant height, zero jitter when
// paging months). Today = solid high-contrast disc; selected = ring; days with
// reminders carry a 3px neutral dot. Honours the configured first weekday + RTL.
ColumnLayout {
    id: root

    property date today: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()
    property string selectedKey: TimeKeeperService.dateKey(today)
    signal daySelected(string key)

    spacing: 4

    readonly property var monthsAr: ["يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو", "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"]
    readonly property var monthsEn: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property var daysAr: ["ح", "ن", "ث", "ر", "خ", "ج", "س"]
    readonly property var daysEn: ["S", "M", "T", "W", "T", "F", "S"]
    readonly property int weekStart: ConfigManager.timeCapsuleWeekStart === "sunday" ? 0
                                     : (ConfigManager.timeCapsuleWeekStart === "monday" ? 1 : 6)
    readonly property string todayKey: TimeKeeperService.dateKey(today)

    // Re-evaluated whenever events change so reminder dots stay live.
    readonly property int eventsRevision: TimeKeeperService.events.length

    function shiftMonth(delta) {
        let m = root.viewMonth + delta, y = root.viewYear;
        while (m < 0) { m += 12; y--; }
        while (m > 11) { m -= 12; y++; }
        root.viewMonth = m;
        root.viewYear = y;
    }
    function goToday() {
        root.viewYear = root.today.getFullYear();
        root.viewMonth = root.today.getMonth();
        root.daySelected(root.todayKey);
    }

    readonly property var cells: {
        const first = new Date(root.viewYear, root.viewMonth, 1);
        const offset = (first.getDay() - root.weekStart + 7) % 7;
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(root.viewYear, root.viewMonth, 1 - offset + i);
            out.push({ day: d.getDate(), key: TimeKeeperService.dateKey(d), inMonth: d.getMonth() === root.viewMonth });
        }
        return out;
    }

    // ── Month navigation ──
    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignLeft
            text: (I18n.isRTL ? root.monthsAr : root.monthsEn)[root.viewMonth] + " " + TimeKeeperService.digits(root.viewYear)
            font.family: Theme.typography.fontFamily
            font.pixelSize: Theme.fontSize(13)
            font.weight: Font.Bold
            color: Theme.notchText
            renderType: Theme.renderType
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.goToday()
            }
        }
        PillButton {
            implicitHeight: 22
            iconName: I18n.isRTL ? "go-next-symbolic" : "go-previous-symbolic"
            onClicked: root.shiftMonth(-1)
        }
        PillButton {
            implicitHeight: 22
            iconName: I18n.isRTL ? "go-previous-symbolic" : "go-next-symbolic"
            onClicked: root.shiftMonth(1)
        }
    }

    // ── Weekday header + 6×7 grid ──
    GridLayout {
        id: grid
        Layout.fillWidth: true
        columns: 7
        rowSpacing: 1
        columnSpacing: 0

        Repeater {
            model: 7
            delegate: Text {
                required property int index
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                horizontalAlignment: Text.AlignHCenter
                text: (I18n.isRTL ? root.daysAr : root.daysEn)[(root.weekStart + index) % 7]
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(9)
                font.weight: Font.DemiBold
                color: Theme.notchTextTertiary
                renderType: Theme.renderType
            }
        }

        Repeater {
            model: root.cells

            delegate: Item {
                id: cell
                required property var modelData
                readonly property bool isToday: modelData.key === root.todayKey
                readonly property bool isSelected: modelData.key === root.selectedKey
                readonly property bool hasEvents: root.eventsRevision >= 0 && TimeKeeperService.hasEvents(modelData.key)

                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: 26

                Rectangle {
                    anchors.centerIn: parent
                    width: 24; height: 24; radius: 12
                    color: cell.isToday ? Theme.qsTileActive
                           : (cell.isSelected ? Theme.notchSurfaceActive
                              : (cellMa.containsMouse ? Theme.notchSurfaceHover : "transparent"))
                    border.color: (cell.isSelected && !cell.isToday) ? Theme.notchBorderHighlight : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                }

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: cell.hasEvents ? -2 : 0
                    text: TimeKeeperService.digits(cell.modelData.day)
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(11)
                    font.weight: cell.isToday || cell.isSelected ? Font.Bold : Font.Normal
                    color: cell.isToday ? Theme.qsTileIconActive
                           : (cell.modelData.inMonth ? Theme.notchText : Theme.notchTextTertiary)
                    opacity: cell.modelData.inMonth || cell.isToday ? 1 : 0.55
                    renderType: Theme.renderType
                }

                Rectangle {
                    visible: cell.hasEvents
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    width: 3; height: 3; radius: 1.5
                    color: cell.isToday ? Theme.qsTileIconActive : Theme.notchTextSecondary
                }

                MouseArea {
                    id: cellMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!cell.modelData.inMonth) {
                            const p = cell.modelData.key.split("-");
                            root.viewYear = +p[0];
                            root.viewMonth = +p[1] - 1;
                        }
                        root.daySelected(cell.modelData.key);
                    }
                }
            }
        }

    }

    // Wheel pages months; deltas are accumulated so a touchpad swipe = one month, not ten.
    property real _wheelAcc: 0
    WheelHandler {
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            root._wheelAcc += event.angleDelta.y;
            if (Math.abs(root._wheelAcc) >= 120) {
                root.shiftMonth(root._wheelAcc > 0 ? -1 : 1);
                root._wheelAcc = 0;
            }
        }
    }
}
