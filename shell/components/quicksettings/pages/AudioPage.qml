import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Services.Pipewire
import "../../../theme"
import "../../../services"
import "../.."
import ".."

// AudioPage — choose the default output and input device (PipeWire), with the
// matching volume sliders on top so level and device live on one screen.
ColumnLayout {
    id: root

    required property var qs
    spacing: 10

    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true
    function t(ar, en) { return I18n.isRTL ? ar : en; }

    readonly property var allNodes: Pipewire.nodes ? Pipewire.nodes.values : []
    readonly property var outputs: allNodes.filter(n => n && n.audio && n.isSink && !n.isStream)
    readonly property var inputs: allNodes.filter(n => n && n.audio && !n.isSink && !n.isStream
                                                        && !(n.name || "").endsWith(".monitor"))

    function label(n) { return n.description || n.nickname || n.name || "—"; }
    function outputIcon(n) {
        const s = ((n.name || "") + " " + (n.description || "")).toLowerCase();
        if (s.indexOf("headphone") >= 0 || s.indexOf("headset") >= 0 || s.indexOf("bluez") >= 0) return "audio-headphones-symbolic";
        if (s.indexOf("hdmi") >= 0 || s.indexOf("displayport") >= 0) return "video-display-symbolic";
        return IconResolver.directional("audio-speakers-symbolic");
    }

    QSPageHeader {
        title: root.t("الصوت", "Sound")
        subtitle: Pipewire.defaultAudioSink ? root.label(Pipewire.defaultAudioSink) : ""
        onBackClicked: ShellState.quickSettingsCapsuleView = "main"
    }

    Flickable {
        id: flick
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentHeight: col.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {
            policy: flick.contentHeight > flick.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            width: 4
            contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Theme.notchBorderHighlight }
        }

        ColumnLayout {
            id: col
            width: flick.width - (flick.contentHeight > flick.height ? 8 : 0)
            // The scrollbar moves to the left in Arabic: keep the gutter on its side.
            x: (I18n.isRTL && flick.contentHeight > flick.height) ? 8 : 0
            spacing: 2

            component SectionLabel: Text {
                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.bottomMargin: 2
                Layout.leftMargin: 10
                horizontalAlignment: Text.AlignLeft
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(10)
                font.weight: Font.DemiBold
                color: Theme.notchTextTertiary
                renderType: Theme.renderType
            }

            SectionLabel { text: root.t("الإخراج", "Output"); Layout.topMargin: 0 }
            QSSlider {
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                iconName: root.qs.volumeIconName + "-symbolic"
                value: root.qs.currentVolume
                muted: root.qs.isMuted
                onMoved: (v) => root.qs.setVolume(v)
                onIconClicked: root.qs.toggleMute()
            }
            Repeater {
                model: root.outputs
                delegate: QSRow {
                    required property var modelData
                    Layout.fillWidth: true
                    iconName: root.outputIcon(modelData)
                    title: root.label(modelData)
                    selected: Pipewire.defaultAudioSink === modelData
                    onClicked: Pipewire.preferredDefaultAudioSink = modelData
                }
            }

            SectionLabel { text: root.t("الإدخال", "Input"); visible: root.inputs.length > 0 }
            QSSlider {
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                visible: root.qs.audioSource !== null
                iconName: root.qs.micMuted ? IconResolver.directional("microphone-sensitivity-muted-symbolic") : "audio-input-microphone-symbolic"
                value: root.qs.micVolume
                muted: root.qs.micMuted
                onMoved: (v) => root.qs.setMicVolume(v)
                onIconClicked: root.qs.toggleMicMute()
            }
            Repeater {
                model: root.inputs
                delegate: QSRow {
                    required property var modelData
                    Layout.fillWidth: true
                    iconName: "audio-input-microphone-symbolic"
                    title: root.label(modelData)
                    selected: Pipewire.defaultAudioSource === modelData
                    onClicked: Pipewire.preferredDefaultAudioSource = modelData
                }
            }
        }
    }
}
