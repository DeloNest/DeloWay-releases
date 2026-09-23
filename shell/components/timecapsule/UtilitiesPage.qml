import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services"

// UtilitiesPage — Tab 1 of the Time Capsule: time management.
//   ┌ Month calendar ┬ Agenda for the selected day ┐
//   └ Alarm          ┴ Timer                       ┘
// The two rows share column proportions so edges line up across cards.
ColumnLayout {
    id: root

    property date today: new Date()
    property int dashGap: 8
    property string selectedKey: TimeKeeperService.dateKey(today)

    spacing: dashGap

    // Keep the selection on "today" across midnight unless the user picked another day.
    property string _lastToday: TimeKeeperService.dateKey(today)
    onTodayChanged: {
        const k = TimeKeeperService.dateKey(today);
        if (root.selectedKey === root._lastToday) root.selectedKey = k;
        root._lastToday = k;
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: root.dashGap

        DashCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            Layout.horizontalStretchFactor: 52

            MonthCalendar {
                anchors.fill: parent
                today: root.today
                selectedKey: root.selectedKey
                onDaySelected: (key) => root.selectedKey = key
            }
        }

        AgendaCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            Layout.horizontalStretchFactor: 48
            dateKey: root.selectedKey
            todayKey: TimeKeeperService.dateKey(root.today)
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: root.dashGap

        AlarmCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            Layout.horizontalStretchFactor: 52
        }

        TimerCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            Layout.horizontalStretchFactor: 48
        }
    }
}
