import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../../theme"
import "../../services"
import ".."

// SystemPage — Tab 2 of the Time Capsule: live hardware & resource dashboard.
// Ring gauges · per-core strip + 60s trend · network / disk · live top processes.
// Monochrome: hierarchy by luminance and weight; semantic colour only in 6px StatusDots.
ColumnLayout {
    id: root

    property bool live: false          // true while this page is on screen (drives canvas repaints)
    property int dashGap: 8
    readonly property int hCoreStrip: 20
    readonly property int hTrend: 40

    spacing: dashGap

    readonly property bool hasVisibleHardware: ConfigManager.timeCapsuleShowHardware
        && (ConfigManager.timeCapsuleShowCpu || ConfigManager.timeCapsuleShowRam || ConfigManager.timeCapsuleShowGpu)
    readonly property bool showGpuGauge: ConfigManager.timeCapsuleShowGpu && HardwareService.hasGpu
    readonly property bool showGauges: root.hasVisibleHardware
        && (ConfigManager.timeCapsuleShowCpu || ConfigManager.timeCapsuleShowRam || root.showGpuGauge)
    readonly property bool showActivity: root.hasVisibleHardware && ConfigManager.timeCapsuleShowCpu
    readonly property bool showBottom: root.hasVisibleHardware

    // ── Health levels (0 nominal · 1 warning · 2 critical) → StatusDots only ──
    function loadLevel(fraction, warn, crit) {
        if (fraction === null || fraction === undefined) return 0;
        return fraction >= crit ? 2 : (fraction >= warn ? 1 : 0);
    }
    function tempLevel(tempC, warn, crit) {
        if (tempC === null || tempC === undefined || !ConfigManager.timeCapsuleShowTemps) return 0;
        return tempC >= crit ? 2 : (tempC >= warn ? 1 : 0);
    }
    readonly property int cpuLevel: Math.max(loadLevel(HardwareService.cpuUsage, 0.75, 0.92), tempLevel(HardwareService.cpuTemp, 75, 85))
    readonly property int ramLevel: loadLevel(HardwareService.ramUsage, 0.80, 0.92)
    readonly property int gpuLevel: Math.max(loadLevel(HardwareService.gpuUsage, 0.85, 0.97), tempLevel(HardwareService.gpuTemp, 80, 90))
    readonly property int diskLevel: Math.max(loadLevel(HardwareService.diskUsage, 0.85, 0.95), tempLevel(HardwareService.nvmeTemp, 65, 75))

    function tempText(t) { return (t === null || t === undefined) ? "—" : Math.round(t) + "°C"; }

    function openSystemMonitor() {
        Hyprland.dispatch("exec mission-center || gnome-system-monitor || kitty -e btop");
        ShellState.closeTimeCapsule();
    }

    component GaugeCard: DashCard {
        id: gauge
        property string title: ""
        property real value: 0
        property bool hasValue: true
        property string line1: ""
        property string line2: ""
        property int level: 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 100   // equal thirds regardless of text length

        RowLayout {
            anchors.fill: parent
            spacing: 10

            RingGauge {
                Layout.preferredWidth: 54
                Layout.preferredHeight: 54
                Layout.alignment: Qt.AlignVCenter
                value: gauge.value
                hasValue: gauge.hasValue
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                RowLayout {
                    spacing: 5
                    Text {
                        text: gauge.title
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(11)
                        font.weight: Font.DemiBold
                        color: Theme.notchText
                        renderType: Theme.renderType
                    }
                    StatusDot { level: gauge.level; Layout.alignment: Qt.AlignVCenter }
                }
                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: gauge.line1
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignLeft
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(10)
                    color: Theme.notchTextSecondary
                    renderType: Theme.renderType
                }
                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: gauge.line2
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignLeft
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(10)
                    color: Theme.notchTextTertiary
                    renderType: Theme.renderType
                }
            }
        }
    }

    // Hardware section disabled in Settings → explain instead of showing an empty page.
    Text {
        visible: !root.hasVisibleHardware
        Layout.fillWidth: true
        Layout.topMargin: 24
        Layout.bottomMargin: 24
        horizontalAlignment: Text.AlignHCenter
        text: I18n.tr("tk_hw_disabled", "Hardware monitoring is turned off in Settings")
        wrapMode: Text.WordWrap
        font.family: Theme.typography.fontFamily
        font.pixelSize: Theme.fontSize(11)
        color: Theme.notchTextTertiary
        renderType: Theme.renderType
    }

    // ── 4. RING GAUGES ───────────────────────────────────────────
    RowLayout {
        visible: root.showGauges
        Layout.fillWidth: true
        spacing: root.dashGap

        GaugeCard {
            visible: ConfigManager.timeCapsuleShowCpu
            title: "CPU"
            value: HardwareService.cpuUsage
            level: root.cpuLevel
            line1: ConfigManager.timeCapsuleShowTemps ? root.tempText(HardwareService.cpuTemp)
                                                      : (HardwareService.cores.length + " " + I18n.tr("tc_threads", "threads"))
            line2: HardwareService.cpuFreq ? (HardwareService.cpuFreq / 1000).toFixed(2) + " GHz" : ""
        }

        GaugeCard {
            visible: ConfigManager.timeCapsuleShowRam
            title: "RAM"
            value: HardwareService.ramUsage
            level: root.ramLevel
            line1: HardwareService.ramUsedGb.toFixed(1) + " / " + HardwareService.ramTotalGb.toFixed(1) + " GB"
            line2: Math.max(0, HardwareService.ramTotalGb - HardwareService.ramUsedGb).toFixed(1) + " GB " + I18n.tr("tc_free", "free")
        }

        GaugeCard {
            visible: root.showGpuGauge
            title: "GPU"
            value: HardwareService.gpuUsage || 0
            hasValue: HardwareService.gpuUsage !== null
            level: root.gpuLevel
            line1: (ConfigManager.timeCapsuleShowTemps ? root.tempText(HardwareService.gpuTemp) : "")
                   + ((ConfigManager.timeCapsuleShowTemps && HardwareService.gpuPower !== null) ? " · " : "")
                   + (HardwareService.gpuPower !== null ? Math.round(HardwareService.gpuPower) + " W" : "")
            line2: (typeof HardwareService.gpuVramUsed === "number" && typeof HardwareService.gpuVramTotal === "number")
                   ? HardwareService.gpuVramUsed.toFixed(1) + " / " + HardwareService.gpuVramTotal.toFixed(1) + " GB"
                   : ""
        }
    }

    // ── 5. PROCESSOR ACTIVITY ────────────────────────────────────
    DashCard {
        visible: root.showActivity
        Layout.fillWidth: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space6

                Text {
                    text: I18n.tr("tc_processor", "Processor")
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(11)
                    font.weight: Font.DemiBold
                    color: Theme.notchText
                    renderType: Theme.renderType
                }
                Text {
                    Layout.fillWidth: true
                    text: (HardwareService.kernel ? "Linux " + HardwareService.kernel + "  ·  " : "")
                          + HardwareService.cores.length + " " + I18n.tr("tc_threads", "threads")
                  + (HardwareService.uptimeSec > 0
                     ? "  ·  " + I18n.tr("tk_uptime", "up") + " " + HardwareService.formatUptime(HardwareService.uptimeSec, I18n.isRTL)
                     : "")
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignLeft
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(10)
                    color: Theme.notchTextTertiary
                    renderType: Theme.renderType
                }
                Text {
                    text: I18n.tr("tc_load", "Load") + "  "
                          + (HardwareService.loadAvg || []).map(v => Number(v).toFixed(2)).join("  ")
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(10)
                    font.features: { "tnum": 1 }
                    color: Theme.notchTextSecondary
                    renderType: Theme.renderType
                }
            }

            CoreStrip {
                Layout.fillWidth: true
                Layout.preferredHeight: root.hCoreStrip
                values: HardwareService.cores
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.hTrend

                TrendChart {
                    anchors.fill: parent
                    active: root.live
                    maxValue: 1.0
                    series: {
                        const s = [
                            { data: HardwareService.ramHistory, alpha: 0.35, width: 1.2, fill: false },
                            { data: HardwareService.cpuHistory, alpha: 1.0,  width: 1.7, fill: true }
                        ];
                        if (HardwareService.hasGpu)
                            s.splice(1, 0, { data: HardwareService.gpuHistory, alpha: 0.65, width: 1.2, fill: false });
                        return s;
                    }
                }

                // Legend — luminance keys matching the series weights
                Row {
                    LayoutMirroring.enabled: false          // keyed to the LTR TrendChart
                    LayoutMirroring.childrenInherit: true   // swatch before label in each entry
                    anchors.top: parent.top
                    anchors.right: parent.right
                    spacing: Theme.space8

                    Repeater {
                        model: HardwareService.hasGpu
                               ? [["CPU", 1.0], ["GPU", 0.65], ["RAM", 0.35]]
                               : [["CPU", 1.0], ["RAM", 0.35]]
                        delegate: Row {
                            required property var modelData
                            spacing: 4
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 10; height: 2; radius: 1
                                color: Theme.notchText
                                opacity: parent.modelData[1]
                            }
                            Text {
                                text: parent.modelData[0]
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(9)
                                color: Theme.notchTextTertiary
                                renderType: Theme.renderType
                            }
                        }
                    }
                }
            }
        }
    }

    // ── 6. NETWORK + DISK  |  TOP PROCESSES ──────────────────────
    RowLayout {
        id: bottomRow
        visible: root.showBottom
        Layout.fillWidth: true
        spacing: root.dashGap

        ColumnLayout {
            // 46 : 54 split without binding to the row's own width (no relayout loop)
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.horizontalStretchFactor: 46
            Layout.fillHeight: true
            spacing: root.dashGap

            // Network throughput
            DashCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                padding: 8

                RowLayout {
                    anchors.fill: parent
                    spacing: Theme.space8

                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0
                        Text {
                            text: "↓ " + HardwareService.formatRate(HardwareService.netRx)
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            font.weight: Font.Bold
                            font.features: { "tnum": 1 }
                            color: Theme.notchText
                            renderType: Theme.renderType
                        }
                        Text {
                            text: "↑ " + HardwareService.formatRate(HardwareService.netTx)
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(10)
                            font.features: { "tnum": 1 }
                            color: Theme.notchTextSecondary
                            renderType: Theme.renderType
                        }
                    }

                    TrendChart {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: 28
                        active: root.live
                        maxValue: 0
                        gridLines: false
                        series: [
                            { data: HardwareService.netTxHistory, alpha: 0.35, width: 1.1, fill: false },
                            { data: HardwareService.netRxHistory, alpha: 0.95, width: 1.4, fill: true }
                        ]
                    }
                }
            }

            // Root filesystem
            DashCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                padding: 8

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5
                        Text {
                            text: I18n.tr("tc_disk", "Disk")
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            font.weight: Font.DemiBold
                            color: Theme.notchText
                            renderType: Theme.renderType
                        }
                        StatusDot { level: root.diskLevel; Layout.alignment: Qt.AlignVCenter }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: Math.round(HardwareService.diskUsage * 100) + "%"
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            font.weight: Font.Bold
                            color: Theme.notchText
                            renderType: Theme.renderType
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 3
                        radius: 1.5
                        color: Theme.notchSurfaceHover
                        Rectangle {
                            anchors.left: parent.left
                            height: parent.height
                            width: Math.max(3, Math.round(parent.width * HardwareService.diskUsage))
                            radius: 1.5
                            color: Theme.notchText
                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: Math.round(HardwareService.diskUsedGb) + " / " + Math.round(HardwareService.diskTotalGb) + " GB"
                              + ((ConfigManager.timeCapsuleShowTemps && HardwareService.nvmeTemp !== null)
                                 ? "  ·  NVMe " + root.tempText(HardwareService.nvmeTemp) : "")
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignLeft
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(10)
                        color: Theme.notchTextTertiary
                        renderType: Theme.renderType
                    }
                }
            }
        }

        // Live top processes (instantaneous, htop convention: 100% = one core)
        DashCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            Layout.horizontalStretchFactor: 54

            ColumnLayout {
                anchors.fill: parent
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space6

                    Text {
                        text: I18n.tr("tc_processes", "Processes")
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(11)
                        font.weight: Font.DemiBold
                        color: Theme.notchText
                        renderType: Theme.renderType
                    }
                    Text {
                        Layout.fillWidth: true
                        text: HardwareService.totalTasks > 0 ? String(HardwareService.totalTasks) : ""
                        horizontalAlignment: Text.AlignLeft
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(10)
                        color: Theme.notchTextTertiary
                        renderType: Theme.renderType
                    }

                    // Open the full system monitor
                    Rectangle {
                        implicitWidth: 20
                        implicitHeight: 20
                        radius: 10
                        color: monitorMa.containsMouse ? Theme.notchSurfaceHover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                        SymbolicIcon {
                            anchors.centerIn: parent
                            iconSize: 12
                            source: "utilities-system-monitor-symbolic"
                            iconColor: monitorMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                        }
                        MouseArea {
                            id: monitorMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openSystemMonitor()
                        }
                    }
                }

                Repeater {
                    model: 3

                    delegate: ColumnLayout {
                        id: procRow
                        required property int index
                        readonly property var proc: (HardwareService.topProcs || [])[index] || null
                        Layout.fillWidth: true
                        spacing: 3
                        opacity: proc ? 1.0 : 0.35

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.space6
                            Text {
                                Layout.fillWidth: true
                                text: procRow.proc ? procRow.proc.name : "—"
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignLeft
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                color: procRow.index === 0 ? Theme.notchText : Theme.notchTextSecondary
                                renderType: Theme.renderType
                            }
                            Text {
                                text: procRow.proc ? procRow.proc.cpu.toFixed(1) + "%" : ""
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(10)
                                font.weight: Font.Bold
                                font.features: { "tnum": 1 }
                                color: Theme.notchTextSecondary
                                renderType: Theme.renderType
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 2
                            radius: 1
                            color: Theme.notchSurfaceHover
                            Rectangle {
                                anchors.left: parent.left
                                height: parent.height
                                width: Math.round(parent.width * Math.min(1, procRow.proc ? procRow.proc.cpu / 100 : 0))
                                radius: 1
                                color: Theme.notchText
                                opacity: 0.85 - procRow.index * 0.2
                                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                }

            }
        }
    }
}
