import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../services"

PanelWindow {
    id: root

    required property ShellScreen targetScreen
    screen: targetScreen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    WlrLayershell.namespace: "deloway:app-store"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: ShellState.appStoreOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    visible: ShellState.appStoreOpen || storeCard.opacity > 0.01

    // Dismiss on clicking backdrop
    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.closeAppStore()
    }

    Rectangle {
        id: storeCard
        anchors.centerIn: parent
        width: Math.min(1020, parent.width - 48)
        height: Math.min(680, parent.height - 80)
        radius: Theme.radius.xlarge
        color: Theme.colors.surface
        border.color: Theme.colors.border
        border.width: 1

        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        opacity: ShellState.appStoreOpen ? 1.0 : 0.0
        transform: Scale {
            origin.x: storeCard.width / 2
            origin.y: storeCard.height / 2
            xScale: ShellState.appStoreOpen ? 1.0 : 0.94
            yScale: ShellState.appStoreOpen ? 1.0 : 0.94
            Behavior on xScale { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingExit } }
            Behavior on yScale { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingExit } }
        }
        Behavior on opacity { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingExit } }

        // Block click-through to backdrop
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        // Active navigation state
        property string activeNav: ShellState.storeCategory || "featured"
        property string searchText: ShellState.storeSearchQuery || ""
        property var selectedApp: ShellState.selectedStoreApp

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ----------------------------------------------------
            // 1. TOP HEADER BAR
            // ----------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                color: Theme.colors.surfaceVariant
                border.color: Theme.colors.border
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 16
                    spacing: 16

                    // App Store Title & Branding
                    RowLayout {
                        spacing: 10
                        AppIcon {
                            source: "software-store"
                            iconSize: 28
                        }
                        ColumnLayout {
                            spacing: 1
                            Text {
                                text: "Delo Store"
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                color: Theme.colors.text
                            }
                            Text {
                                text: "Discover & manage software"
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: 11
                                color: Theme.colors.textSecondary
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Search Bar
                    DeloTextField {
                        id: searchField
                        Layout.preferredWidth: 320
                        Layout.preferredHeight: 36
                        showSearchIcon: true
                        placeholderText: "Search apps, packages, tools..."
                        text: storeCard.searchText
                        onTextEdited: {
                            storeCard.searchText = text;
                            ShellState.storeSearchQuery = text;
                            if (storeCard.selectedApp) storeCard.selectedApp = null;
                        }
                    }

                    // Window Close Button
                    DeloButton {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        variant: "ghost"
                        text: "✕"
                        onClicked: ShellState.closeAppStore()
                    }
                }
            }

            // ----------------------------------------------------
            // 2. MAIN BODY (SIDEBAR + CONTENT)
            // ----------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // 2A. LEFT SIDEBAR
                Rectangle {
                    Layout.preferredWidth: 200
                    Layout.fillHeight: true
                    color: Theme.colors.surfaceVariant
                    border.color: Theme.colors.border
                    border.width: 1

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 10
                        clip: true

                        ColumnLayout {
                            width: parent.width
                            spacing: 4

                            // Navigation Items List
                            Repeater {
                                model: [
                                    { "id": "featured", "name": "Featured", "icon": "software-store" },
                                    { "id": "all", "name": "All Apps", "icon": "apps" },
                                    { "id": "development", "name": "Development", "icon": "development" },
                                    { "id": "internet", "name": "Internet", "icon": "internet" },
                                    { "id": "multimedia", "name": "Multimedia", "icon": "multimedia" },
                                    { "id": "graphics", "name": "Graphics", "icon": "graphics" },
                                    { "id": "office", "name": "Productivity", "icon": "office" },
                                    { "id": "system", "name": "System", "icon": "system" }
                                ]

                                delegate: Rectangle {
                                    id: navItem
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    radius: Theme.radius.medium
                                    color: (storeCard.activeNav === modelData.id && !storeCard.selectedApp)
                                           ? Theme.colors.surface
                                           : (navMouse.containsMouse ? Theme.colors.surfaceVariant : "transparent")

                                    border.color: (storeCard.activeNav === modelData.id && !storeCard.selectedApp)
                                                  ? Theme.colors.border
                                                  : "transparent"
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 10

                                        SymbolicIcon {
                                            source: modelData.icon
                                            iconSize: 16
                                            iconColor: (storeCard.activeNav === modelData.id && !storeCard.selectedApp)
                                                       ? Theme.colors.primary
                                                       : Theme.colors.textSecondary
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: 13
                                            font.bold: storeCard.activeNav === modelData.id && !storeCard.selectedApp
                                            color: (storeCard.activeNav === modelData.id && !storeCard.selectedApp)
                                                   ? Theme.colors.text
                                                   : Theme.colors.textSecondary
                                        }
                                    }

                                    MouseArea {
                                        id: navMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            storeCard.activeNav = modelData.id;
                                            storeCard.selectedApp = null;
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                Layout.topMargin: 8
                                Layout.bottomMargin: 8
                                color: Theme.colors.borderSubtle
                            }

                            // Installed Apps Nav
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                radius: Theme.radius.medium
                                color: (storeCard.activeNav === "installed" && !storeCard.selectedApp)
                                       ? Theme.colors.surface
                                       : (instMouse.containsMouse ? Theme.colors.surfaceVariant : "transparent")
                                border.color: (storeCard.activeNav === "installed" && !storeCard.selectedApp) ? Theme.colors.border : "transparent"
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    SymbolicIcon {
                                        source: "user-home-symbolic"
                                        iconSize: 15
                                        iconColor: (storeCard.activeNav === "installed") ? Theme.colors.primary : Theme.colors.textSecondary
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: "Installed"
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 13
                                        color: (storeCard.activeNav === "installed") ? Theme.colors.text : Theme.colors.textSecondary
                                    }

                                    Rectangle {
                                        Layout.preferredHeight: 18
                                        Layout.preferredWidth: Math.max(22, instCountTxt.implicitWidth + 8)
                                        radius: 9
                                        color: Theme.colors.surfaceVariant
                                        border.color: Theme.colors.borderSubtle
                                        border.width: 1

                                        Text {
                                            id: instCountTxt
                                            anchors.centerIn: parent
                                            text: PackageManager.installedApps.length
                                            font.pixelSize: Theme.typography.scaleCaption.size
                                            font.weight: Font.DemiBold
                                            color: Theme.colors.textSecondary
                                        }
                                    }
                                }

                                MouseArea {
                                    id: instMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        storeCard.activeNav = "installed";
                                        storeCard.selectedApp = null;
                                    }
                                }
                            }

                            // Updates Nav
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                radius: Theme.radius.medium
                                color: (storeCard.activeNav === "updates" && !storeCard.selectedApp)
                                       ? Theme.colors.surface
                                       : (updMouse.containsMouse ? Theme.colors.surfaceVariant : "transparent")
                                border.color: (storeCard.activeNav === "updates" && !storeCard.selectedApp) ? Theme.colors.border : "transparent"
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    SymbolicIcon {
                                        source: "system-reboot-symbolic"
                                        iconSize: 15
                                        iconColor: (storeCard.activeNav === "updates") ? Theme.colors.primary : Theme.colors.textSecondary
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: "Updates"
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 13
                                        color: (storeCard.activeNav === "updates") ? Theme.colors.text : Theme.colors.textSecondary
                                    }

                                    Rectangle {
                                        visible: PackageManager.updatableApps.length > 0
                                        Layout.preferredHeight: 18
                                        Layout.preferredWidth: 22
                                        radius: 9
                                        color: Theme.colors.primary

                                        Text {
                                            anchors.centerIn: parent
                                            text: PackageManager.updatableApps.length
                                            font.pixelSize: Theme.typography.scaleCaption.size
                                            font.weight: Font.DemiBold
                                            color: Theme.textOnPrimary
                                        }
                                    }
                                }

                                MouseArea {
                                    id: updMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        storeCard.activeNav = "updates";
                                        storeCard.selectedApp = null;
                                    }
                                }
                            }
                        }
                    }
                }

                // 2B. RIGHT CONTENT AREA
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.colors.surface

                    // VIEW 1: APP DETAILS VIEW
                    ScrollView {
                        id: detailsScrollView
                        anchors.fill: parent
                        anchors.margins: 24
                        clip: true
                        contentWidth: availableWidth
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        visible: storeCard.selectedApp !== null

                        ColumnLayout {
                            width: detailsScrollView.availableWidth
                            spacing: 20

                            // Back Navigation Button
                            DeloButton {
                                Layout.preferredHeight: 32
                                variant: "secondary"
                                iconSource: "go-previous-symbolic"
                                text: "Back to Catalog"
                                onClicked: storeCard.selectedApp = null
                            }

                            // App Hero Header
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 20

                                Rectangle {
                                    Layout.preferredWidth: 72
                                    Layout.preferredHeight: 72
                                    radius: Theme.radius.large
                                    color: Theme.colors.surfaceVariant
                                    border.color: Theme.colors.border
                                    border.width: 1

                                    AppIcon {
                                        anchors.centerIn: parent
                                        source: storeCard.selectedApp ? storeCard.selectedApp.icon : ""
                                        iconSize: 56
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Text {
                                        text: storeCard.selectedApp ? storeCard.selectedApp.name : ""
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 22
                                        font.weight: Font.DemiBold
                                        color: Theme.colors.text
                                    }

                                    RowLayout {
                                        spacing: 8
                                        Text {
                                            text: storeCard.selectedApp ? storeCard.selectedApp.developer : ""
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: 13
                                            color: Theme.colors.textSecondary
                                        }
                                        Text { text: "•"; color: Theme.colors.textSecondary }
                                        Text {
                                            text: storeCard.selectedApp ? storeCard.selectedApp.category : ""
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: Theme.typography.scaleCaption.size
                                            color: Theme.colors.primary
                                            font.weight: Font.DemiBold
                                        }
                                        Text { text: "•"; color: Theme.colors.textSecondary }
                                        Text {
                                            text: "★ " + (storeCard.selectedApp ? storeCard.selectedApp.rating : "5.0")
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: Theme.typography.scaleCaption.size
                                            color: Theme.colors.warning
                                            font.weight: Font.DemiBold
                                        }
                                    }

                                    Text {
                                        text: storeCard.selectedApp ? storeCard.selectedApp.summary : ""
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 13
                                        color: Theme.colors.textSecondary
                                        Layout.topMargin: 2
                                    }
                                }

                                // Actions Column
                                ColumnLayout {
                                    spacing: 8

                                    // Install / Launch Button
                                    DeloButton {
                                        Layout.preferredWidth: 140
                                        Layout.preferredHeight: 38
                                        variant: {
                                            if (!storeCard.selectedApp) return "primary";
                                            if (PackageManager.isInstalled(storeCard.selectedApp.id)) return "secondary";
                                            return "primary";
                                        }
                                        text: {
                                            if (!storeCard.selectedApp) return "";
                                            if (PackageManager.isInstalling(storeCard.selectedApp.id)) {
                                                const pct = Math.round(PackageManager.getInstallProgress(storeCard.selectedApp.id) * 100);
                                                return "Installing (" + pct + "%)";
                                            }
                                            if (PackageManager.isInstalled(storeCard.selectedApp.id)) return "Launch App";
                                            return "Install";
                                        }
                                        onClicked: {
                                            if (!storeCard.selectedApp) return;
                                            if (PackageManager.isInstalled(storeCard.selectedApp.id)) {
                                                ApplicationManager.activateOrLaunch({ id: storeCard.selectedApp.id, exec: storeCard.selectedApp.id });
                                                ShellState.closeAppStore();
                                            } else {
                                                PackageManager.installApp(storeCard.selectedApp.id);
                                            }
                                        }
                                    }

                                    // Pin / Unpin Button
                                    DeloButton {
                                        visible: storeCard.selectedApp && PackageManager.isInstalled(storeCard.selectedApp.id)
                                        Layout.preferredWidth: 140
                                        Layout.preferredHeight: 32
                                        variant: "secondary"
                                        text: (storeCard.selectedApp && ApplicationManager.isPinned(storeCard.selectedApp.id)) ? "Unpin from Dock" : "Pin to Dock"
                                        onClicked: {
                                            if (storeCard.selectedApp) ApplicationManager.togglePin(storeCard.selectedApp.id);
                                        }
                                    }

                                    // Uninstall Button
                                    DeloButton {
                                        visible: storeCard.selectedApp && PackageManager.isInstalled(storeCard.selectedApp.id)
                                        Layout.preferredWidth: 140
                                        Layout.preferredHeight: 32
                                        variant: "danger"
                                        text: "Uninstall"
                                        onClicked: {
                                            if (storeCard.selectedApp) PackageManager.uninstallApp(storeCard.selectedApp.id);
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: Theme.colors.borderSubtle
                            }

                            // Description Section
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: "About this application"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                    color: Theme.colors.text
                                }

                                Text {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    text: storeCard.selectedApp ? storeCard.selectedApp.description : ""
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 13
                                    lineHeight: 1.4
                                    color: Theme.colors.textSecondary
                                }
                            }

                            // Specifications Card
                            DeloCard {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 100
                                cardRadius: Theme.radiusMedium
                                surfaceColor: Theme.colors.surfaceVariant
                                borderColor: Theme.colors.borderSubtle
                                borderWidth: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 16

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Version"; font.pixelSize: 11; color: Theme.colors.textSecondary }
                                        Text { text: storeCard.selectedApp ? storeCard.selectedApp.version : ""; font.weight: Font.DemiBold; color: Theme.colors.text }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Download Size"; font.pixelSize: 11; color: Theme.colors.textSecondary }
                                        Text { text: storeCard.selectedApp ? storeCard.selectedApp.size : ""; font.weight: Font.DemiBold; color: Theme.colors.text }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Text { text: "License"; font.pixelSize: 11; color: Theme.colors.textSecondary }
                                        Text { text: storeCard.selectedApp ? storeCard.selectedApp.license : ""; font.weight: Font.DemiBold; color: Theme.colors.text }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Package Format"; font.pixelSize: 11; color: Theme.colors.textSecondary }
                                        Text { text: "Native / Flatpak"; font.weight: Font.DemiBold; color: Theme.colors.text }
                                    }
                                }
                            }
                        }
                    }

                    // VIEW 2: CATALOG / SEARCH LIST
                    ScrollView {
                        id: catalogScrollView
                        anchors.fill: parent
                        anchors.margins: 24
                        clip: true
                        contentWidth: availableWidth
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        visible: storeCard.selectedApp === null

                        ColumnLayout {
                            width: catalogScrollView.availableWidth
                            spacing: 16

                            // Category Header
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: {
                                        if (storeCard.searchText.length > 0) return "Search Results for \"" + storeCard.searchText + "\"";
                                        if (storeCard.activeNav === "featured") return "Featured & Spotlight";
                                        if (storeCard.activeNav === "installed") return "Installed Applications";
                                        if (storeCard.activeNav === "updates") return "Software Updates";
                                        return storeCard.activeNav.charAt(0).toUpperCase() + storeCard.activeNav.slice(1) + " Applications";
                                    }
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 18
                                    font.weight: Font.DemiBold
                                    color: Theme.colors.text
                                }
                                Item { Layout.fillWidth: true }

                                // Update All button if on updates tab
                                DeloButton {
                                    visible: storeCard.activeNav === "updates" && PackageManager.updatableApps.length > 0
                                    Layout.preferredHeight: 30
                                    variant: "primary"
                                    text: "Update All"
                                    onClicked: PackageManager.updateAll()
                                }
                            }

                            // Spotlight Hero Banner (Only shown on Featured tab without search)
                            Rectangle {
                                visible: storeCard.activeNav === "featured" && storeCard.searchText.length === 0
                                Layout.fillWidth: true
                                Layout.preferredHeight: 150
                                radius: Theme.radius.large
                                color: Theme.colors.surfaceVariant
                                border.color: Theme.colors.border
                                border.width: 1
                                clip: true



                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 20
                                    spacing: 16

                                    AppIcon {
                                        source: "blender"
                                        iconSize: 64
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Rectangle {
                                            Layout.preferredHeight: 20
                                            Layout.preferredWidth: 90
                                            radius: 10
                                            color: Theme.colors.primary

                                            Text {
                                                anchors.centerIn: parent
                                                text: "APP OF THE DAY"
                                                font.pixelSize: 9
                                                font.weight: Font.DemiBold
                                                color: Theme.textOnPrimary
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            text: "Blender 4.2 LTS"
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: 18
                                            font.weight: Font.DemiBold
                                            color: Theme.colors.text
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                            text: "The free and open source 3D creation suite, powered by modern GPU rendering."
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: Theme.typography.scaleCaption.size
                                            color: Theme.colors.textSecondary
                                        }
                                    }

                                    DeloButton {
                                        Layout.preferredWidth: 100
                                        Layout.preferredHeight: 34
                                        variant: PackageManager.isInstalled("blender") ? "secondary" : "primary"
                                        text: PackageManager.isInstalled("blender") ? "Installed" : "Get Blender"
                                        onClicked: {
                                            if (PackageManager.isInstalled("blender")) {
                                                ApplicationManager.activateOrLaunch({ id: "blender", exec: "blender" });
                                                ShellState.closeAppStore();
                                            } else {
                                                PackageManager.installApp("blender");
                                            }
                                        }
                                    }
                                }
                            }

                            // Application Cards List
                            ColumnLayout {
                                id: cardsCol
                                Layout.fillWidth: true
                                spacing: 10

                                property var queriedApps: PackageManager.queryApps(storeCard.activeNav, storeCard.searchText)

                                Repeater {
                                    model: cardsCol.queriedApps

                                    delegate: DeloCard {
                                        id: appCard
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 74
                                        cardRadius: Theme.radiusLarge
                                        surfaceColor: Theme.colors.surface
                                        surfaceHoverColor: Theme.colors.surfaceVariant
                                        borderColor: Theme.colors.border
                                        borderHoverColor: Theme.colors.primary
                                        hoverable: true
                                        onClicked: storeCard.selectedApp = modelData

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 16
                                            anchors.rightMargin: 16
                                            anchors.topMargin: 10
                                            anchors.bottomMargin: 10
                                            spacing: 14

                                            // App Icon
                                            Rectangle {
                                                Layout.preferredWidth: 46
                                                Layout.preferredHeight: 46
                                                radius: Theme.radius.medium
                                                color: Theme.colors.surfaceVariant
                                                border.color: Theme.colors.borderSubtle
                                                border.width: 1

                                                AppIcon {
                                                    anchors.centerIn: parent
                                                    source: modelData.icon
                                                    iconSize: 36
                                                }
                                            }

                                            // Text Info
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 3

                                                RowLayout {
                                                    spacing: 8
                                                    Text {
                                                        text: modelData.name
                                                        font.family: Theme.typography.fontFamily
                                                        font.pixelSize: 14
                                                        font.weight: Font.DemiBold
                                                        color: Theme.colors.text
                                                    }
                                                    Text {
                                                        text: "★ " + modelData.rating
                                                        font.pixelSize: 11
                                                        color: Theme.colors.warning
                                                        font.weight: Font.DemiBold
                                                    }
                                                    Text { text: "•"; font.pixelSize: 10; color: Theme.colors.textSecondary }
                                                    Text {
                                                        text: modelData.category
                                                        font.pixelSize: 11
                                                        color: Theme.colors.primary
                                                        font.weight: Font.DemiBold
                                                    }
                                                }

                                                Text {
                                                    text: modelData.summary
                                                    font.family: Theme.typography.fontFamily
                                                    font.pixelSize: Theme.typography.scaleCaption.size
                                                    color: Theme.colors.textSecondary
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }

                                            // Quick Pin to Dock Icon Button (if installed)
                                            Rectangle {
                                                visible: modelData.installed
                                                Layout.preferredWidth: 32
                                                Layout.preferredHeight: 32
                                                radius: Theme.radius.small
                                                color: pinMouse.containsMouse ? Theme.colors.surfaceVariant : "transparent"

                                                SymbolicIcon {
                                                    anchors.centerIn: parent
                                                    source: ApplicationManager.isPinned(modelData.id) ? "apps-symbolic" : "view-app-grid-symbolic"
                                                    iconSize: 16
                                                    iconColor: ApplicationManager.isPinned(modelData.id) ? Theme.colors.primary : Theme.colors.textSecondary
                                                }

                                                MouseArea {
                                                    id: pinMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: ApplicationManager.togglePin(modelData.id)
                                                }
                                            }

                                            // Action Button
                                            DeloButton {
                                                Layout.preferredWidth: 84
                                                Layout.preferredHeight: 32
                                                variant: modelData.installed ? "secondary" : "primary"
                                                text: {
                                                    if (modelData.isInstalling) return Math.round(modelData.progress * 100) + "%";
                                                    if (modelData.installed) return "Open";
                                                    return "Install";
                                                }
                                                onClicked: {
                                                    if (modelData.installed) {
                                                        ApplicationManager.activateOrLaunch({ id: modelData.id, exec: modelData.id });
                                                        ShellState.closeAppStore();
                                                    } else {
                                                        PackageManager.installApp(modelData.id);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Empty State
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 40
                                spacing: 10
                                visible: cardsCol.queriedApps.length === 0

                                SymbolicIcon {
                                    Layout.alignment: Qt.AlignHCenter
                                    source: "search"
                                    iconSize: 32
                                    iconColor: Theme.colors.textSecondary
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "No applications found"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                    color: Theme.colors.text
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Try adjusting your search terms or browse categories."
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.typography.scaleCaption.size
                                    color: Theme.colors.textSecondary
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
