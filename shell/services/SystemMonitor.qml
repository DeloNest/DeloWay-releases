pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

QtObject {
    id: root

    // Real CPU Metrics
    property real cpuUsage: 0.15
    property string cpuPercentText: "15%"
    readonly property alias cpuText: root.cpuPercentText

    // Real RAM Metrics
    property real ramTotalGb: 31.3
    property real ramUsedGb: 10.4
    property real ramUsage: 0.33
    property string ramText: "10.4 / 31.3 GB"

    // Real Battery Metrics (false on Desktop PC)
    property bool hasBattery: false
    property int batteryPercent: 100
    property string batteryStatusText: "AC Connected"

    // Real Network Metrics
    property string netDevice: "eno1"
    property string netIp: "192.168.100.9"
    property bool isWifi: false
    property bool isOnline: true

    // Real Bluetooth Metrics
    property bool bluetoothOn: true

    // Real Live Weather Metrics
    property string weatherCity: "Al Madina"
    property string weatherTemp: "32°C"
    property string weatherDesc: "Sunny"
    property string weatherHumidity: "16%"
    property string weatherWind: "4 km/h"
    property string weatherUv: "3"

    // Background Process for Sysinfo
    property var sysProcess: Process {
        id: procSys
        command: [ConfigManager.projectDir + "/scripts/deloway-sysinfo.py"]
        stdout: SplitParser {
            onRead: function(line) {
                try {
                    const data = JSON.parse(line.trim());
                    if (data.cpu !== undefined) {
                        root.cpuUsage = Math.max(0.0, Math.min(1.0, data.cpu / 100.0));
                        root.cpuPercentText = Math.round(data.cpu) + "%";
                    }
                    if (data.ramTotal !== undefined) {
                        root.ramTotalGb = data.ramTotal;
                        root.ramUsedGb = data.ramUsed;
                        root.ramUsage = Math.max(0.0, Math.min(1.0, data.ramPercent / 100.0));
                        root.ramText = data.ramUsed + " / " + data.ramTotal + " GB";
                    }
                    if (data.hasBattery !== undefined) {
                        root.hasBattery = data.hasBattery;
                        root.batteryPercent = data.batteryPercent;
                        root.batteryStatusText = data.hasBattery ? (data.batteryPercent + "% • " + data.batteryStatus) : "AC Connected";
                    }
                    if (data.netDevice !== undefined) {
                        root.netDevice = data.netDevice;
                        root.netIp = data.netIp;
                        root.isWifi = data.isWifi;
                        root.isOnline = true;
                    }
                    if (data.bluetoothOn !== undefined) {
                        root.bluetoothOn = data.bluetoothOn;
                    }
                } catch (e) {
                    // ignore parse errors
                }
            }
        }
    }

    // Background Process for Weather
    property var weatherProcess: Process {
        id: procWeather
        command: [ConfigManager.projectDir + "/scripts/deloway-weather.py"]
        stdout: SplitParser {
            onRead: function(line) {
                try {
                    const data = JSON.parse(line.trim());
                    if (data.city) root.weatherCity = data.city;
                    if (data.tempC) root.weatherTemp = data.tempC + "°C";
                    if (data.desc) root.weatherDesc = data.desc;
                    if (data.humidity) root.weatherHumidity = data.humidity + "%";
                    if (data.wind) root.weatherWind = data.wind + " km/h";
                    if (data.uv) root.weatherUv = data.uv;
                } catch (e) {
                    // ignore parse errors
                }
            }
        }
    }

    // Refresh timers
    property var sysTimer: Timer {
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            procSys.running = true;
        }
    }

    property var weatherTimer: Timer {
        interval: 900000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            procWeather.running = true;
        }
    }
}
