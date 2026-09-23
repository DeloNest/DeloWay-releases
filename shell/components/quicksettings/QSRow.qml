import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services"
import ".."

// QSRow — list row for networks / devices / outputs / power actions.
//   [icon] Title              [trailing] [✓]
//          subtitle
// `selected` = current connection / default device (solid high-contrast chip);
// `busy` = connecting (breathing icon). Expansion content (e.g. password field) can be
// placed in `extra`, which animates open under the row.
Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property string iconName: ""
    property string trailingIcon: ""
    property string trailingText: ""
    property bool selected: false
    property bool busy: false
    property bool danger: false          // destructive action → 6px red dot only
    property alias extra: extraHolder.data
    property bool expanded: false

    signal clicked()

    implicitHeight: 44 + (root.expanded ? extraHolder.childrenRect.height + 8 : 0)
    Behavior on implicitHeight { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
    radius: Theme.notchRadiusCard
    clip: true
    color: root.selected ? Theme.notchSurfaceActive
           : (ma.containsMouse || root.expanded ? Theme.qsTileBackgroundHover : "transparent")
    Behavior on color { ColorAnimation { duration: Theme.motionFast } }

    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    MouseArea {
        id: ma
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 44
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 44
        anchors.leftMargin: 10
        anchors.rightMargin: 12
        spacing: 10

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 28
            implicitHeight: 28
            radius: 14
            color: root.selected ? Theme.qsTileActive : Theme.qsTileIconCircleInactive
            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
            SymbolicIcon {
                anchors.centerIn: parent
                iconSize: 14
                source: root.iconName
                iconColor: root.selected ? Theme.qsTileIconActive : Theme.notchText
                SequentialAnimation on opacity {
                    running: root.busy
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) parent.opacity = 1
                    NumberAnimation { to: 0.25; duration: 500; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutSine }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: -2
            Text {
                Layout.fillWidth: true
                text: NotificationManager.bidi(root.title)
                textFormat: Text.PlainText
                horizontalAlignment: Text.AlignLeft
                elide: Text.ElideRight
                maximumLineCount: 1
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(12)
                font.weight: root.selected ? Font.DemiBold : Font.Normal
                color: Theme.notchText
                renderType: Theme.renderType
            }
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: NotificationManager.bidi(root.subtitle)
                textFormat: Text.PlainText
                horizontalAlignment: Text.AlignLeft
                elide: Text.ElideRight
                maximumLineCount: 1
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(10)
                color: Theme.notchTextTertiary
                renderType: Theme.renderType
            }
        }

        Text {
            visible: text.length > 0
            text: root.trailingText
            font.family: Theme.typography.fontFamily
            font.pixelSize: Theme.fontSize(10)
            color: Theme.notchTextTertiary
            renderType: Theme.renderType
        }
        SymbolicIcon {
            visible: root.trailingIcon.length > 0
            iconSize: 13
            source: root.trailingIcon
            iconColor: Theme.notchTextTertiary
        }
        SymbolicIcon {
            visible: root.selected
            iconSize: 13
            source: "object-select-symbolic"
            iconColor: Theme.notchText
        }
    }

    Item {
        id: extraHolder
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 44
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        opacity: root.expanded ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Theme.motionBase } }
    }
}
