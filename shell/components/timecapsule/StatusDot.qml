import QtQuick
import "../../theme"

// StatusDot — the ONLY place the dashboard uses semantic colour (6px, per CLAUDE.md).
// level: 0 = nominal (hidden), 1 = warning, 2 = critical.
Rectangle {
    property int level: 0
    implicitWidth: 6
    implicitHeight: 6
    radius: 3
    visible: level > 0
    color: level >= 2 ? Theme.danger : Theme.warning
}
