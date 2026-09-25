import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme"
import "../../services"
import ".."

// AlarmCard — one daily/once alarm. Hours and minutes are scrubbed with the wheel
// (minutes: 1 step, Shift = 5) or clicked; ringing swaps the card into Stop / Snooze.
DashCard {
    id: root

    readonly property var tk: TimeKeeperService

    // Minute-precision clock for the "rings in" countdown (no extra timers).
    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property real nowMs: clock.date ? clock.date.getTime() : Date.now()

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            SymbolicIcon { iconSize: 12; source: "alarm-symbolic"; iconColor: Theme.notchTextSecondary }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignLeft
                text: I18n.tr("tk_alarm", "Alarm")
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(11)
                font.weight: Font.DemiBold
                color: Theme.notchText
                renderType: Theme.renderType
            }
            // Warning dot while ringing (semantic, 6px)
            StatusDot { level: root.tk.alarmRinging ? 1 : 0; Layout.alignment: Qt.AlignVCenter }
            MonoSwitch {
                checked: root.tk.alarmEnabled || root.tk.snoozeAt > 0
                onToggled: (on) => root.tk.setAlarmEnabled(on)
            }
        }

        // Big HH:MM with independent wheel zones
        Row {
            Layout.alignment: Qt.AlignHCenter
            LayoutMirroring.enabled: false
            spacing: 2
            opacity: root.tk.alarmEnabled || root.tk.alarmRinging ? 1 : 0.45
            Behavior on opacity { NumberAnimation { duration: Theme.motionBase } }

            Repeater {
                model: [
                    { text: root.tk.digits(root.tk.pad2(root.tk.alarmHour)),   step: 60, fine: 60 },
                    { text: ":",                               step: 0,  fine: 0 },
                    { text: root.tk.digits(root.tk.pad2(root.tk.alarmMinute)), step: 1,  fine: 5 }
                ]
                delegate: Text {
                    id: seg
                    required property var modelData
                    text: modelData.text
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(26)
                    font.weight: Font.Bold
                    font.features: { "tnum": 1 }
                    color: Theme.notchText
                    opacity: segMa.containsMouse && modelData.step > 0 ? 0.8 : 1
                    renderType: Theme.renderType

                    MouseArea {
                        id: segMa
                        anchors.fill: parent
                        enabled: seg.modelData.step > 0 && !root.tk.alarmRinging
                        hoverEnabled: true
                        cursorShape: Qt.SizeVerCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        property real acc: 0
                        onClicked: (m) => root.tk.nudgeAlarm(m.button === Qt.RightButton ? -seg.modelData.step : seg.modelData.step)
                        onWheel: (w) => {
                            acc += w.angleDelta.y;
                            if (Math.abs(acc) < 120) return;
                            const step = (w.modifiers & Qt.ShiftModifier) ? seg.modelData.fine : seg.modelData.step;
                            root.tk.nudgeAlarm(acc > 0 ? step : -step);
                            acc = 0;
                        }
                    }
                }
            }
        }

        // Footer: status + repeat, or Stop / Snooze while ringing
        Item {
            Layout.fillWidth: true
            implicitHeight: 24

            RowLayout {
                anchors.fill: parent
                spacing: 6
                visible: !root.tk.alarmRinging
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideRight
                    text: root.tk.snoozeAt > 0
                          ? I18n.tr("tk_snooze", "Snooze") + " · " + root.tk.formatIn(root.tk.snoozeAt - root.nowMs)
                          : (root.tk.alarmEnabled
                             ? I18n.tr("tk_rings_in", "Rings in") + " " + root.tk.formatIn(root.tk.nextAlarmAt - root.nowMs)
                             : I18n.tr("tk_off", "Off"))
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(10)
                    color: Theme.notchTextTertiary
                    renderType: Theme.renderType
                }
                PillButton {
                    implicitHeight: 22
                    text: root.tk.alarmRepeatDaily ? I18n.tr("tk_daily", "Daily") : I18n.tr("tk_once", "Once")
                    selected: root.tk.alarmRepeatDaily
                    onClicked: root.tk.setAlarmRepeat(!root.tk.alarmRepeatDaily)
                }
            }

            RowLayout {
                anchors.fill: parent
                spacing: 6
                visible: root.tk.alarmRinging
                PillButton {
                    Layout.fillWidth: true
                    implicitHeight: 24
                    text: I18n.tr("tk_snooze", "Snooze") + " " + TimeKeeperService.digits(root.tk.snoozeMinutes)
                    onClicked: root.tk.snooze()
                }
                PillButton {
                    Layout.fillWidth: true
                    implicitHeight: 24
                    primary: true
                    text: I18n.tr("tk_stop", "Stop")
                    onClicked: root.tk.dismissAlarm()
                }
            }
        }
    }
}
