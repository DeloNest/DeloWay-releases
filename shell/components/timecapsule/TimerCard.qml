import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services"
import ".."

// TimerCard — countdown ring (remaining / total) + presets + transport.
// Idle: wheel on the ring adjusts the duration by 1 minute. Runs in the service, so it
// keeps counting (and fires) while the capsule is collapsed.
DashCard {
    id: root

    readonly property var tk: TimeKeeperService
    readonly property var presets: [1, 5, 10, 25]

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            SymbolicIcon { iconSize: 12; source: "preferences-system-time-symbolic"; iconColor: Theme.notchTextSecondary }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignLeft
                text: I18n.tr("tk_timer", "Timer")
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(11)
                font.weight: Font.DemiBold
                color: Theme.notchText
                renderType: Theme.renderType
            }
            Text {
                visible: root.tk.timerFinished
                text: I18n.tr("tk_done", "Done")
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(10)
                font.weight: Font.Bold
                color: Theme.notchText
                renderType: Theme.renderType
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            RingGauge {
                id: ring
                Layout.preferredWidth: 62
                Layout.preferredHeight: 62
                stroke: 4
                value: root.tk.timerTotalSec > 0 ? root.tk.timerRemainingSec / root.tk.timerTotalSec : 0
                centerText: root.tk.formatClock(root.tk.timerRemainingSec)

                // Finished → gentle breathing of the whole ring (luminance only)
                SequentialAnimation on opacity {
                    running: root.tk.timerFinished
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) ring.opacity = 1
                    NumberAnimation { to: 0.35; duration: 600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0;  duration: 600; easing.type: Easing.InOutSine }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !root.tk.timerRunning
                    cursorShape: Qt.SizeVerCursor
                    property real acc: 0
                    onClicked: root.tk.toggleTimer()
                    onWheel: (w) => {
                        acc += w.angleDelta.y;
                        if (Math.abs(acc) < 120) return;
                        root.tk.nudgeTimer(acc > 0 ? 1 : -1);
                        acc = 0;
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                // Presets
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: root.presets
                        delegate: PillButton {
                            required property int modelData
                            Layout.fillWidth: true
                            implicitHeight: 22
                            text: TimeKeeperService.digits(modelData) + (I18n.isRTL ? "د" : "m")
                            selected: !root.tk.timerRunning && root.tk.timerTotalSec === modelData * 60
                            enabled: !root.tk.timerRunning
                            onClicked: root.tk.setTimerMinutes(modelData)
                        }
                    }
                }

                // Transport
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    PillButton {
                        Layout.fillWidth: true
                        implicitHeight: 26
                        primary: true
                        iconName: root.tk.timerRunning ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                        onClicked: root.tk.toggleTimer()
                    }
                    PillButton {
                        implicitHeight: 26
                        iconName: "view-refresh-symbolic"
                        enabled: root.tk.timerRunning || root.tk.timerFinished
                                 || root.tk.timerRemainingSec !== root.tk.timerTotalSec
                        onClicked: root.tk.resetTimer()
                    }
                }
            }
        }
    }
}
