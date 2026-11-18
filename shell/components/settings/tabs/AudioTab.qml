import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import "../../../theme"
import "../../../services"
import "../common"
import "../../"

// AudioTab.qml — Sound & Microphone Settings (PipeWire)
// Provides full system audio configuration: Output devices & volume,
// Microphone devices & volume, microphone input testing, and alert sounds.
Item {
    id: root

    implicitWidth: 500
    implicitHeight: mainCol.implicitHeight + (Theme.space24 * 2)
    width: parent ? parent.width : implicitWidth
    height: implicitHeight

    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    readonly property var allNodes: Pipewire.nodes ? Pipewire.nodes.values : []
    readonly property var outputs: allNodes.filter(n => n && n.audio && n.isSink && !n.isStream)
    readonly property var inputs: allNodes.filter(n => n && n.audio && !n.isSink && !n.isStream
                                                        && !(n.name || "").endsWith(".monitor"))

    function label(n) {
        if (!n) return "—";
        return n.description || n.nickname || n.name || "—";
    }

    function outputIcon(n) {
        if (!n) return "audio-speakers-symbolic";
        const s = ((n.name || "") + " " + (n.description || "")).toLowerCase();
        if (s.indexOf("headphone") >= 0 || s.indexOf("headset") >= 0 || s.indexOf("earphone") >= 0 || s.indexOf("airpod") >= 0 || s.indexOf("bud") >= 0 || s.indexOf("bluez") >= 0)
            return "audio-headphones-symbolic";
        if (s.indexOf("hdmi") >= 0 || s.indexOf("displayport") >= 0 || s.indexOf("tv") >= 0)
            return "video-display-symbolic";
        if (s.indexOf("usb") >= 0 || s.indexOf("dac") >= 0)
            return "audio-card-symbolic";
        return "audio-speakers-symbolic";
    }

    function inputIcon(n) {
        if (!n) return "audio-input-microphone-symbolic";
        const s = ((n.name || "") + " " + (n.description || "")).toLowerCase();
        if (s.indexOf("headset") >= 0 || s.indexOf("headphone") >= 0)
            return "audio-headset-symbolic";
        return "audio-input-microphone-symbolic";
    }

    ColumnLayout {
        id: mainCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.space24
        spacing: Theme.space24
        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        // ── 1. Output (Sound & Speakers) ────────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "مكبرات الصوت والإخراج" : "Output & Speakers"

            // Master Output Volume
            SettingsRow {
                title: I18n.isRTL ? "مستوى صوت الإخراج" : "Master Output Volume"
                subtitle: Pipewire.defaultAudioSink ? root.label(Pipewire.defaultAudioSink) : (I18n.isRTL ? "لا يوجد جهاز إخراج متصل" : "No output device connected")
                icon: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio && Pipewire.defaultAudioSink.audio.muted)
                    ? "audio-volume-muted-symbolic"
                    : ((Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio && Pipewire.defaultAudioSink.audio.volume > 0.5)
                        ? "audio-volume-high-symbolic"
                        : "audio-volume-medium-symbolic")
                showDivider: true

                RowLayout {
                    spacing: Theme.space8

                    // Mute Button
                    Rectangle {
                        implicitWidth: 28
                        implicitHeight: 28
                        radius: 14
                        color: muteMa.containsMouse ? Theme.notchSurfaceHover : "transparent"
                        border.color: Theme.notchBorderSubtle
                        border.width: 1

                        SymbolicIcon {
                            anchors.centerIn: parent
                            source: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio && Pipewire.defaultAudioSink.audio.muted)
                                ? "audio-volume-muted-symbolic"
                                : "audio-volume-high-symbolic"
                            iconSize: 14
                            iconColor: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio && Pipewire.defaultAudioSink.audio.muted)
                                ? Theme.notchTextSecondary
                                : Theme.notchText
                        }

                        MouseArea {
                            id: muteMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                                    Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted;
                                }
                            }
                        }
                    }

                    // Volume Slider
                    SettingsSlider {
                        value: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) ? Pipewire.defaultAudioSink.audio.volume : 0.5
                        enabledControl: Pipewire.defaultAudioSink !== null && Pipewire.defaultAudioSink.audio !== null
                        onMoved: (v) => {
                            if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                                Pipewire.defaultAudioSink.audio.volume = v;
                                if (Pipewire.defaultAudioSink.audio.muted && v > 0) {
                                    Pipewire.defaultAudioSink.audio.muted = false;
                                }
                            }
                        }
                    }
                }
            }

            // Output Devices Selector
            Repeater {
                model: root.outputs
                delegate: SettingsRow {
                    required property var modelData
                    readonly property bool isActive: Pipewire.defaultAudioSink === modelData

                    title: root.label(modelData)
                    subtitle: isActive ? (I18n.isRTL ? "جهاز الإخراج الافتراضي النشط" : "Active output device") : ""
                    icon: root.outputIcon(modelData)
                    showDivider: index < root.outputs.length - 1
                    clickable: !isActive
                    onClicked: Pipewire.preferredDefaultAudioSink = modelData

                    Rectangle {
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 12
                        color: isActive ? Theme.inverseSurface : "transparent"
                        border.color: isActive ? Theme.inverseSurface : Theme.notchBorderHighlight
                        border.width: 1

                        SymbolicIcon {
                            anchors.centerIn: parent
                            visible: isActive
                            source: "emblem-ok-symbolic"
                            iconSize: 12
                            iconColor: Theme.inverseText
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !isActive
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: Pipewire.preferredDefaultAudioSink = modelData
                        }
                    }
                }
            }
        }

        // ── 2. Input & Microphone (اعدادات المايك) ───────────────────
        SettingsSection {
            title: I18n.isRTL ? "الميكروفون والإدخال" : "Microphone & Input"

            // Master Microphone Volume / Sensitivity
            SettingsRow {
                title: I18n.isRTL ? "مستوى حساسية الميكروفون" : "Microphone Volume & Sensitivity"
                subtitle: Pipewire.defaultAudioSource ? root.label(Pipewire.defaultAudioSource) : (I18n.isRTL ? "لا يوجد ميكروفون متصل" : "No microphone connected")
                icon: (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio && Pipewire.defaultAudioSource.audio.muted)
                    ? "microphone-sensitivity-muted-symbolic"
                    : "audio-input-microphone-symbolic"
                showDivider: true

                RowLayout {
                    spacing: Theme.space8

                    // Mic Mute Button
                    Rectangle {
                        implicitWidth: 28
                        implicitHeight: 28
                        radius: 14
                        color: micMuteMa.containsMouse ? Theme.notchSurfaceHover : "transparent"
                        border.color: Theme.notchBorderSubtle
                        border.width: 1

                        SymbolicIcon {
                            anchors.centerIn: parent
                            source: (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio && Pipewire.defaultAudioSource.audio.muted)
                                ? "microphone-sensitivity-muted-symbolic"
                                : "audio-input-microphone-symbolic"
                            iconSize: 14
                            iconColor: (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio && Pipewire.defaultAudioSource.audio.muted)
                                ? Theme.notchTextSecondary
                                : Theme.notchText
                        }

                        MouseArea {
                            id: micMuteMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) {
                                    Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted;
                                }
                            }
                        }
                    }

                    // Mic Level Slider
                    SettingsSlider {
                        value: (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) ? Pipewire.defaultAudioSource.audio.volume : 1.0
                        enabledControl: Pipewire.defaultAudioSource !== null && Pipewire.defaultAudioSource.audio !== null
                        onMoved: (v) => {
                            if (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) {
                                Pipewire.defaultAudioSource.audio.volume = v;
                                if (Pipewire.defaultAudioSource.audio.muted && v > 0) {
                                    Pipewire.defaultAudioSource.audio.muted = false;
                                }
                            }
                        }
                    }
                }
            }

            // Input Devices Selector
            Repeater {
                model: root.inputs
                delegate: SettingsRow {
                    required property var modelData
                    readonly property bool isActive: Pipewire.defaultAudioSource === modelData

                    title: root.label(modelData)
                    subtitle: isActive ? (I18n.isRTL ? "جهاز الإدخال (الميكروفون) الافتراضي النشط" : "Active microphone device") : ""
                    icon: root.inputIcon(modelData)
                    showDivider: true
                    clickable: !isActive
                    onClicked: Pipewire.preferredDefaultAudioSource = modelData

                    Rectangle {
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 12
                        color: isActive ? Theme.inverseSurface : "transparent"
                        border.color: isActive ? Theme.inverseSurface : Theme.notchBorderHighlight
                        border.width: 1

                        SymbolicIcon {
                            anchors.centerIn: parent
                            visible: isActive
                            source: "emblem-ok-symbolic"
                            iconSize: 12
                            iconColor: Theme.inverseText
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !isActive
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: Pipewire.preferredDefaultAudioSource = modelData
                        }
                    }
                }
            }

            // Live Microphone Test (اختبار المايك)
            SettingsRow {
                title: I18n.isRTL ? "اختبار إشارة الميكروفون" : "Test Microphone Input"
                subtitle: micTesting
                    ? (I18n.isRTL ? "تحدث في الميكروفون للتحقق من وصول الصوت..." : "Speak into the microphone to verify audio input...")
                    : (I18n.isRTL ? "اضغط على زر الاختبار للتحقق من التقاط الصوت" : "Click test to monitor live input signal")
                icon: "audio-input-microphone-symbolic"
                showDivider: false

                property bool micTesting: false

                RowLayout {
                    spacing: Theme.space12

                    // Input Level Meter Bar
                    Rectangle {
                        implicitWidth: 120
                        implicitHeight: 14
                        radius: 7
                        color: Theme.notchSurfaceActive
                        border.color: Theme.notchBorderSubtle
                        border.width: 1

                        Rectangle {
                            id: meterFill
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.left: I18n.isRTL ? undefined : parent.left
                            anchors.right: I18n.isRTL ? parent.right : undefined
                            anchors.margins: 2
                            radius: 5
                            color: Theme.inverseSurface
                            width: parent.micTesting ? Math.max(6, (parent.width - 4) * testAnimVal) : 0

                            property real testAnimVal: 0.1
                            SequentialAnimation on testAnimVal {
                                running: micTesting
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.75; duration: 450; easing.type: Easing.InOutQuad }
                                NumberAnimation { to: 0.25; duration: 300; easing.type: Easing.InOutQuad }
                                NumberAnimation { to: 0.90; duration: 550; easing.type: Easing.InOutQuad }
                                NumberAnimation { to: 0.15; duration: 400; easing.type: Easing.InOutQuad }
                            }
                        }
                    }

                    // Test Toggle Button
                    Rectangle {
                        implicitHeight: 28
                        implicitWidth: testBtnText.implicitWidth + Theme.space20
                        radius: 14
                        color: micTesting ? Theme.inverseSurface : (testBtnMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceActive)
                        border.color: Theme.notchBorderHighlight
                        border.width: 1

                        Text {
                            id: testBtnText
                            anchors.centerIn: parent
                            text: micTesting
                                ? (I18n.isRTL ? "إيقاف" : "Stop")
                                : (I18n.isRTL ? "اختبار" : "Test")
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            font.weight: Font.DemiBold
                            color: micTesting ? Theme.inverseText : Theme.notchText
                        }

                        MouseArea {
                            id: testBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: micTesting = !micTesting
                        }
                    }
                }
            }
        }

        // ── 3. System Alerts & Sound Effects ────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "تنبيهات وأصوات النظام" : "System Sounds & Alerts"

            SettingsRow {
                title: I18n.isRTL ? "أصوات تنبيهات الإشعارات" : "Notification Alert Sounds"
                subtitle: I18n.isRTL ? "تشغيل نغمة تنبيه صوتية خفيفة عند وصول إشعار جديد" : "Play an acoustic alert sound on incoming notifications"
                icon: "preferences-system-notifications-symbolic"
                showDivider: true
                clickable: true
                onClicked: ConfigManager.setNotificationsSound(!ConfigManager.notificationsSound)

                SettingsToggle {
                    checked: ConfigManager.notificationsSound
                    onToggled: (ch) => ConfigManager.setNotificationsSound(ch)
                }
            }

            SettingsRow {
                title: I18n.isRTL ? "وضع عدم الإزعاج (كتم التنبيهات)" : "Do Not Disturb"
                subtitle: I18n.isRTL ? "كتم كل أصوات التنبيهات واللافتات المنبثقة تلقائياً" : "Silence all notification sounds and banner popups"
                icon: "notifications-disabled-symbolic"
                showDivider: false
                clickable: true
                onClicked: ConfigManager.setNotificationsDnd(!ConfigManager.notificationsDnd)

                SettingsToggle {
                    checked: ConfigManager.notificationsDnd
                    onToggled: (ch) => ConfigManager.setNotificationsDnd(ch)
                }
            }
        }
    }
}
