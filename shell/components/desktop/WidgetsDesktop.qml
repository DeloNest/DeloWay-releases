import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../services"
import "../"

Item {
    id: root

    // Widget contents follow the reading direction (widgets themselves are placed by
    // saved/explicit x; the defaults below start on the reading side).
    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true
    property var now: new Date()
    function defaultX(physicalX, w) { return I18n.isRTL ? root.width - w - physicalX : physicalX; }
    anchors.fill: parent

    // Click handler on wallpaper
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        z: 0

        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                DesktopManager.showWallpaperContextMenu(mouse.x, mouse.y);
            } else {
                ShellState.closeAll();
                DesktopManager.closeContextMenu();
            }
        }
    }

    // ----------------------------------------------------
    // WIDGET 1: CLOCK & CALENDAR
    // ----------------------------------------------------
    Rectangle {
        id: clockWidget
        visible: ConfigManager.isWidgetEnabled("clock")
        width: 290
        height: 150
        radius: Theme.radiusLarge
        color: Theme.colors.surface
        border.color: Theme.colors.border
        border.width: 1
        z: 10

        x: (ConfigManager.widgetPositions.clock && ConfigManager.widgetPositions.clock.x !== undefined) ? ConfigManager.widgetPositions.clock.x : root.defaultX(60, width)
        y: (ConfigManager.widgetPositions.clock && ConfigManager.widgetPositions.clock.y !== undefined) ? ConfigManager.widgetPositions.clock.y : 70

        // Drag Handle
        MouseArea {
            id: clockDragArea
            anchors.fill: parent
            drag.target: clockWidget
            drag.minimumX: 16
            drag.maximumX: root.width - clockWidget.width - 16
            drag.minimumY: 48
            drag.maximumY: root.height - clockWidget.height - 60
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            onReleased: {
                ConfigManager.setWidgetPosition("clock", clockWidget.x, clockWidget.y);
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                SymbolicIcon {
                    source: "preferences-system-symbolic"
                    iconSize: 13
                    iconColor: Theme.colors.textSecondary
                }

                Text {
                    text: I18n.tr("widget_time_date")
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(10)
                    font.weight: Font.DemiBold
                    color: Theme.colors.textSecondary
                }

                Item { Layout.fillWidth: true }

                Text {
                    font.family: Theme.typography.fontFamily
                    text: "⋮⋮"
                    font.pixelSize: Theme.fontSize(12)
                    color: Theme.colors.textTertiary
                }
            }

            RowLayout {
                spacing: 8

                Text {
                    id: clockTimeTxt
                    text: I18n.clockDigits(root.now)
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(38)
                    font.weight: Font.DemiBold
                    color: Theme.colors.text
                }

                Text {
                    visible: text.length > 0
                    text: I18n.meridiem(root.now)
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(14)
                    font.weight: Font.DemiBold
                    color: Theme.colors.textSecondary
                }
            }

            Text {
                text: I18n.fullDateText(root.now)
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(13)
                color: Theme.colors.textSecondary
            }

            // Only while the widgets desktop is shown (the date used to never update,
            // and the timer ran in every desktop mode).
            Timer {
                interval: 1000
                running: root.visible
                repeat: true
                triggeredOnStart: true
                onTriggered: root.now = new Date()
            }
        }
    }

    // ----------------------------------------------------
    // WIDGET 2: WEATHER & CONDITIONS
    // ----------------------------------------------------
    Rectangle {
        id: weatherWidget
        visible: ConfigManager.isWidgetEnabled("weather")
        width: 290
        height: 150
        radius: Theme.radiusLarge
        color: Theme.colors.surface
        border.color: Theme.colors.border
        border.width: 1
        z: 10

        x: (ConfigManager.widgetPositions.weather && ConfigManager.widgetPositions.weather.x !== undefined) ? ConfigManager.widgetPositions.weather.x : root.defaultX(370, width)
        y: (ConfigManager.widgetPositions.weather && ConfigManager.widgetPositions.weather.y !== undefined) ? ConfigManager.widgetPositions.weather.y : 70

        MouseArea {
            anchors.fill: parent
            drag.target: weatherWidget
            drag.minimumX: 16
            drag.maximumX: root.width - weatherWidget.width - 16
            drag.minimumY: 48
            drag.maximumY: root.height - weatherWidget.height - 60
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            onReleased: {
                ConfigManager.setWidgetPosition("weather", weatherWidget.x, weatherWidget.y);
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                SymbolicIcon {
                    source: "weather-sunny"
                    iconSize: 13
                    iconColor: Theme.colors.textSecondary
                }

                Text {
                    text: I18n.tr("widget_weather")
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(10)
                    font.weight: Font.DemiBold
                    color: Theme.colors.textSecondary
                }

                Item { Layout.fillWidth: true }

                Text {
                    font.family: Theme.typography.fontFamily
                    text: "⋮⋮"
                    font.pixelSize: Theme.fontSize(12)
                    color: Theme.colors.textTertiary
                }
            }

            RowLayout {
                spacing: 12

                SymbolicIcon {
                    source: "weather-sunny"
                    iconSize: 34
                    iconColor: Theme.colors.text
                }

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: SystemMonitor.weatherTemp
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(30)
                        font.weight: Font.DemiBold
                        color: Theme.colors.text
                    }
                    Text {
                        text: SystemMonitor.weatherDesc + " • " + SystemMonitor.weatherCity
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(12)
                        color: Theme.colors.textSecondary
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                Text {
                    font.family: Theme.typography.fontFamily
                    text: I18n.tr("widget_humidity") + " " + I18n.ltr(SystemMonitor.weatherHumidity)
                    font.pixelSize: Theme.fontSize(11)
                    color: Theme.colors.textTertiary
                }
                Text {
                    font.family: Theme.typography.fontFamily
                    text: I18n.tr("widget_wind") + " " + I18n.ltr(SystemMonitor.weatherWind)
                    font.pixelSize: Theme.fontSize(11)
                    color: Theme.colors.textTertiary
                }
                Text {
                    font.family: Theme.typography.fontFamily
                    text: I18n.tr("widget_uv") + " " + I18n.ltr(SystemMonitor.weatherUv)
                    font.pixelSize: Theme.fontSize(11)
                    color: Theme.colors.textTertiary
                }
            }
        }
    }

    // ----------------------------------------------------
    // WIDGET 3: HARDWARE & SYSTEM MONITOR
    // ----------------------------------------------------
    Rectangle {
        id: sysWidget
        visible: ConfigManager.isWidgetEnabled("system_monitor")
        width: 290
        height: 180
        radius: Theme.radiusLarge
        color: Theme.colors.surface
        border.color: Theme.colors.border
        border.width: 1
        z: 10

        x: (ConfigManager.widgetPositions.system_monitor && ConfigManager.widgetPositions.system_monitor.x !== undefined) ? ConfigManager.widgetPositions.system_monitor.x : root.defaultX(60, width)
        y: (ConfigManager.widgetPositions.system_monitor && ConfigManager.widgetPositions.system_monitor.y !== undefined) ? ConfigManager.widgetPositions.system_monitor.y : 240

        MouseArea {
            anchors.fill: parent
            drag.target: sysWidget
            drag.minimumX: 16
            drag.maximumX: root.width - sysWidget.width - 16
            drag.minimumY: 48
            drag.maximumY: root.height - sysWidget.height - 60
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            onReleased: {
                ConfigManager.setWidgetPosition("system_monitor", sysWidget.x, sysWidget.y);
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                SymbolicIcon {
                    source: "utilities-system-monitor-symbolic"
                    iconSize: 13
                    iconColor: Theme.colors.textSecondary
                }

                Text {
                    text: I18n.tr("widget_system")
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(10)
                    font.weight: Font.DemiBold
                    color: Theme.colors.textSecondary
                }

                Item { Layout.fillWidth: true }

                Text {
                    font.family: Theme.typography.fontFamily
                    text: "⋮⋮"
                    font.pixelSize: Theme.fontSize(12)
                    color: Theme.colors.textTertiary
                }
            }

            // CPU Usage Bar
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    Text { font.family: Theme.typography.fontFamily; text: I18n.tr("widget_cpu"); font.pixelSize: Theme.fontSize(11); color: Theme.colors.textSecondary }
                    Item { Layout.fillWidth: true }
                    Text { font.family: Theme.typography.fontFamily; text: SystemMonitor.cpuPercentText; font.weight: Font.DemiBold; font.pixelSize: Theme.fontSize(11); color: Theme.colors.text }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    radius: 3
                    color: Theme.colors.surfaceVariant

                    Rectangle {
                        anchors.left: parent.left   // fills from the reading start (mirrored)
                        width: parent.width * SystemMonitor.cpuUsage
                        height: parent.height
                        radius: 3
                        color: Theme.colors.text
                    }
                }
            }

            // Memory Usage Bar
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    Text { font.family: Theme.typography.fontFamily; text: I18n.tr("widget_memory"); font.pixelSize: Theme.fontSize(11); color: Theme.colors.textSecondary }
                    Item { Layout.fillWidth: true }
                    Text { font.family: Theme.typography.fontFamily; text: SystemMonitor.ramText; font.weight: Font.DemiBold; font.pixelSize: Theme.fontSize(11); color: Theme.colors.text }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    radius: 3
                    color: Theme.colors.surfaceVariant

                    Rectangle {
                        anchors.left: parent.left
                        width: parent.width * SystemMonitor.ramUsage
                        height: parent.height
                        radius: 3
                        color: Theme.colors.text
                    }
                }
            }

            // Battery / Power Status
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                SymbolicIcon {
                    source: SystemMonitor.hasBattery ? "battery-level-100-symbolic" : "preferences-system-symbolic"
                    iconSize: 14
                    iconColor: (SystemMonitor.hasBattery && SystemMonitor.batteryPercent <= 20) ? Theme.danger : Theme.colors.textSecondary
                }

                Text {
                    font.family: Theme.typography.fontFamily
                    text: SystemMonitor.hasBattery ? ((I18n.isRTL ? "البطارية " : "Battery ") + I18n.digits(SystemMonitor.batteryPercent) + "%")
                                                : (I18n.isRTL ? "متصل بالتيار" : "Power: AC Connected")
                    font.pixelSize: Theme.fontSize(11)
                    color: Theme.colors.textSecondary
                }
            }
        }
    }

    // ----------------------------------------------------
    // WIDGET 4: QUICK NOTES / SCRATCHPAD
    // ----------------------------------------------------
    Rectangle {
        id: notesWidget
        visible: ConfigManager.isWidgetEnabled("notes")
        width: 290
        height: 180
        radius: Theme.radiusLarge
        color: Theme.colors.surface
        border.color: Theme.colors.border
        border.width: 1
        z: 10

        x: (ConfigManager.widgetPositions.notes && ConfigManager.widgetPositions.notes.x !== undefined) ? ConfigManager.widgetPositions.notes.x : root.defaultX(370, width)
        y: (ConfigManager.widgetPositions.notes && ConfigManager.widgetPositions.notes.y !== undefined) ? ConfigManager.widgetPositions.notes.y : 240

        // Drag bar on header
        MouseArea {
            id: notesHeaderDrag
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 36
            drag.target: notesWidget
            drag.minimumX: 16
            drag.maximumX: root.width - notesWidget.width - 16
            drag.minimumY: 48
            drag.maximumY: root.height - notesWidget.height - 60
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            onReleased: {
                ConfigManager.setWidgetPosition("notes", notesWidget.x, notesWidget.y);
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                SymbolicIcon {
                    source: "applications-office-symbolic"
                    iconSize: 13
                    iconColor: Theme.colors.textSecondary
                }

                Text {
                    text: I18n.tr("widget_notes")
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(10)
                    font.weight: Font.DemiBold
                    color: Theme.colors.textSecondary
                }

                Item { Layout.fillWidth: true }

                Text {
                    font.family: Theme.typography.fontFamily
                    text: "⋮⋮"
                    font.pixelSize: Theme.fontSize(12)
                    color: Theme.colors.textTertiary
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusSmall
                color: Theme.colors.surfaceVariant
                border.color: noteArea.activeFocus ? Theme.colors.borderHighlight : Theme.colors.borderSubtle
                border.width: 1

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 8
                    clip: true

                    TextArea {
                        id: noteArea
                        placeholderText: I18n.tr("widget_notes_placeholder")
                        placeholderTextColor: Theme.colors.textTertiary
                        text: ""
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(12)
                        color: Theme.colors.text
                        wrapMode: Text.WordWrap
                        background: null

                        onTextChanged: {
                            if (loadNotesProc.isLoaded) {
                                saveNotesTimer.restart();
                            }
                        }
                    }
                }
            }
        }
    }

    // Notes Persistence Processes
    Process {
        id: loadNotesProc
        property bool isLoaded: false
        command: ["bash", "-c", "cat " + ConfigManager.userConfigDir + "/notes.txt 2>/dev/null || true"]
        stdout: SplitParser {
            onRead: function(line) {
                noteArea.text += (noteArea.text.length > 0 ? "\n" : "") + line;
            }
        }
        onExited: isLoaded = true
        Component.onCompleted: running = true
    }

    Process {
        id: saveNotesProc
    }

    Timer {
        id: saveNotesTimer
        interval: 1000
        repeat: false
        onTriggered: {
            // Text is passed as an argument, never spliced into the script: a line
            // reading "EOF" (or anything else) in the note cannot run as a command.
            saveNotesProc.exec(["sh", "-c", 'mkdir -p "$1" && printf "%s\\n" "$2" > "$1/notes.txt"',
                                "sh", ConfigManager.userConfigDir, noteArea.text]);
        }
    }
}
