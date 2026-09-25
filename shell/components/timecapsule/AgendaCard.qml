import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services"
import ".."

// AgendaCard — reminders for the selected calendar day + inline composer.
// Enter in either field adds; a timed reminder fires a notification at that minute.
DashCard {
    id: root

    property string dateKey: TimeKeeperService.dateKey(new Date())
    property string todayKey: TimeKeeperService.dateKey(new Date())

    readonly property var dayEvents: TimeKeeperService.events.length >= 0 ? TimeKeeperService.eventsFor(root.dateKey) : []

    readonly property var daysAr: ["الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت"]
    readonly property var daysEn: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    readonly property var monthsAr: ["يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو", "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"]
    readonly property var monthsEn: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    readonly property string heading: {
        if (root.dateKey === root.todayKey) return I18n.tr("tk_today", "Today");
        const p = root.dateKey.split("-");
        const d = new Date(+p[0], +p[1] - 1, +p[2]);
        return I18n.isRTL
            ? root.daysAr[d.getDay()] + " " + TimeKeeperService.digits(d.getDate()) + " " + root.monthsAr[d.getMonth()]
            : root.daysEn[d.getDay()].slice(0, 3) + ", " + root.monthsEn[d.getMonth()] + " " + d.getDate();
    }

    function submit() {
        if (TimeKeeperService.addEvent(root.dateKey, titleInput.text, timeInput.text)) {
            titleInput.text = "";
            timeInput.text = "";
            titleInput.forceActiveFocus();
        } else if (timeInput.text.length > 0 && TimeKeeperService.parseTime(timeInput.text) === null) {
            timeShake.restart();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignLeft
                text: root.heading
                elide: Text.ElideRight
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(13)
                font.weight: Font.Bold
                color: Theme.notchText
                renderType: Theme.renderType
            }
            Text {
                visible: root.dayEvents.length > 0
                text: TimeKeeperService.digits(root.dayEvents.length)
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(10)
                color: Theme.notchTextTertiary
                renderType: Theme.renderType
            }
        }

        // Event list (scrolls when the day is busy)
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 60
            clip: true
            spacing: 2
            model: root.dayEvents
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: evRow
                required property var modelData
                width: ListView.view.width
                height: 26
                radius: 8
                color: evMa.containsMouse ? Theme.notchSurfaceHover : "transparent"
                readonly property bool past: modelData.notified === true

                MouseArea { id: evMa; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 4
                    spacing: 8

                    Text {
                        Layout.preferredWidth: 34
                        horizontalAlignment: Text.AlignLeft
                        text: evRow.modelData.time ? TimeKeeperService.digits(evRow.modelData.time) : "•"
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(10)
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                        color: evRow.past ? Theme.notchTextTertiary : Theme.notchTextSecondary
                        renderType: Theme.renderType
                    }
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignLeft
                        text: evRow.modelData.title
                        elide: Text.ElideRight
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(11)
                        font.strikeout: evRow.past
                        color: evRow.past ? Theme.notchTextTertiary : Theme.notchText
                        renderType: Theme.renderType
                    }
                    Rectangle {
                        implicitWidth: 18; implicitHeight: 18; radius: 9
                        opacity: evMa.containsMouse || delMa.containsMouse ? 1 : 0
                        color: delMa.containsMouse ? Theme.notchSurfaceActive : "transparent"
                        Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }
                        Text {
                            font.family: Theme.typography.fontFamily
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: Theme.fontSize(9)
                            color: Theme.notchTextSecondary
                        }
                        MouseArea {
                            id: delMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: TimeKeeperService.removeEvent(evRow.modelData.id)
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                text: I18n.tr("tk_no_events", "No reminders")
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(11)
                color: Theme.notchTextTertiary
                renderType: Theme.renderType
            }
        }

        // Composer: [ title ........ ][ HH:MM ][ + ]
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 28
                radius: 14
                color: Theme.notchSurfaceElevated
                border.color: titleInput.activeFocus ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                TextInput {
                    id: titleInput
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignLeft   // mirrored to the right in Arabic by the inherited LayoutMirroring
                    clip: true
                    maximumLength: 80
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(11)
                    color: Theme.notchText
                    selectionColor: Theme.notchSurfaceActive
                    selectedTextColor: Theme.notchText
                    onAccepted: root.submit()
                    KeyNavigation.tab: timeInput

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: parent.horizontalAlignment
                        visible: titleInput.text.length === 0
                        text: I18n.tr("tk_new_event", "New reminder…")
                        font: titleInput.font
                        color: Theme.notchTextTertiary
                    }
                }
            }

            Rectangle {
                id: timeBox
                implicitWidth: 54
                implicitHeight: 28
                radius: 14
                color: Theme.notchSurfaceElevated
                border.color: timeInput.activeFocus ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                border.width: 1

                // Invalid time → brief horizontal shake (transform only, no relayout)
                transform: Translate { id: shakeT }
                SequentialAnimation {
                    id: timeShake
                    NumberAnimation { target: shakeT; property: "x"; to: 4; duration: 40 }
                    NumberAnimation { target: shakeT; property: "x"; to: -4; duration: 40 }
                    NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 40 }
                }

                TextInput {
                    id: timeInput
                    anchors.fill: parent
                    horizontalAlignment: TextInput.AlignHCenter
                    verticalAlignment: TextInput.AlignVCenter
                    maximumLength: 5
                    inputMethodHints: Qt.ImhTime
                    validator: RegularExpressionValidator { regularExpression: /^[0-9]{0,2}[:.]?[0-9]{0,2}$/ }
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(11)
                    font.features: { "tnum": 1 }
                    color: Theme.notchText
                    selectionColor: Theme.notchSurfaceActive
                    onAccepted: root.submit()
                    // Auto-insert the colon after two digits.
                    onTextEdited: if (/^\d{2}$/.test(text)) { text = text + ":"; cursorPosition = 3; }

                    Text {
                        anchors.centerIn: parent
                        visible: timeInput.text.length === 0
                        text: "--:--"
                        font: timeInput.font
                        color: Theme.notchTextTertiary
                    }
                }
            }

            PillButton {
                implicitHeight: 28
                primary: true
                iconName: "list-add-symbolic"
                enabled: titleInput.text.trim().length > 0
                onClicked: root.submit()
            }
        }
    }
}
