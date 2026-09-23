import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../theme"
import "../../../services"
import "../.."
import ".."

ColumnLayout {
    id: root

    property bool hotspotAvailable: false
    property bool hotspotEnabled: false
    property string hotspotSsid: ""
    property string hotspotPassword: ""
    property string hotspotError: ""
    property string hotspotSaveSuccess: ""
    property var hotspotClients: []
    property bool actionRunning: false
    property bool configureRunning: false

    signal backClicked()
    signal refreshClicked()
    signal toggleClicked()
    signal saveClicked(string ssid, string password)

    spacing: 10
    // The only Quick Settings page that never mirrored (no ancestor supplies it).
    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    // Header: Back button + Title + Refresh
    QSPageHeader {
        title: I18n.isRTL ? "إعدادات نقطة الاتصال" : "Hotspot Settings"
        hasAction: true
        actionText: "⟳"
        onBackClicked: root.backClicked()
        onActionClicked: root.refreshClicked()
    }

    // Large Toggle Switch Card (Hotspot State)
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 46
        radius: Theme.notchRadiusCard
        color: Theme.notchSurfaceElevated
        border.color: root.hotspotEnabled ? Theme.accent : Theme.notchBorder
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            SymbolicIcon {
                source: "network-wireless-hotspot-symbolic"
                iconSize: 18
                iconColor: root.hotspotEnabled ? Theme.accent : Theme.notchTextSecondary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignLeft
                    text: I18n.isRTL ? "نقطة الاتصال الشخصية" : "Personal Hotspot"
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(11)
                    font.weight: Font.DemiBold
                    color: Theme.notchText
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignLeft
                    text: {
                        if (!root.hotspotAvailable) return I18n.isRTL ? "غير متوفرة" : "Unavailable";
                        if (root.hotspotEnabled) return I18n.isRTL ? ("مفعلة • " + I18n.isolate(root.hotspotSsid || "Hotspot")) : ("Active • " + I18n.isolate(root.hotspotSsid || "Hotspot"));
                        return I18n.isRTL ? "معطلة" : "Disabled";
                    }
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(10)
                    color: root.hotspotEnabled ? Theme.accent : Theme.notchTextSecondary
                    elide: Text.ElideRight
                }
            }

            // Switch Pill
            Rectangle {
                width: 44
                height: 24
                radius: 12
                color: root.hotspotEnabled ? Theme.accent : Theme.notchBackground
                border.color: Theme.notchBorder
                border.width: 1
                opacity: root.hotspotAvailable && !root.actionRunning ? 1.0 : 0.5

                Rectangle {
                    x: root.hotspotEnabled ? (I18n.isRTL ? 4 : 24) : (I18n.isRTL ? 24 : 4)
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    radius: 8
                    color: Theme.textOnAccent
                    Behavior on x { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.hotspotAvailable && !root.actionRunning
                    cursorShape: root.hotspotAvailable ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.toggleClicked()
                }
            }
        }
    }

    // Configuration Card (SSID, Password, Save)
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: hotspotConfigCol.implicitHeight + 16
        radius: Theme.notchRadiusCard
        color: Theme.notchSurfaceElevated
        border.color: Theme.notchBorder
        border.width: 1

        Connections {
            target: root
            function onHotspotSsidChanged() {
                if (!ssidInput.activeFocus) {
                    ssidInput.text = root.hotspotSsid;
                }
            }
            function onHotspotPasswordChanged() {
                if (!pwdInput.activeFocus) {
                    pwdInput.text = root.hotspotPassword;
                }
            }
        }

        ColumnLayout {
            id: hotspotConfigCol
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            // SSID Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: I18n.isRTL ? "الاسم:" : "SSID:"
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(10)
                    font.weight: Font.Medium
                    color: Theme.notchTextSecondary
                    Layout.preferredWidth: 38
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 26
                    radius: Theme.notchRadiusPill
                    color: Theme.notchBackground
                    border.color: ssidInput.activeFocus ? Theme.notchBorderHighlight : Theme.notchBorder
                    border.width: 1

                    TextInput {
                        id: ssidInput
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: TextInput.AlignVCenter
                        horizontalAlignment: TextInput.AlignLeft
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(11)
                        color: Theme.notchText
                        text: root.hotspotSsid
                        selectByMouse: true
                        clip: true
                    }
                }
            }

            // Password Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: I18n.isRTL ? "السر:" : "Pass:"
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(10)
                    font.weight: Font.Medium
                    color: Theme.notchTextSecondary
                    Layout.preferredWidth: 38
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 26
                    radius: Theme.notchRadiusPill
                    color: Theme.notchBackground
                    border.color: pwdInput.activeFocus ? Theme.notchBorderHighlight : (pwdInput.text.length < 8 && pwdInput.text.length > 0 ? Theme.colors.danger : Theme.notchBorder)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 4
                        spacing: 4

                        TextInput {
                            id: pwdInput
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            verticalAlignment: TextInput.AlignVCenter
                            horizontalAlignment: TextInput.AlignLeft
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            color: Theme.notchText
                            text: root.hotspotPassword
                            echoMode: showPwdBtn.showPassword ? TextInput.Normal : TextInput.Password
                            selectByMouse: true
                            clip: true
                        }

                        Rectangle {
                            id: showPwdBtn
                            property bool showPassword: false
                            implicitWidth: pwdToggleText.implicitWidth + 10
                            implicitHeight: 20
                            radius: 10
                            color: eyeMa.containsMouse ? Theme.notchSurfaceHover : "transparent"

                            Text {
                                id: pwdToggleText
                                anchors.centerIn: parent
                                text: showPwdBtn.showPassword ? (I18n.isRTL ? "إخفاء" : "Hide") : (I18n.isRTL ? "إظهار" : "Show")
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(10)
                                font.weight: Font.Medium
                                color: eyeMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: eyeMa
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: showPwdBtn.showPassword = !showPwdBtn.showPassword
                            }
                        }
                    }
                }
            }

            // Save Button Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignLeft
                    text: {
                        if (root.hotspotError.length > 0) return root.hotspotError;
                        if (root.hotspotSaveSuccess.length > 0) return root.hotspotSaveSuccess;
                        if (pwdInput.text.length < 8) return (I18n.isRTL ? "كلمة المرور 8 خانات كحد أدنى" : "Password must be >= 8 chars");
                        return "";
                    }
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(10)
                    color: {
                        if (root.hotspotError.length > 0 || (pwdInput.text.length < 8 && pwdInput.text.length > 0)) return Theme.colors.danger;
                        if (root.hotspotSaveSuccess.length > 0) return Theme.colors.success;
                        return Theme.notchTextTertiary;
                    }
                    elide: Text.ElideRight
                }

                Rectangle {
                    implicitWidth: 60
                    implicitHeight: 24
                    radius: Theme.notchRadiusPill
                    color: saveBtnMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchBackground
                    border.color: canSave ? Theme.notchBorderHighlight : Theme.notchBorder
                    border.width: 1
                    opacity: canSave && !root.configureRunning ? 1.0 : 0.4

                    readonly property bool canSave: ssidInput.text.trim().length > 0 && pwdInput.text.length >= 8 && (ssidInput.text.trim() !== root.hotspotSsid || pwdInput.text !== root.hotspotPassword)

                    Text {
                        anchors.centerIn: parent
                        text: root.configureRunning ? "..." : (I18n.isRTL ? "حفظ" : "Save")
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(10)
                        font.weight: Font.DemiBold
                        color: parent.canSave ? Theme.notchText : Theme.notchTextTertiary
                    }

                    MouseArea {
                        id: saveBtnMa
                        anchors.fill: parent
                        enabled: parent.canSave && !root.configureRunning
                        cursorShape: parent.canSave ? Qt.PointingHandCursor : Qt.ArrowCursor
                        hoverEnabled: true
                        onClicked: {
                            root.saveClicked(ssidInput.text.trim(), pwdInput.text);
                        }
                    }
                }
            }
        }
    }

    // Connected Devices Section Title
    Text {
        text: I18n.isRTL ? "الأجهزة المتصلة" : "Connected Devices"
        font.family: Theme.typography.fontFamily
        font.pixelSize: Theme.fontSize(10)
        font.weight: Font.DemiBold
        color: Theme.notchTextSecondary
        Layout.topMargin: 2
    }

    // Connected Devices Box / List
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Theme.notchRadiusCard
        color: Theme.notchSurfaceElevated
        border.color: Theme.notchBorder
        border.width: 1
        clip: true

        ListView {
            id: clientsListView
            anchors.fill: parent
            anchors.margins: 6
            spacing: 4
            clip: true
            model: root.hotspotClients

            delegate: Rectangle {
                width: clientsListView.width
                height: 32
                radius: 6
                color: clientMa.containsMouse ? Theme.notchSurfaceHover : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    SymbolicIcon {
                        source: "computer-symbolic"
                        iconSize: 14
                        iconColor: Theme.notchTextSecondary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: modelData.hostname || modelData.ip || modelData.mac
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            font.weight: Font.DemiBold
                            color: Theme.notchText
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignLeft
                        }

                        Text {
                            text: I18n.ltr((modelData.ip ? modelData.ip + " • " : "") + (modelData.mac || ""))
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(9)
                            color: Theme.notchTextTertiary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignLeft
                        }
                    }
                }

                MouseArea {
                    id: clientMa
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }

            // Empty State
            Text {
                anchors.centerIn: parent
                visible: clientsListView.count === 0
                text: !root.hotspotEnabled
                      ? (I18n.isRTL ? "قم بتفعيل نقطة الاتصال لعرض الأجهزة" : "Enable hotspot to see connected devices")
                      : (I18n.isRTL ? "لا توجد أجهزة متصلة حالياً" : "No devices currently connected")
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(10)
                color: Theme.notchTextTertiary
            }
        }
    }
}
