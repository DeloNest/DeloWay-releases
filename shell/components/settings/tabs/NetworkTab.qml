// Network & Internet — Wi-Fi, personal hotspot, saved networks and IP details.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../../theme"
import "../../../services"
import "../common"
import "../../"

Item {
    id: root

    implicitWidth: 500
    implicitHeight: mainCol.implicitHeight + (Theme.space24 * 2)
    width: parent ? parent.width : implicitWidth
    height: implicitHeight
    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    property string selectedSsid: ""
    property string wifiPasswordInput: ""

    ColumnLayout {
        id: mainCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.space24
        spacing: Theme.space24
        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        // ═════════════════════════════════════════════════════════════
        // 1. WI-FI MANAGEMENT SECTION
        // ═════════════════════════════════════════════════════════════
        SettingsSection {
            title: I18n.isRTL ? "شبكة Wi-Fi والاتصال اللاسلكي" : "Wi-Fi & Wireless Network"

            // Wi-Fi Master Toggle
            SettingsRow {
                title: I18n.isRTL ? "شبكة Wi-Fi" : "Wi-Fi Network"
                subtitle: !NetworkService.wifiEnabled
                    ? (I18n.isRTL ? "الواي فاي معطل" : "Wi-Fi is turned off")
                    : (NetworkService.wifiSsid.length > 0
                        ? (I18n.isRTL ? ("متصل بشبكة: " + I18n.isolate(NetworkService.wifiSsid)) : ("Connected to: " + I18n.isolate(NetworkService.wifiSsid)))
                        : (I18n.isRTL ? "مفعّل — غير متصل بأي شبكة" : "Enabled — Not connected"))
                icon: NetworkService.wifiEnabled ? "network-wireless-symbolic" : "network-wireless-offline-symbolic"
                showDivider: NetworkService.wifiEnabled
                clickable: true
                onClicked: NetworkService.toggleWifi()

                SettingsToggle {
                    checked: NetworkService.wifiEnabled
                    onToggled: ch => {
                        if (ch !== NetworkService.wifiEnabled) NetworkService.toggleWifi();
                    }
                }
            }

            // If Wi-Fi is enabled: Connected network, available networks, scan button
            Item {
                visible: NetworkService.wifiEnabled
                Layout.fillWidth: true
                implicitHeight: wifiContentCol.implicitHeight
                Layout.preferredHeight: implicitHeight

                ColumnLayout {
                    id: wifiContentCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: Theme.space12
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    // Network Error Toast if any
                    Rectangle {
                        visible: NetworkService.networkError.length > 0
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.space16
                        Layout.rightMargin: Theme.space16
                        implicitHeight: 32
                        radius: 8
                        color: Theme.notchSurfaceElevated
                        border.color: Theme.notchBorder
                        border.width: 1

                        // Semantic colour only on the 6px dot.
                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Rectangle { width: 6; height: 6; radius: 3; color: Theme.danger; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                text: NetworkService.networkError
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: Font.Medium
                                color: Theme.notchText
                            }
                        }
                    }

                    // Section Header: Available Networks & Rescan Action
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.space16
                        Layout.rightMargin: Theme.space16

                        Text {
                            text: I18n.isRTL ? "الشبكات القريبة المتاحة" : "Available Networks"
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            font.weight: Font.DemiBold
                            color: Theme.notchTextSecondary
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignLeft
                        }

                        // Rescan Button
                        Rectangle {
                            height: 26
                            implicitWidth: rescanRow.implicitWidth + Theme.space16
                            radius: 13
                            color: rescanMa.pressed ? Theme.notchSurfaceActive : (rescanMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceElevated)
                            border.color: rescanMa.containsMouse ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                            RowLayout {
                                id: rescanRow
                                anchors.centerIn: parent
                                spacing: 6
                                LayoutMirroring.enabled: I18n.isRTL
                                LayoutMirroring.childrenInherit: true

                                Text {
                                    text: NetworkService.isScanning ? "..." : "⟳"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(12)
                                    font.weight: Font.Bold
                                    color: Theme.notchText
                                }

                                Text {
                                    text: NetworkService.isScanning ? (I18n.isRTL ? "جارٍ المسح..." : "Scanning...") : (I18n.isRTL ? "تحديث" : "Refresh")
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(10)
                                    font.weight: Font.Medium
                                    color: Theme.notchText
                                }
                            }

                            MouseArea {
                                id: rescanMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NetworkService.scanWifi()
                            }
                        }
                    }

                    // Scanned Wi-Fi Networks List
                    Repeater {
                        model: NetworkService.wifiNetworks
                        delegate: ColumnLayout {
                            id: netDelegate
                            required property var modelData
                            required property int index

                            readonly property bool isCurrentConnected: modelData.connected || (NetworkService.wifiSsid === modelData.ssid)
                            readonly property bool isSelectedToConnect: root.selectedSsid === modelData.ssid
                            readonly property bool isSecured: modelData.security && modelData.security !== "Open" && modelData.security !== ""

                            Layout.fillWidth: true
                            spacing: 0

                            SettingsRow {
                                title: modelData.ssid || (I18n.isRTL ? "شبكة مخفية" : "Hidden Network")
                                subtitle: isCurrentConnected
                                    ? (I18n.isRTL ? "متصل حالياً بهذه الشبكة" : "Currently connected")
                                    : (modelData.security ? modelData.security : (I18n.isRTL ? "شبكة مفتوحة" : "Open"))
                                icon: isSecured ? "network-wireless-encrypted-symbolic" : "network-wireless-symbolic"
                                showDivider: true
                                clickable: !isCurrentConnected
                                onClicked: {
                                    if (isCurrentConnected) return;
                                    if (root.selectedSsid === modelData.ssid) {
                                        root.selectedSsid = "";
                                    } else {
                                        root.selectedSsid = modelData.ssid;
                                        root.wifiPasswordInput = "";
                                        // If open network, connect directly
                                        if (!isSecured) {
                                            NetworkService.connectWifi(modelData.ssid, "");
                                        }
                                    }
                                }

                                // Status indicator & Connect / Disconnect Actions
                                RowLayout {
                                    spacing: Theme.space8
                                    LayoutMirroring.enabled: I18n.isRTL
                                    LayoutMirroring.childrenInherit: true

                                    // Signal strength badge
                                    Text {
                                        text: (modelData.signal || 50) + "%"
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(10)
                                        color: Theme.notchTextTertiary
                                    }

                                    // Disconnect Button for active network
                                    Rectangle {
                                        visible: isCurrentConnected
                                        height: 26
                                        implicitWidth: disconnText.implicitWidth + Theme.space16
                                        radius: 13
                                        color: disconnMa.pressed ? Theme.notchSurfaceActive : (disconnMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceElevated)
                                        border.color: Theme.notchBorderSubtle
                                        border.width: 1

                                        Text {
                                            id: disconnText
                                            anchors.centerIn: parent
                                            text: I18n.isRTL ? "قطع الاتصال" : "Disconnect"
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: Theme.fontSize(10)
                                            font.weight: Font.Medium
                                            color: disconnMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                                        }

                                        MouseArea {
                                            id: disconnMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: NetworkService.disconnectWifi()
                                        }
                                    }

                                    // Expand Chevron for unconnected networks
                                    SymbolicIcon {
                                        visible: !isCurrentConnected
                                        source: isSelectedToConnect ? "pan-down-symbolic" : (I18n.isRTL ? "pan-start-symbolic" : "pan-end-symbolic")
                                        iconSize: 12
                                        iconColor: Theme.notchTextTertiary
                                    }
                                }
                            }

                            // Password Input Inset (shown when network is selected to connect)
                            Rectangle {
                                visible: isSelectedToConnect && !isCurrentConnected && isSecured
                                Layout.fillWidth: true
                                Layout.leftMargin: Theme.space16
                                Layout.rightMargin: Theme.space16
                                Layout.bottomMargin: Theme.space8
                                implicitHeight: 44
                                radius: 8
                                color: Theme.notchSurfaceElevated
                                border.color: Theme.notchBorderHighlight
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.space12
                                    anchors.rightMargin: Theme.space12
                                    spacing: Theme.space8
                                    LayoutMirroring.enabled: I18n.isRTL
                                    LayoutMirroring.childrenInherit: true

                                    DeloTextField {
                                        id: pwdInput
                                        Layout.fillWidth: true
                                        echoMode: TextInput.Password
                                        fontPixelSize: Theme.fontSize(12)
                                        placeholderText: I18n.isRTL ? "أدخل كلمة مرور الشبكة..." : "Enter Wi-Fi password..."
                                        onTextChanged: root.wifiPasswordInput = text
                                        onAccepted: {
                                            if (text.length >= 8) {
                                                NetworkService.connectWifi(netDelegate.modelData.ssid, text);
                                                root.selectedSsid = "";
                                            }
                                        }
                                    }

                                    Rectangle {
                                        height: 28
                                        implicitWidth: connBtnText.implicitWidth + Theme.space20
                                        radius: 14
                                        color: connBtnMa.pressed ? Theme.notchSurfaceActive : (connBtnMa.containsMouse ? Theme.notchSurfaceHover : Theme.inverseSurface)
                                        border.color: Theme.notchBorderHighlight
                                        border.width: 1

                                        Text {
                                            id: connBtnText
                                            anchors.centerIn: parent
                                            text: NetworkService.connectingSsid === netDelegate.modelData.ssid
                                                ? (I18n.isRTL ? "جارٍ الاتصال..." : "Connecting...")
                                                : (I18n.isRTL ? "اتصال" : "Connect")
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: Theme.fontSize(11)
                                            font.weight: Font.DemiBold
                                            color: (connBtnMa.pressed || connBtnMa.containsMouse) ? Theme.notchText : Theme.inverseText
                                        }

                                        MouseArea {
                                            id: connBtnMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                NetworkService.connectWifi(netDelegate.modelData.ssid, root.wifiPasswordInput);
                                                root.selectedSsid = "";
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Empty state for networks list
                    Text {
                        visible: NetworkService.wifiNetworks.length === 0 && !NetworkService.isScanning
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.space16
                        Layout.bottomMargin: Theme.space8
                        text: I18n.isRTL ? "لا توجد شبكات متاحة حالياً. اضغط تحديث للمسح." : "No networks detected. Click refresh to scan."
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(11)
                        color: Theme.notchTextTertiary
                        horizontalAlignment: Text.AlignLeft
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════
        // 2. PERSONAL HOTSPOT SECTION
        // ═════════════════════════════════════════════════════════════
        SettingsSection {
            title: I18n.isRTL ? "نقطة الاتصال الشخصية (Hotspot)" : "Personal Hotspot"

            // Master Hotspot Toggle
            SettingsRow {
                title: I18n.isRTL ? "نقطة الاتصال اللاسلكية" : "Mobile Hotspot"
                subtitle: !NetworkService.hotspotAvailable
                    ? (I18n.isRTL ? "غير متاحة على هذا العتاد" : "Not available on this hardware")
                    : (NetworkService.hotspotEnabled
                        ? (I18n.isRTL ? ("مفعّلة — متصل بها " + (NetworkService.hotspotClients ? NetworkService.hotspotClients.length : 0) + " جهاز")
                                      : ("Enabled — " + (NetworkService.hotspotClients ? NetworkService.hotspotClients.length : 0) + " device(s) connected"))
                        : (I18n.isRTL ? "معطلة — مشاركة الاتصال متوقفة" : "Disabled — Connection sharing is off"))
                icon: "network-wireless-hotspot-symbolic"
                showDivider: NetworkService.hotspotEnabled
                clickable: NetworkService.hotspotAvailable && !NetworkService.hotspotActionRunning
                onClicked: NetworkService.toggleHotspot()

                SettingsToggle {
                    enabled: NetworkService.hotspotAvailable && !NetworkService.hotspotActionRunning
                    checked: NetworkService.hotspotEnabled
                    onToggled: ch => {
                        if (ch !== NetworkService.hotspotEnabled) NetworkService.toggleHotspot();
                    }
                }
            }

            // Inset Card for SSID & Password Configuration + Clients (visible when enabled)
            Item {
                visible: NetworkService.hotspotEnabled
                Layout.fillWidth: true
                implicitHeight: hsContentCol.implicitHeight
                Layout.preferredHeight: implicitHeight

                ColumnLayout {
                    id: hsContentCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: Theme.space12
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    // Hotspot Error Toast if any
                    Rectangle {
                        visible: NetworkService.hotspotError.length > 0
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.space16
                        Layout.rightMargin: Theme.space16
                        implicitHeight: 32
                        radius: 8
                        color: Theme.notchSurfaceElevated
                        border.color: Theme.notchBorder
                        border.width: 1

                        // Semantic colour only on the 6px dot.
                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Rectangle { width: 6; height: 6; radius: 3; color: Theme.danger; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                text: NetworkService.hotspotError
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: Font.Medium
                                color: Theme.notchText
                            }
                        }
                    }

                    // Configuration Box: SSID + Password + Save
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.space16
                        Layout.rightMargin: Theme.space16
                        implicitHeight: hsFormCol.implicitHeight + Theme.space24
                        radius: 10
                        color: Theme.notchSurfaceElevated
                        border.color: Theme.notchBorderSubtle
                        border.width: 1

                        ColumnLayout {
                            id: hsFormCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Theme.space12
                            spacing: Theme.space8

                            Text {
                                text: I18n.isRTL ? "إعدادات شبكة البث" : "Hotspot Credentials"
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: Font.DemiBold
                                color: Theme.notchTextSecondary
                                horizontalAlignment: Text.AlignLeft
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.space8

                                DeloTextField {
                                    id: hsSsidInput
                                    Layout.fillWidth: true
                                    fontPixelSize: Theme.fontSize(11)
                                    placeholderText: I18n.isRTL ? "اسم الشبكة (SSID)..." : "Network SSID..."
                                    text: NetworkService.hotspotSsid || "Deloway-Hotspot"
                                }

                                DeloTextField {
                                    id: hsPasswordInput
                                    Layout.fillWidth: true
                                    echoMode: hsShowPwd ? TextInput.Normal : TextInput.Password
                                    fontPixelSize: Theme.fontSize(11)
                                    placeholderText: I18n.isRTL ? "كلمة المرور (8 أحرف فأكثر)..." : "Password (min 8 chars)..."
                                    text: NetworkService.hotspotPassword || ""
                                    property bool hsShowPwd: false
                                }

                                Rectangle {
                                    height: 28
                                    implicitWidth: saveBtnText.implicitWidth + Theme.space20
                                    radius: 14
                                    color: saveBtnMa.pressed ? Theme.notchSurfaceActive : (saveBtnMa.containsMouse ? Theme.notchSurfaceHover : Theme.inverseSurface)
                                    border.color: Theme.notchBorderHighlight
                                    border.width: 1

                                    Text {
                                        id: saveBtnText
                                        anchors.centerIn: parent
                                        text: NetworkService.hotspotConfigureRunning
                                            ? (I18n.isRTL ? "جارٍ الحفظ..." : "Saving...")
                                            : (I18n.isRTL ? "حفظ وتطبيق" : "Save & Apply")
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(10)
                                        font.weight: Font.DemiBold
                                        color: (saveBtnMa.pressed || saveBtnMa.containsMouse) ? Theme.notchText : Theme.inverseText
                                    }

                                    MouseArea {
                                        id: saveBtnMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        enabled: !NetworkService.hotspotConfigureRunning
                                        onClicked: {
                                            NetworkService.configureHotspot(hsSsidInput.text, hsPasswordInput.text);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Connected Clients Section
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.space16
                        Layout.rightMargin: Theme.space16
                        spacing: Theme.space6

                        Text {
                            text: (I18n.isRTL ? "الأجهزة المتصلة (" : "Connected Devices (") +
                                  (NetworkService.hotspotClients ? NetworkService.hotspotClients.length : 0) + ")"
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            font.weight: Font.DemiBold
                            color: Theme.notchTextSecondary
                            horizontalAlignment: Text.AlignLeft
                        }

                        Repeater {
                            model: NetworkService.hotspotClients
                            delegate: Rectangle {
                                id: clientCard
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                implicitHeight: 36
                                radius: 8
                                color: Theme.notchSurfaceElevated
                                border.color: Theme.notchBorderSubtle
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.space12
                                    anchors.rightMargin: Theme.space12
                                    spacing: Theme.space8
                                    LayoutMirroring.enabled: I18n.isRTL
                                    LayoutMirroring.childrenInherit: true

                                    SymbolicIcon {
                                        source: "network-wireless-symbolic"
                                        iconSize: 14
                                        iconColor: Theme.colors.success
                                    }

                                    Text {
                                        text: clientCard.modelData.hostname || clientCard.modelData.ip || clientCard.modelData.mac
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(11)
                                        font.weight: Font.Medium
                                        color: Theme.notchText
                                    }

                                    Text {
                                        horizontalAlignment: Text.AlignLeft   // hug the hostname (mirrored in Arabic)
                                        text: clientCard.modelData.ip ? ("(" + I18n.ltr(clientCard.modelData.ip) + ")") : ""
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(10)
                                        color: Theme.notchTextTertiary
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        visible: clientCard.modelData.signal ? true : false
                                        text: (clientCard.modelData.signal || "") + " dBm"
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(10)
                                        color: Theme.notchTextSecondary
                                    }
                                }
                            }
                        }

                        // Empty clients state
                        Text {
                            visible: !NetworkService.hotspotClients || NetworkService.hotspotClients.length === 0
                            text: I18n.isRTL ? "لا توجد أجهزة متصلة بنقطة الاتصال حالياً." : "No devices connected to hotspot currently."
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(10)
                            color: Theme.notchTextTertiary
                            horizontalAlignment: Text.AlignLeft
                        }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════
        // 4. ADVANCED NETWORK SETTINGS (Collapsible)
        // ═════════════════════════════════════════════════════════════
        SettingsSection {
            title: I18n.isRTL ? "إعدادات متقدمة للشبكة (Saved Networks & IP)" : "Advanced Network Settings"
            collapsible: true
            isExpanded: false

            // Section Header: Saved Networks
            SettingsRow {
                title: (I18n.isRTL ? "إدارة الشبكات المحفوظة (" : "Saved Networks (") + NetworkService.savedConnections.length + ")"
                subtitle: I18n.isRTL ? "الشبكات التي تم الاتصال بها مسبقاً وتخزين مفاتيحها" : "Previously connected wireless access points"
                icon: "network-wireless-symbolic"
                showDivider: true
            }

            Repeater {
                model: NetworkService.savedConnections
                delegate: SettingsRow {
                    id: savedRow
                    required property var modelData
                    required property int index

                    title: modelData.name
                    subtitle: modelData.autoconnect
                        ? (I18n.isRTL ? "اتصال تلقائي عند الاقتراب" : "Auto-connect enabled")
                        : (I18n.isRTL ? "اتصال يدوي" : "Manual connect")
                    icon: "network-wireless-symbolic"
                    showDivider: true

                    // Forget / Remove Connection Button
                    Rectangle {
                        height: 28
                        width: 28
                        radius: 14
                        color: forgetMa.pressed ? Theme.notchSurfaceActive : (forgetMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceElevated)
                        border.color: forgetMa.containsMouse ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                        SymbolicIcon {
                            anchors.centerIn: parent
                            iconSize: 14
                            source: "user-trash-symbolic"
                            iconColor: forgetMa.containsMouse ? Theme.colors.urgent : Theme.notchTextSecondary
                        }

                        MouseArea {
                            id: forgetMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                NetworkService.forgetConnection(savedRow.modelData.name || savedRow.modelData.uuid);
                            }
                        }
                    }
                }
            }

            // Empty state for saved connections
            SettingsRow {
                visible: NetworkService.savedConnections.length === 0
                title: I18n.isRTL ? "لا توجد شبكات محفوظة" : "No Saved Networks"
                subtitle: I18n.isRTL ? "الشبكات التي تتصل بها ستظهر هنا تلقائياً" : "Networks you connect to will appear here automatically"
                icon: "dialog-information-symbolic"
                showDivider: true
            }

            // IPv4 Address
            SettingsRow {
                title: "IPv4 Address"
                subtitle: NetworkService.ipDetails.ipv4 || (I18n.isRTL ? "غير متاح" : "Not assigned")
                icon: "network-workgroup-symbolic"
                showDivider: true
            }

            // Default Gateway
            SettingsRow {
                title: I18n.isRTL ? "البوابة الافتراضية (Gateway)" : "Default Gateway"
                subtitle: NetworkService.ipDetails.gateway || (I18n.isRTL ? "غير محددة" : "None")
                icon: "network-server-symbolic"
                showDivider: true
            }

            // DNS Servers
            SettingsRow {
                title: I18n.isRTL ? "خوادم الـ DNS" : "DNS Servers"
                subtitle: (NetworkService.ipDetails.dns && NetworkService.ipDetails.dns.length > 0)
                    ? NetworkService.ipDetails.dns.join(" • ")
                    : (I18n.isRTL ? "تلقائي من الشبكة" : "Automatic DHCP")
                icon: "preferences-system-network-symbolic"
                showDivider: true
            }

            // MAC & Interface
            SettingsRow {
                title: I18n.isRTL ? "منفذ الشبكة والـ MAC" : "Hardware Interface & MAC"
                subtitle: (NetworkService.ipDetails.interface || "wlan0") + " • " + (NetworkService.ipDetails.mac || "00:00:00:00:00:00")
                icon: "drive-harddisk-symbolic"
                showDivider: false
            }
        }
    }
}
