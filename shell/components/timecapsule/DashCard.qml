import QtQuick
import "../../theme"

// DashCard — the single surface primitive of the dashboard (elevation via alpha).
// Sizes itself from its first child's implicit size, so card heights follow the
// real font metrics instead of hard-coded guesses.
Rectangle {
    id: root

    default property alias content: inner.data
    property real padding: 10

    readonly property Item body: inner.children.length > 0 ? inner.children[0] : null
    implicitWidth: (body ? body.implicitWidth : 0) + padding * 2
    implicitHeight: (body ? body.implicitHeight : 0) + padding * 2

    radius: Theme.notchRadiusCard
    color: Theme.notchSurface
    border.color: Theme.notchBorderSubtle
    border.width: 1

    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: root.padding
    }
}
