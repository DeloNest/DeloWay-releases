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

        x: (ConfigManager.widgetPositions.clock && ConfigManager.widgetPositions.clock.x !== undefined) ? ConfigManager.widgetPositions.clock.x : 60
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
                    text: "TIME & DATE"
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: Theme.colors.textSecondary
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "⋮⋮"
                    font.pixelSize: 12
                    color: Theme.colors.textTertiary
                }
            }

            RowLayout {
                spacing: 8

                Text {
                    id: clockTimeTxt
                    text: Qt.formatTime(new Date(), ConfigManager.clockFormat === "24h" ? "hh:mm" : "hh:mm")
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: 38
                    font.weight: Font.DemiBold
                    color: Theme.colors.text
                }

                Text {
                    visible: ConfigManager.clockFormat !== "24h"
                    text: Qt.formatTime(new Date(), "AP")
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: Theme.colors.textSecondary
                }
            }

            Text {
                text: Qt.formatDate(new Date(), "dddd, MMMM d, yyyy")
                font.family: Theme.typography.fontFamily
                font.pixelSize: 13
                color: Theme.colors.textSecondary
            }

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: {
                    clockTimeTxt.text = Qt.formatTime(new Date(), ConfigManager.clockFormat === "24h" ? "hh:mm" : "hh:mm");
                }
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

        x: (ConfigManager.widgetPositions.weather && ConfigManager.widgetPositions.weather.x !== undefined) ? ConfigManager.widgetPositions.weather.x : 370
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
                    iconColor: Theme.colors.warning
                }

                Text {
                    text: "WEATHER & FORECAST"
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: Theme.colors.warning
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "⋮⋮"
                    font.pixelSize: 12
                    color: Theme.colors.textTertiary
                }
            }

            RowLayout {
                spacing: 12

                SymbolicIcon {
                    source: "weather-sunny"
                    iconSize: 34
                    iconColor: Theme.colors.warning
                }

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: SystemMonitor.weatherTemp
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: 30
                        font.weight: Font.DemiBold
                        color: Theme.colors.text
                    }
                    Text {
                        text: SystemMonitor.weatherDesc + " • " + SystemMonitor.weatherCity
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: 12
                        color: Theme.colors.textSecondary
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                Text {
                    text: "Humidity: " + SystemMonitor.weatherHumidity
                    font.pixelSize: 11
                    color: Theme.colors.textTertiary
                }
                Text {
                    text: "Wind: " + SystemMonitor.weatherWind
                    font.pixelSize: 11
                    color: Theme.colors.textTertiary
                }
                Text {
                    text: "UV Index: " + SystemMonitor.weatherUv
                    font.pixelSize: 11
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

        x: (ConfigManager.widgetPositions.system_monitor && ConfigManager.widgetPositions.system_monitor.x !== undefined) ? ConfigManager.widgetPositions.system_monitor.x : 60
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
                    text: "SYSTEM MONITOR"
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: Theme.colors.textSecondary
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "⋮⋮"
                    font.pixelSize: 12
                    color: Theme.colors.textTertiary
                }
            }

            // CPU Usage Bar
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "CPU Load"; font.pixelSize: 11; color: Theme.colors.textSecondary }
                    Item { Layout.fillWidth: true }
                    Text { text: SystemMonitor.cpuPercentText; font.weight: Font.DemiBold; font.pixelSize: 11; color: Theme.colors.text }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    radius: 3
                    color: Theme.colors.surfaceVariant

                    Rectangle {
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
                    Text { text: "Memory Usage"; font.pixelSize: 11; color: Theme.colors.textSecondary }
                    Item { Layout.fillWidth: true }
                    Text { text: SystemMonitor.ramText; font.weight: Font.DemiBold; font.pixelSize: 11; color: Theme.colors.text }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    radius: 3
                    color: Theme.colors.surfaceVariant

                    Rectangle {
                        width: parent.width * SystemMonitor.ramUsage
                        height: parent.height
                        radius: 3
                        color: Theme.colors.success
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
                    iconColor: Theme.colors.success
                }

                Text {
                    text: SystemMonitor.hasBattery ? ("Battery " + SystemMonitor.batteryPercent + "%") : "Power: AC Connected"
                    font.pixelSize: 11
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

        x: (ConfigManager.widgetPositions.notes && ConfigManager.widgetPositions.notes.x !== undefined) ? ConfigManager.widgetPositions.notes.x : 370
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
                    iconColor: Theme.colors.warning
                }

                Text {
                    text: "QUICK NOTES"
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: Theme.colors.warning
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "⋮⋮"
                    font.pixelSize: 12
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
                        placeholderText: "Type thoughts, tasks or commands here..."
                        placeholderTextColor: Theme.colors.textTertiary
                        text: ""
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: 12
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
            saveNotesProc.exec(["bash", "-c", "mkdir -p " + ConfigManager.userConfigDir + " && cat << 'EOF' > " + ConfigManager.userConfigDir + "/notes.txt\n" + noteArea.text + "\nEOF"]);
        }
    }
}
