import QtQuick
import "../../theme"
import ".."

// NotificationIcon — one visual slot for every icon source a notification can carry:
// raw image (avatar/cover via image:// or file path), theme/app icon name, or none
// (neutral bell). Always the same rounded tile, so rows never shift.
Rectangle {
    id: root

    property string source: ""
    property real size: 32

    implicitWidth: size
    implicitHeight: size
    radius: Math.round(size * 0.28)
    color: Theme.notchSurfaceElevated
    border.color: Theme.notchBorderSubtle
    border.width: 1
    clip: true

    readonly property bool isImage: source.startsWith("image://") || source.startsWith("/") || source.startsWith("file://")
    readonly property bool isName: source.length > 0 && !isImage

    Image {
        visible: root.isImage && status === Image.Ready
        anchors.fill: parent
        anchors.margins: 1
        source: root.isImage ? (root.source.startsWith("/") ? "file://" + root.source : root.source) : ""
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
    }

    AppIcon {
        visible: root.isName
        anchors.centerIn: parent
        iconSize: Math.round(root.size * 0.62)
        source: root.isName ? root.source : ""
    }

    SymbolicIcon {
        visible: root.source.length === 0
        anchors.centerIn: parent
        iconSize: Math.round(root.size * 0.5)
        source: "preferences-system-notifications-symbolic"
        iconColor: Theme.notchTextSecondary
    }
}
