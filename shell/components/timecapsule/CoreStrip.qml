import QtQuick
import "../../theme"

// CoreStrip — one micro-bar per logical CPU. Height AND luminance encode load,
// so a hot core reads instantly without any colour.
Item {
    id: root

    property var values: []   // 0..100 per core
    property real gap: 3

    implicitHeight: 20
    LayoutMirroring.enabled: false   // data always reads core 0 → N left to right

    readonly property int count: Math.max(1, values.length)
    readonly property real barWidth: (width - gap * (count - 1)) / count

    Row {
        anchors.fill: parent
        spacing: root.gap

        Repeater {
            model: root.values.length

            delegate: Rectangle {
                id: track
                required property int index
                readonly property real load: Math.max(0, Math.min(100, root.values[index] || 0)) / 100

                width: root.barWidth
                height: root.height
                radius: 2
                color: Theme.notchSurface

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.max(2, Math.round(parent.height * track.load))
                    radius: 2
                    color: Theme.notchText
                    opacity: 0.30 + 0.70 * track.load
                    Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 400 } }
                }
            }
        }
    }
}
