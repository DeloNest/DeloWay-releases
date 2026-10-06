pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

QtObject {
    id: root

    // Real CPU Metrics
    // Neutral placeholders until the first real sample (these used to be the
    // developer machine's numbers and stayed on screen if the helper failed).
    property real cpuUsage: 0
    property string cpuPercentText: "—"
    readonly property alias cpuText: root.cpuPercentText

    // Real RAM Metrics
    property real ramTotalGb: 0
    property real ramUsedGb: 0
    property real ramUsage: 0
    property string ramText: "—"

    // Real Battery Metrics (false on Desktop PC)
    property bool hasBattery: false
    property int batteryPercent: 100
    property string batteryStatusText: ""    // raw sysfs status: "Charging" / "Discharging" / "Full"

    // Real Network Metrics
    property string netDevice: ""
    property string netIp: ""
    property bool isWifi: false
    property bool isOnline: false
    // "full" | "limited" (a link, but NetworkManager finds no internet behind it) | "none"
    property string internet: "none"

    // Real Bluetooth Metrics
    property bool bluetoothOn: true

    // Real Live Weather Metrics
    // Empty until a real reading arrives; a failed fetch keeps the last good values.
    property bool weatherOk: false
    property string weatherCity: ""
    property string weatherTemp: "—"
    property string weatherDesc: ""
    property string weatherHumidity: "—"
    property string weatherWind: "—"
    property string weatherUv: "—"
    property int weatherCode: 0      // wttr.in / WWO condition code
    // The condition's icon (it was always a sun, even for "cloudy" or rain).
    readonly property string weatherIcon: {
        const c = root.weatherCode;
        const h = new Date().getHours();
        const night = h < 6 || h >= 19;
        if (c === 113) return night ? "weather-clear-night-symbolic" : "weather-clear-symbolic";
        if (c === 116) return "weather-few-clouds-symbolic";
        if (c === 119 || c === 122) return "weather-overcast-symbolic";
        if ([143, 248, 260].indexOf(c) >= 0) return "weather-fog-symbolic";
        if ([200, 386, 389, 392, 395].indexOf(c) >= 0) return "weather-storm-symbolic";
        if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 350, 368, 371, 374, 377].indexOf(c) >= 0) return "weather-snow-symbolic";
        if ([176, 263, 266, 293, 296, 353].indexOf(c) >= 0) return "weather-showers-scattered-symbolic";
        if (c >= 176) return "weather-showers-symbolic";
        return "weather-clear-symbolic";
    }

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
                        // Raw status — QuickSettings compares it with "Charging" (the old
                        // "84% • Charging" string never matched, so the charging glyph never showed).
                        root.batteryStatusText = data.hasBattery ? (data.batteryStatus || "") : "";
                    }
                    if (data.netDevice !== undefined) {
                        root.netDevice = data.netDevice;
                        root.netIp = data.netIp;
                        root.isWifi = data.isWifi;
                        root.isOnline = (data.online !== undefined) ? data.online : data.netDevice.length > 0;
                        root.internet = data.internet || (root.isOnline ? "full" : "none");
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
                    if (data.ok === false) return;   // keep the last good reading
                    root.weatherOk = true;
                    if (data.city) root.weatherCity = data.city;
                    if (data.tempC) root.weatherTemp = data.tempC + "°C";
                    if (data.desc) root.weatherDesc = data.desc;
                    if (data.humidity) root.weatherHumidity = data.humidity + "%";
                    if (data.wind) root.weatherWind = data.wind + " km/h";
                    if (data.uv) root.weatherUv = data.uv;
                    root.weatherCode = parseInt(data.code, 10) || 0;
                } catch (e) {
                    // ignore parse errors
                }
            }
        }
    }

    // Refresh timers
    // CPU/RAM/weather are only drawn by the Widgets desktop. Outside that mode the top bar
    // needs just battery + network state, so poll 3 s there and 10 s otherwise.
    readonly property bool widgetsVisible: ConfigManager.showDesktopContent && ConfigManager.desktopMode === "widgets"

    property var sysTimer: Timer {
        interval: root.widgetsVisible ? 3000 : 10000
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
        running: root.widgetsVisible
        triggeredOnStart: true
        onTriggered: {
            procWeather.running = true;
        }
    }
}
