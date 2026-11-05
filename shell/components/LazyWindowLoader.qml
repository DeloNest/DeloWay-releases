import QtQuick

Loader {
    id: root
    required property bool shouldOpen
    property int unloadDelay: 350
    property bool keepAlive: shouldOpen

    Timer {
        id: unloadTimer
        interval: root.unloadDelay
        repeat: false
        onTriggered: root.keepAlive = false
    }

    onShouldOpenChanged: {
        if (shouldOpen) {
            unloadTimer.stop();
            keepAlive = true;
        } else {
            unloadTimer.restart();
        }
    }

    active: keepAlive
}
