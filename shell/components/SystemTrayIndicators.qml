import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Qt5Compat.GraphicalEffects
import "../theme"
import "../services"

Item {
    id: root

    // Determine whether any active, non-passive tray items exist
    readonly property bool hasVisibleItems: {
        const items = SystemTray.items.values;
        if (!items || items.length === 0) return false;
        for (let i = 0; i < items.length; i++) {
            if (items[i] && items[i].status !== Status.Passive) return true;
        }
        return false;
    }

    visible: hasVisibleItems
    implicitWidth: visible ? trayRow.implicitWidth : 0
    implicitHeight: visible ? trayRow.implicitHeight : 0

    RowLayout {
        id: trayRow
        anchors.fill: parent
        spacing: 4

        Repeater {
            id: trayRepeater
            model: SystemTray.items

            delegate: MouseArea {
                id: itemArea
                required property SystemTrayItem modelData
                property alias menuActive: menuLoader.active

                visible: modelData.status !== Status.Passive
                implicitWidth: visible ? 28 : 0
                implicitHeight: visible ? 28 : 0
                Layout.alignment: Qt.AlignVCenter

                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                // Visual hover pill matching QuickSettings capsule buttons
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.notchRadiusPill
                    color: itemArea.containsMouse ? Theme.notchSurfaceHover : "transparent"
                    Behavior on color { ColorAnimation { duration: 80 } }
                }

                // Tray glyph. Most tray icons are single-colour glyphs authored for dark
                // panels (white on transparent) and vanished on the light-mode capsule.
                // Monochrome icons are tinted with the theme foreground; genuinely colourful
                // icons (Discord, Steam, …) keep their colours instead of becoming blobs.
                TrayGlyph {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    source: IconResolver.safeUrl(modelData.icon)
                }

                onPressed: (mouse) => {
                    if (mouse.button === Qt.LeftButton) {
                        if (menuLoader.active) menuLoader.active = false;
                        modelData.activate();
                    } else if (mouse.button === Qt.MiddleButton) {
                        if (menuLoader.active) menuLoader.active = false;
                        modelData.secondaryActivate();
                    } else if (mouse.button === Qt.RightButton) {
                        if (modelData.hasMenu && modelData.menu) {
                            menuLoader.active = !menuLoader.active;
                        } else {
                            modelData.activate();
                        }
                    }
                }

                // Mouse wheel support (e.g. tray icons with volume or scroll actions)
                onWheel: (wheel) => {
                    wheel.accepted = true;
                    if (wheel.angleDelta.y !== 0) {
                        modelData.scroll(wheel.angleDelta.y > 0 ? 1 : -1, false);
                    } else if (wheel.angleDelta.x !== 0) {
                        modelData.scroll(wheel.angleDelta.x > 0 ? 1 : -1, true);
                    }
                }

                Loader {
                    id: menuLoader
                    active: false
                    sourceComponent: TrayContextMenu {
                        menuHandle: modelData.menu
                        trayItemId: modelData.id
                        anchor {
                            window: itemArea.QsWindow.window
                            item: itemArea
                            edges: Edges.Bottom
                            gravity: Edges.Bottom
                            adjustment: PopupAdjustment.Slide | PopupAdjustment.Flip
                        }
                        onMenuClosed: {
                            menuLoader.active = false;
                        }
                    }
                }
            }
        }

        // Subtle vertical divider separating tray apps from system status indicators
        Rectangle {
            visible: root.hasVisibleItems
            implicitWidth: 1
            implicitHeight: 16
            color: Theme.notchTextTertiary
            opacity: 0.35
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: 4
            Layout.rightMargin: 4
        }
    }

    component TrayGlyph: Item {
        id: glyph
        property string source: ""
        // null = not analysed yet (render untinted until known)
        property var monochrome: null

        Image {
            id: raw
            anchors.fill: parent
            sourceSize.width: 48
            sourceSize.height: 48
            fillMode: Image.PreserveAspectFit
            source: glyph.source
            smooth: true
            mipmap: true
            visible: glyph.monochrome !== true
        }

        ColorOverlay {
            anchors.fill: raw
            source: raw
            color: Theme.notchText
            visible: glyph.monochrome === true && raw.status === Image.Ready
        }

        // One-shot colour probe: 16×16 downsample, mean saturation of opaque pixels.
        Canvas {
            id: probe
            width: 16
            height: 16
            opacity: 0                       // must stay "visible" to paint
            renderStrategy: Canvas.Immediate
            property string loaded: ""

            function analyse() {
                if (!glyph.source) return;
                if (probe.loaded && probe.loaded !== glyph.source) probe.unloadImage(probe.loaded);
                probe.loaded = glyph.source;
                if (probe.isImageLoaded(glyph.source)) probe.requestPaint();
                else probe.loadImage(glyph.source);
            }
            onImageLoaded: requestPaint()
            onPaint: {
                if (!probe.loaded || !probe.isImageLoaded(probe.loaded)) return;
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, 16, 16);
                ctx.drawImage(probe.loaded, 0, 0, 16, 16);
                const d = ctx.getImageData(0, 0, 16, 16).data;
                let n = 0, satSum = 0;
                for (let i = 0; i < d.length; i += 4) {
                    if (d[i + 3] < 64) continue;                    // ignore transparent pixels
                    const r = d[i] / 255, g = d[i + 1] / 255, b = d[i + 2] / 255;
                    const mx = Math.max(r, g, b), mn = Math.min(r, g, b);
                    satSum += mx > 0 ? (mx - mn) / mx : 0;
                    n++;
                }
                // Unreadable (e.g. provider refused pixels) → assume monochrome glyph.
                glyph.monochrome = n === 0 ? true : (satSum / n) < 0.18;
            }
        }

        onSourceChanged: { glyph.monochrome = null; probe.analyse(); }
        Component.onCompleted: probe.analyse()
    }
}
