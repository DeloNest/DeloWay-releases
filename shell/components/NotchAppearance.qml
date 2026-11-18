import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../theme"
import "../services"
import "."

Item {
    id: root

    // Mirrors layout under RTL locales
    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    property string subView: ShellState.appearanceSubView || "wallpapers" // "wallpapers" | "themes"
    readonly property bool isTabActive: ShellState.smartNotchExpanded && ShellState.smartNotchTab === 3

    readonly property real cardBoxWidth: Math.round(240 * Math.max(1.0, (Theme.fontScale - 1.0) * 0.5 + 1.0))
    readonly property real cardBoxHeight: Math.max(150, Math.round(150 * Math.max(1.0, Theme.fontScale)) + (Theme.fontScale > 1.0 ? 8 : 0))
    readonly property real requiredWidth: Math.max(Theme.notchExpandedWidth - 40, subViewRow.implicitWidth + headerThemeLabel.implicitWidth + 64)
    readonly property real requiredHeight: Math.max(268, Math.ceil(6 + headerRow.height + 8 + root.cardBoxHeight + 36 + 8 + footerRow.height + 8))

    property int thumbnailGenVersion: 0
    property real wheelAccumulator: 0

    focus: isTabActive

    onIsTabActiveChanged: {
        if (isTabActive) {
            forceActiveFocus();
            if (subView === "themes") {
                syncThemeSelection();
            } else {
                if (wallpaperListModel.count === 0) {
                    listProc.running = true;
                } else {
                    Qt.callLater(() => {
                        carouselView.positionViewAtIndex(carouselView.currentIndex, ListView.Center);
                    });
                }
            }
        }
    }

    onSubViewChanged: {
        if (subView === "themes") {
            syncThemeSelection();
        } else {
            Qt.callLater(() => {
                if (carouselView.count > 0) {
                    carouselView.positionViewAtIndex(carouselView.currentIndex, ListView.Center);
                }
            });
        }
    }

    Connections {
        target: ShellState
        function onAppearanceSubViewChanged() {
            root.subView = ShellState.appearanceSubView;
        }
        function onAppearanceNextRequested() { root.stepNext(); }
        function onAppearancePrevRequested() { root.stepPrev(); }
        function onAppearanceApplyRequested() { root.applyCurrent(); }
        function onAppearanceToggleViewRequested() { root.toggleSubView(); }
    }

    Connections {
        target: Theme
        function onThemeNameChanged() {
            if (root.subView === "themes") {
                root.syncThemeSelection();
            }
        }
    }

    // ── Key Navigation ────────────────────────────────────────────────────────
    Keys.onTabPressed: toggleSubView()
    Keys.onBacktabPressed: toggleSubView()

    function toggleSubView() {
        if (subView === "wallpapers") {
            subView = "themes";
            ShellState.appearanceSubView = "themes";
        } else {
            subView = "wallpapers";
            ShellState.appearanceSubView = "wallpapers";
        }
    }

    Keys.onLeftPressed: {
        // In RTL, visual left corresponds to next item (higher index)
        if (I18n.isRTL) {
            stepNext();
        } else {
            stepPrev();
        }
    }

    Keys.onRightPressed: {
        // In RTL, visual right corresponds to previous item (lower index)
        if (I18n.isRTL) {
            stepPrev();
        } else {
            stepNext();
        }
    }

    Keys.onReturnPressed: applyCurrent()
    Keys.onEnterPressed: applyCurrent()
    Keys.onEscapePressed: ShellState.closeSmartNotch()

    function stepPrev() {
        if (subView === "themes") {
            if (themesView.count === 0) return;
            if (themesView.currentIndex > 0) {
                themesView.currentIndex--;
                themesView.positionViewAtIndex(themesView.currentIndex, ListView.Center);
            }
        } else {
            if (carouselView.count === 0) return;
            if (carouselView.currentIndex > 0) {
                carouselView.currentIndex--;
                carouselView.positionViewAtIndex(carouselView.currentIndex, ListView.Center);
            }
        }
    }

    function stepNext() {
        if (subView === "themes") {
            if (themesView.count === 0) return;
            if (themesView.currentIndex < themesView.count - 1) {
                themesView.currentIndex++;
                themesView.positionViewAtIndex(themesView.currentIndex, ListView.Center);
            }
        } else {
            if (carouselView.count === 0) return;
            if (carouselView.currentIndex < carouselView.count - 1) {
                carouselView.currentIndex++;
                carouselView.positionViewAtIndex(carouselView.currentIndex, ListView.Center);
            }
        }
    }

    function applyCurrent() {
        if (subView === "themes") {
            applyCurrentTheme();
        } else {
            applyCurrentWallpaper();
        }
    }

    function applyCurrentTheme() {
        if (themesView.currentIndex >= 0 && themesView.currentIndex < themesView.count) {
            var themeId = themesView.model[themesView.currentIndex];
            if (themeId) {
                applyTheme(themeId);
            }
        }
    }

    function applyTheme(name) {
        if (!name) return;
        ConfigManager.setTheme(name);
    }

    function syncThemeSelection() {
        const cur = Theme.themeName;
        const idx = ["dark", "glass", "light"].indexOf(cur);
        if (idx >= 0 && themesView) {
            themesView.currentIndex = idx;
            Qt.callLater(() => {
                if (themesView) {
                    themesView.positionViewAtIndex(idx, ListView.Center);
                }
            });
        }
    }

    function applyCurrentWallpaper() {
        if (carouselView.currentIndex >= 0 && carouselView.currentIndex < wallpaperListModel.count) {
            var item = wallpaperListModel.get(carouselView.currentIndex);
            if (item && item.path) {
                applyWallpaper(item.path);
            }
        }
    }

    function applyWallpaper(path) {
        if (!path) return;
        ConfigManager.setWallpaper(path);
    }

    ListModel {
        id: wallpaperListModel
    }

    // ── Process: Fetch Wallpapers & Thumbnails ────────────────────────────────
    Process {
        id: listProc
        command: [
            "setpriv", "--pdeathsig", "TERM",
            "python3", ConfigManager.projectDir + "/scripts/deloway-wallpaper-cache.py",
            "--list"
        ]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var parsed = JSON.parse(data.trim());
                    if (Array.isArray(parsed) && parsed.length > 0) {
                        root.populateWallpapers(parsed);
                    }
                } catch (e) {
                    console.warn("Failed to parse wallpaper list JSON:", e);
                }
            }
        }
    }

    // ── Process: Batch Thumbnail Generation ───────────────────────────────────
    Process {
        id: batchThumbProc
        onExited: {
            root.thumbnailGenVersion++;
        }
    }

    function populateWallpapers(items) {
        wallpaperListModel.clear();
        var missingThumbPaths = [];
        var activeIndex = 0;
        var currentWp = ConfigManager.wallpaper;

        for (var i = 0; i < items.length; ++i) {
            var it = items[i];
            wallpaperListModel.append({
                "name": it.name || "",
                "name_ar": it.name_ar || "",
                "path": it.path || "",
                "category": it.category || "",
                "filename": it.filename || "",
                "thumb": it.thumb || "",
                "thumbExists": !!it.thumbExists
            });
            if (!it.thumbExists && it.path) {
                missingThumbPaths.push(it.path);
            }
            if (currentWp && (currentWp === it.path || currentWp === ConfigManager.fileUrl(it.path))) {
                activeIndex = i;
            }
        }

        carouselView.currentIndex = activeIndex;
        Qt.callLater(() => {
            carouselView.positionViewAtIndex(activeIndex, ListView.Center);
        });

        // Lazily generate missing thumbnails in background
        if (missingThumbPaths.length > 0) {
            var cmd = [
                "setpriv", "--pdeathsig", "TERM",
                "python3", ConfigManager.projectDir + "/scripts/deloway-wallpaper-cache.py",
                "--batch"
            ];
            for (var j = 0; j < missingThumbPaths.length; ++j) {
                cmd.push(missingThumbPaths[j]);
            }
            batchThumbProc.command = cmd;
            batchThumbProc.running = true;
        }
    }

    // ── HEADER ROW ───────────────────────────────────────────────────────────
    Item {
        id: headerRow
        anchors.top: parent.top
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.right: parent.right
        anchors.rightMargin: 20
        height: Math.max(26, Math.max(subViewRow.implicitHeight, headerThemeLabel.implicitHeight) + 4)

        // Start side: Subview toggle ("Wallpapers | Themes")
        Row {
            id: subViewRow
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                text: I18n.tr("wallpapers_title")
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(12)
                font.weight: root.subView === "wallpapers" ? Font.DemiBold : Font.Normal
                color: root.subView === "wallpapers"
                       ? Theme.notchText
                       : (wallpapersMa.containsMouse ? Theme.notchTextSecondary : Theme.notchTextTertiary)
                Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                MouseArea {
                    id: wallpapersMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.subView = "wallpapers";
                        ShellState.appearanceSubView = "wallpapers";
                    }
                }
            }

            Text {
                text: "|"
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(12)
                font.weight: Font.Normal
                color: Theme.notchBorder
            }

            Text {
                text: I18n.tr("themes_title")
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(12)
                font.weight: root.subView === "themes" ? Font.DemiBold : Font.Normal
                color: root.subView === "themes"
                       ? Theme.notchText
                       : (themesMa.containsMouse ? Theme.notchTextSecondary : Theme.notchTextTertiary)
                Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                MouseArea {
                    id: themesMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.subView = "themes";
                        ShellState.appearanceSubView = "themes";
                    }
                }
            }
        }

        // End side: Active mode / theme name (muted)
        Text {
            id: headerThemeLabel
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: Theme.themeName === "glass"
                  ? I18n.tr("theme_glass")
                  : (Theme.isDark ? I18n.tr("theme_dark") : I18n.tr("theme_light"))
            font.family: Theme.typography.fontFamily
            font.pixelSize: Theme.fontSize(11)
            font.weight: Font.Normal
            color: Theme.notchTextTertiary
        }
    }

    // ── CENTER AREA: CAROUSEL OR THEMES STUB ──────────────────────────────────
    Item {
        id: centerArea
        anchors.top: headerRow.bottom
        anchors.topMargin: 8
        anchors.bottom: footerRow.top
        anchors.bottomMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        clip: true

        // ── Themes Carousel View ─────────────────────────────────────────────
        Item {
            id: themesContainer
            anchors.fill: parent
            visible: root.subView === "themes"
            clip: true

            ListView {
                id: themesView
                anchors.fill: parent
                orientation: ListView.Horizontal
                snapMode: ListView.SnapToItem
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: Math.round((width - root.cardBoxWidth) / 2)
                preferredHighlightEnd: Math.round((width + root.cardBoxWidth) / 2)
                highlightMoveDuration: 180
                spacing: 14
                clip: true
                model: ["dark", "glass", "light"]
                keyNavigationEnabled: false
                reuseItems: false
                displayMarginBeginning: 250
                displayMarginEnd: 250

                header: Item {
                    width: Math.max(0, Math.round((themesView.width - root.cardBoxWidth) / 2))
                    height: themesView.height
                }

                footer: Item {
                    width: Math.max(0, Math.round((themesView.width - root.cardBoxWidth) / 2))
                    height: themesView.height
                }

                delegate: Item {
                    id: themeDelegate
                    width: root.cardBoxWidth
                    height: themesView.height

                    readonly property string themeId: modelData
                    readonly property string themeTitle: {
                        if (themeId === "dark") return I18n.tr("theme_dark");
                        if (themeId === "glass") return I18n.tr("theme_glass");
                        if (themeId === "light") return I18n.tr("theme_light");
                        return "";
                    }
                    readonly property string themeSubtitle: {
                        if (themeId === "dark") return I18n.tr("theme_dark_desc");
                        if (themeId === "glass") return I18n.tr("theme_glass_desc");
                        if (themeId === "light") return I18n.tr("theme_light_desc");
                        return "";
                    }

                    readonly property bool isSelected: ListView.isCurrentItem
                    readonly property bool isApplied: Theme.themeName === themeId

                    Rectangle {
                        id: themeCardBox
                        anchors.centerIn: parent
                        width: root.cardBoxWidth
                        height: root.cardBoxHeight
                        radius: Theme.notchRadiusCard
                        color: "transparent"
                        scale: themeDelegate.isSelected ? 1.0 : (themeCardMa.containsMouse ? 0.94 : 0.92)
                        opacity: themeDelegate.isSelected ? 1.0 : (themeCardMa.containsMouse ? 0.88 : 0.70)
                        border.width: themeDelegate.isSelected ? 2 : 1
                        border.color: themeDelegate.isSelected
                                      ? Theme.cardBorderSelected
                                      : (themeCardMa.containsMouse ? Theme.cardBorderHover : Theme.cardBorderUnselected)

                        Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic } }
                        Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                        // ── Inset Theme Preview Container ──
                        Rectangle {
                            id: innerThemePreview
                            anchors.fill: parent
                            anchors.margins: 3
                            radius: Math.max(0, Theme.notchRadiusCard - 3)
                            color: Theme.notchSurface
                            clip: true

                            // 1. Theme Canvas Base
                            Rectangle {
                                anchors.fill: parent
                                color: {
                                    if (themeDelegate.themeId === "light") return Theme.themeLightBackground;
                                    if (themeDelegate.themeId === "glass") return Theme.themeGlassBackground;
                                    return Theme.themeDarkBackground;
                                }
                            }

                            // 2. Neutral backing sample (visible through glass transparency)
                            Item {
                                anchors.fill: parent
                                visible: themeDelegate.themeId === "glass"

                                Rectangle {
                                    x: 18
                                    y: 16
                                    width: 130
                                    height: 48
                                    radius: Theme.notchRadiusPill
                                    color: Theme.notchBorderHighlight
                                    opacity: 0.22
                                }
                                Rectangle {
                                    x: 85
                                    y: 52
                                    width: 135
                                    height: 52
                                    radius: Theme.notchRadiusPill
                                    color: Theme.notchTextTertiary
                                    opacity: 0.16
                                }
                            }

                            // 3. Mini UI Surface (Card) demonstrating the theme's material
                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.min(innerThemePreview.width - 16, Math.max(176, miniCardCol.implicitWidth + 32))
                                height: Math.min(innerThemePreview.height - 16, Math.max(74, miniCardCol.implicitHeight + 22))
                                radius: Theme.notchRadiusCard
                                color: {
                                    if (themeDelegate.themeId === "light") return Theme.themeLightSurface;
                                    if (themeDelegate.themeId === "glass") return Theme.themeGlassSurface;
                                    return Theme.themeDarkSurface;
                                }
                                border.width: 1
                                border.color: {
                                    if (themeDelegate.themeId === "light") return Theme.themeLightBorder;
                                    if (themeDelegate.themeId === "glass") return Theme.themeGlassBorder;
                                    return Theme.themeDarkBorder;
                                }

                                ColumnLayout {
                                    id: miniCardCol
                                    anchors.centerIn: parent
                                    spacing: 4

                                    RowLayout {
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 6

                                        Rectangle {
                                            width: 6
                                            height: 6
                                            radius: 3
                                            color: {
                                                if (themeDelegate.themeId === "light") return Theme.themeLightTextSecondary;
                                                return Theme.themeDarkTextSecondary;
                                            }
                                        }

                                        Rectangle {
                                            width: 30
                                            height: 4
                                            radius: 2
                                            color: {
                                                if (themeDelegate.themeId === "light") return Theme.themeLightTextSecondary;
                                                return Theme.themeDarkTextSecondary;
                                            }
                                            opacity: 0.5
                                        }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: themeDelegate.themeTitle
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(13)
                                        font.weight: Font.DemiBold
                                        color: {
                                            if (themeDelegate.themeId === "light") return Theme.themeLightText;
                                            return Theme.themeDarkText;
                                        }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: themeDelegate.themeSubtitle
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(10)
                                        font.weight: Font.Normal
                                        color: {
                                            if (themeDelegate.themeId === "light") return Theme.themeLightTextSecondary;
                                            return Theme.themeDarkTextSecondary;
                                        }
                                    }
                                }
                            }
                        }

                        // Top-corner checkmark badge for currently applied theme
                        Rectangle {
                            visible: themeDelegate.isApplied
                            width: 22
                            height: 22
                            radius: 11
                            color: Theme.inverseSurface
                            border.width: 1.5
                            border.color: Theme.notchBackground
                            anchors.top: parent.top
                            anchors.topMargin: 8
                            x: I18n.isRTL ? 8 : (parent.width - width - 8)
                            z: 10

                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: Font.Bold
                                color: Theme.inverseText
                            }
                        }

                        MouseArea {
                            id: themeCardMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                themesView.currentIndex = index;
                                themesView.positionViewAtIndex(index, ListView.Center);
                                root.applyTheme(themeDelegate.themeId);
                            }
                        }
                    }
                }
            }

            WheelHandler {
                target: null
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (event) => {
                    if (root.subView !== "themes") return;
                    var delta = (Math.abs(event.angleDelta.y) >= Math.abs(event.angleDelta.x))
                                ? event.angleDelta.y : event.angleDelta.x;
                    root.wheelAccumulator += delta;
                    if (Math.abs(root.wheelAccumulator) >= 100) {
                        if (root.wheelAccumulator < 0) {
                            root.stepNext();
                        } else {
                            root.stepPrev();
                        }
                        root.wheelAccumulator = 0;
                    }
                    event.accepted = true;
                }
            }
        }

        // ── Wallpapers Carousel View ─────────────────────────────────────────
        Item {
            id: carouselContainer
            anchors.fill: parent
            visible: root.subView === "wallpapers"
            clip: true

            ListView {
                id: carouselView
                anchors.fill: parent
                orientation: ListView.Horizontal
                snapMode: ListView.SnapToItem
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: Math.round((width - root.cardBoxWidth) / 2)
                preferredHighlightEnd: Math.round((width + root.cardBoxWidth) / 2)
                highlightMoveDuration: 180
                spacing: 14
                clip: true
                model: wallpaperListModel
                keyNavigationEnabled: false
                reuseItems: false
                displayMarginBeginning: 250
                displayMarginEnd: 250

                header: Item {
                    width: Math.max(0, Math.round((carouselView.width - root.cardBoxWidth) / 2))
                    height: carouselView.height
                }

                footer: Item {
                    width: Math.max(0, Math.round((carouselView.width - root.cardBoxWidth) / 2))
                    height: carouselView.height
                }

                delegate: Item {
                    id: cardDelegate
                    width: root.cardBoxWidth
                    height: carouselView.height

                    readonly property string itemPath: model.path
                    readonly property string itemFilename: model.filename
                    readonly property string itemThumb: model.thumb
                    readonly property bool itemThumbExists: model.thumbExists

                    readonly property bool isSelected: ListView.isCurrentItem
                    readonly property bool isApplied: {
                        var cur = ConfigManager.wallpaper;
                        return !!cur && (cur === itemPath || cur === ConfigManager.fileUrl(itemPath));
                    }

                    Rectangle {
                        id: cardBox
                        anchors.centerIn: parent
                        width: root.cardBoxWidth
                        height: root.cardBoxHeight
                        radius: Theme.notchRadiusCard
                        color: "transparent"
                        scale: cardDelegate.isSelected ? 1.0 : (cardMa.containsMouse ? 0.94 : 0.92)
                        opacity: cardDelegate.isSelected ? 1.0 : (cardMa.containsMouse ? 0.88 : 0.70)
                        border.width: cardDelegate.isSelected ? 2 : 1
                        border.color: cardDelegate.isSelected
                                      ? Theme.cardBorderSelected
                                      : (cardMa.containsMouse ? Theme.cardBorderHover : Theme.cardBorderUnselected)

                        Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic } }
                        Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                        // ── Inset Wallpaper Preview Container ──
                        Rectangle {
                            id: innerWpPreview
                            anchors.fill: parent
                            anchors.margins: 3
                            radius: Math.max(0, Theme.notchRadiusCard - 3)
                            color: Theme.notchSurface
                            clip: true

                            Image {
                                id: thumbImg
                                anchors.fill: parent
                                source: (cardDelegate.itemThumb && (cardDelegate.itemThumbExists || root.thumbnailGenVersion > 0))
                                        ? ConfigManager.fileUrl(cardDelegate.itemThumb) : ""
                                asynchronous: true
                                cache: true
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                                visible: status === Image.Ready
                            }

                            // Subtle placeholder while thumbnail is being generated or decoded
                            Rectangle {
                                anchors.fill: parent
                                color: Theme.notchSurfaceElevated
                                visible: thumbImg.status !== Image.Ready
                            }
                        }

                        // Top-corner checkmark badge for currently applied wallpaper
                        Rectangle {
                            visible: cardDelegate.isApplied
                            width: 22
                            height: 22
                            radius: 11
                            color: Theme.inverseSurface
                            border.width: 1.5
                            border.color: Theme.notchBackground
                            anchors.top: parent.top
                            anchors.topMargin: 8
                            x: I18n.isRTL ? 8 : (parent.width - width - 8)
                            z: 10

                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: Font.Bold
                                color: Theme.inverseText
                            }
                        }

                        MouseArea {
                            id: cardMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                carouselView.currentIndex = index;
                                carouselView.positionViewAtIndex(index, ListView.Center);
                                root.applyWallpaper(cardDelegate.itemPath);
                            }
                        }
                    }
                }
            }

            // Mouse wheel scrolls carousel items smoothly
            WheelHandler {
                target: null
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (event) => {
                    if (root.subView !== "wallpapers") return;
                    var delta = (Math.abs(event.angleDelta.y) >= Math.abs(event.angleDelta.x))
                                ? event.angleDelta.y : event.angleDelta.x;
                    root.wheelAccumulator += delta;
                    if (Math.abs(root.wheelAccumulator) >= 100) {
                        if (root.wheelAccumulator < 0) {
                            root.stepNext();
                        } else {
                            root.stepPrev();
                        }
                        root.wheelAccumulator = 0;
                    }
                    event.accepted = true;
                }
            }
        }
    }

    // ── FOOTER ROW ───────────────────────────────────────────────────────────
    RowLayout {
        id: footerRow
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.right: parent.right
        anchors.rightMargin: 20
        height: Math.max(24, Math.max(footerTitleText.implicitHeight, footerHintText.implicitHeight) + 4)
        spacing: 12

        // Start edge: Name/title of selected item (muted)
        Text {
            id: footerTitleText
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            horizontalAlignment: Text.AlignLeft
            text: {
                if (root.subView === "themes") {
                    if (themesView.currentIndex >= 0 && themesView.currentIndex < themesView.count) {
                        var tid = themesView.model[themesView.currentIndex];
                        if (tid === "dark") return I18n.tr("theme_dark");
                        if (tid === "glass") return I18n.tr("theme_glass");
                        if (tid === "light") return I18n.tr("theme_light");
                    }
                    return "";
                }
                if (carouselView.currentIndex >= 0 && carouselView.currentIndex < wallpaperListModel.count) {
                    var it = wallpaperListModel.get(carouselView.currentIndex);
                    if (!it) return "";
                    return (I18n.isRTL && it.name_ar) ? it.name_ar : (it.name || it.filename);
                }
                return "";
            }
            color: Theme.notchTextTertiary
            font.family: Theme.typography.fontFamily
            font.pixelSize: Theme.fontSize(12)
            font.weight: Font.Normal
            elide: Text.ElideMiddle
            maximumLineCount: 1
        }

        // End edge: "n/total · Enter to apply" (muted)
        Text {
            id: footerHintText
            Layout.alignment: Qt.AlignVCenter
            text: {
                var count = root.subView === "themes" ? themesView.count : wallpaperListModel.count;
                var current = root.subView === "themes"
                    ? (count > 0 ? (themesView.currentIndex + 1) : 0)
                    : (count > 0 ? (carouselView.currentIndex + 1) : 0);
                return current + "/" + count + " · " + I18n.tr("enter_to_apply");
            }
            color: Theme.notchTextTertiary
            font.family: Theme.typography.fontFamily
            font.pixelSize: Theme.fontSize(12)
            font.weight: Font.Normal
        }
    }
}
