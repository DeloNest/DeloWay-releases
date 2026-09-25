import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../theme"
import "../../../services"
import "../.."
import ".."
import "../../timecapsule"

// WifiPage — networks, connection state and inline authentication.
//   • Sorted: connected → saved → by signal strength; signal-bar icon per network.
//   • Secured + unknown network → password row expands in place (Enter / Connect).
//   • Failed auth (nmcli "secrets required") re-opens the password row with the error.
//   • Connected network → expands to Disconnect / Forget actions.
ColumnLayout {
    id: root

    required property var qs
    spacing: 10

    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    function t(ar, en) { return I18n.isRTL ? ar : en; }
    property string expandedSsid: ""

    readonly property var sortedNetworks: {
        const list = (NetworkService.wifiNetworks || []).slice();
        const seen = {};
        const uniq = list.filter(n => n.ssid && !seen[n.ssid] && (seen[n.ssid] = true));
        return uniq.sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            const sa = NetworkService.isSaved(a.ssid), sb = NetworkService.isSaved(b.ssid);
            if (sa !== sb) return sa ? -1 : 1;
            return (b.signal || 0) - (a.signal || 0);
        });
    }

    function signalIcon(s) {
        if (s >= 75) return "network-wireless-signal-excellent-symbolic";
        if (s >= 50) return "network-wireless-signal-good-symbolic";
        if (s >= 25) return "network-wireless-signal-ok-symbolic";
        return "network-wireless-signal-weak-symbolic";
    }
    function secured(n) { return n.security && n.security !== "Open" && n.security !== "--" && n.security.length > 0; }

    function activate(n) {
        if (n.connected || root.expandedSsid === n.ssid) {
            root.expandedSsid = (root.expandedSsid === n.ssid) ? "" : n.ssid;
            return;
        }
        if (root.secured(n) && !NetworkService.isSaved(n.ssid)) {
            root.expandedSsid = n.ssid;
            return;
        }
        root.expandedSsid = "";
        NetworkService.connectWifi(n.ssid, "");
    }

    // Failed authentication → open the password row for that network.
    Connections {
        target: NetworkService
        function onPasswordRequiredSsidChanged() {
            if (NetworkService.passwordRequiredSsid.length > 0) root.expandedSsid = NetworkService.passwordRequiredSsid;
        }
    }

    QSPageHeader {
        title: "Wi-Fi"
        subtitle: !NetworkService.wifiEnabled ? root.t("متوقف", "Off")
                  : (NetworkService.wifiSsid ? root.t("متصل بـ ", "Connected to ") + I18n.isolate(NetworkService.wifiSsid)
                     : (root.sortedNetworks.length === 0 ? root.t("لا توجد شبكات", "No networks")
                                                       : I18n.networksCount(root.sortedNetworks.length)))
        hasAction: NetworkService.wifiEnabled
        actionBusy: NetworkService.isScanning
        hasSwitch: NetworkService.wifiAvailable
        switchOn: NetworkService.wifiEnabled
        onBackClicked: ShellState.quickSettingsCapsuleView = "main"
        onActionClicked: NetworkService.scanWifi()
        onSwitchToggled: root.qs.toggleWifi()
    }

    // Wired connection (read-only summary)
    QSRow {
        visible: NetworkService.ethernetConnected
        Layout.fillWidth: true
        iconName: "network-wired-symbolic"
        title: root.t("اتصال سلكي", "Wired")
        subtitle: (NetworkService.ethernetDevice || "") + (NetworkService.ethernetIp ? "  ·  " + NetworkService.ethernetIp : "")
        selected: true
    }

    ListView {
        id: list
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        model: NetworkService.wifiEnabled ? root.sortedNetworks : []
        ScrollBar.vertical: ScrollBar {
            policy: list.contentHeight > list.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            width: 4
            contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Theme.notchBorderHighlight }
        }
        displaced: Transition { NumberAnimation { properties: "y"; duration: Theme.motionBase; easing.type: Theme.easingEnter } }

        delegate: QSRow {
            id: row
            required property var modelData
            readonly property bool isSecured: root.secured(modelData)
            readonly property bool isSaved: NetworkService.isSaved(modelData.ssid)
            readonly property bool needsPassword: isSecured && (!isSaved || NetworkService.passwordRequiredSsid === modelData.ssid)
            width: list.width - (list.contentHeight > list.height ? 8 : 0)
            // Vertical ListView only positions y: keep the gutter on the scrollbar's side.
            x: (I18n.isRTL && list.contentHeight > list.height) ? 8 : 0
            iconName: root.signalIcon(modelData.signal || 0)
            title: modelData.ssid
            subtitle: NetworkService.connectingSsid === modelData.ssid ? root.t("جارٍ الاتصال…", "Connecting…")
                      : (modelData.connected ? root.t("متصل", "Connected") + (NetworkService.ipDetails.ipv4 ? "  ·  " + NetworkService.ipDetails.ipv4 : "")
                         : (isSaved ? root.t("محفوظة", "Saved") : (isSecured ? root.t("محمية", "Secured") : root.t("مفتوحة", "Open"))))
            trailingIcon: isSecured ? "system-lock-screen-symbolic" : ""
            selected: modelData.connected
            busy: NetworkService.connectingSsid === modelData.ssid
            expanded: root.expandedSsid === modelData.ssid
            onClicked: root.activate(modelData)

            extra: Column {
                width: parent ? parent.width : 0
                spacing: 6

                // Password entry (unknown secured network / failed auth)
                RowLayout {
                    visible: !row.modelData.connected && row.needsPassword
                    width: parent.width
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 32
                        radius: 16
                        color: Theme.notchSurfaceElevated
                        border.color: pw.activeFocus ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                        border.width: 1

                        TextInput {
                            id: pw
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter
                            horizontalAlignment: TextInput.AlignLeft   // mirrored to the right in Arabic by the inherited LayoutMirroring
                            echoMode: reveal.checked ? TextInput.Normal : TextInput.Password
                            passwordCharacter: "•"
                            clip: true
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(12)
                            color: Theme.notchText
                            selectionColor: Theme.notchSurfaceActive
                            onAccepted: if (text.length >= 8) { NetworkService.connectWifi(row.modelData.ssid, text); root.expandedSsid = ""; text = ""; }
                            onVisibleChanged: if (visible && row.expanded) forceActiveFocus()

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: parent.horizontalAlignment
                                visible: pw.text.length === 0
                                text: root.t("كلمة المرور", "Password")
                                font: pw.font
                                color: Theme.notchTextTertiary
                            }
                        }
                    }
                    QSIconButton {
                        id: reveal
                        property bool checked: false
                        size: 32
                        iconName: checked ? "view-conceal-symbolic" : "view-reveal-symbolic"
                        highlighted: checked
                        onClicked: checked = !checked
                    }
                    PillButton {
                        implicitHeight: 32
                        primary: true
                        text: root.t("اتصال", "Connect")
                        enabled: pw.text.length >= 8
                        onClicked: { NetworkService.connectWifi(row.modelData.ssid, pw.text); root.expandedSsid = ""; pw.text = ""; }
                    }
                }
                // Actions for the connected / saved network
                RowLayout {
                    visible: row.modelData.connected || (row.isSaved && !row.needsPassword)
                    width: parent.width
                    spacing: 6
                    Item { Layout.fillWidth: true }
                    PillButton {
                        visible: row.modelData.connected
                        implicitHeight: 28
                        text: root.t("قطع الاتصال", "Disconnect")
                        onClicked: { NetworkService.disconnectWifi(); root.expandedSsid = ""; }
                    }
                    PillButton {
                        visible: !row.modelData.connected
                        implicitHeight: 28
                        primary: true
                        text: root.t("اتصال", "Connect")
                        onClicked: { NetworkService.connectWifi(row.modelData.ssid, ""); root.expandedSsid = ""; }
                    }
                    PillButton {
                        visible: row.isSaved
                        implicitHeight: 28
                        text: root.t("نسيان", "Forget")
                        onClicked: { NetworkService.forgetConnection(row.modelData.ssid); root.expandedSsid = ""; }
                    }
                }
            }
        }

        // Empty / off states
        Column {
            anchors.centerIn: parent
            spacing: 8
            visible: list.count === 0
            SymbolicIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                iconSize: 26
                source: NetworkService.wifiEnabled ? "network-wireless-signal-weak-symbolic" : "network-wireless-disabled-symbolic"
                iconColor: Theme.notchTextTertiary
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: !NetworkService.wifiAvailable ? root.t("لا توجد بطاقة Wi-Fi", "No Wi-Fi adapter")
                      : (!NetworkService.wifiEnabled ? I18n.uiLine(root.t("Wi-Fi متوقف", "Wi-Fi is off"))
                         : (NetworkService.isScanning ? root.t("جارٍ البحث…", "Scanning…") : root.t("لا توجد شبكات", "No networks found")))
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(12)
                color: Theme.notchTextSecondary
                renderType: Theme.renderType
            }
        }
    }

    // Error line (semantic colour restricted to the 6px dot)
    RowLayout {
        visible: NetworkService.networkError.length > 0
        Layout.fillWidth: true
        spacing: 8
        StatusDot { level: 2; Layout.alignment: Qt.AlignVCenter }
        Text {
            Layout.fillWidth: true
            text: NotificationManager.bidi(NetworkService.networkError)
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideRight
            font.family: Theme.typography.fontFamily
            font.pixelSize: Theme.fontSize(10)
            color: Theme.notchTextSecondary
            renderType: Theme.renderType
        }
    }
}
