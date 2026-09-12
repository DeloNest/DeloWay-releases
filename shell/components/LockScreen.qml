import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import "../theme"
import "../services"

WlSessionLock {
    id: root

    property string currentUser: Quickshell.env("USER") || "DeloOS"

    surface: Component {
        WlSessionLockSurface {
            id: surface
            color: Theme.colors.background

            // Fullscreen Alpine Backdrop
            Image {
                anchors.fill: parent
                source: ConfigManager.wallpaper.startsWith("file://") ? ConfigManager.wallpaper : ("file://" + ConfigManager.wallpaper)
                fillMode: Image.PreserveAspectCrop

                Rectangle {
                    anchors.fill: parent
                    color: Qt.alpha(Theme.colors.background, 0.88) // Mica dark overlay for lockscreen focus
                }
            }

            // Lock Screen Center Panel
            Item {
                id: centerCard
                anchors.centerIn: parent
                width: 360
                height: 480

                LayoutMirroring.enabled: I18n.isRTL
                LayoutMirroring.childrenInherit: true

                property real shakeOffset: 0
                transform: Translate { x: centerCard.shakeOffset }

                SequentialAnimation {
                    id: shakeAnim
                    NumberAnimation { target: centerCard; property: "shakeOffset"; from: 0; to: -12; duration: 50 }
                    NumberAnimation { target: centerCard; property: "shakeOffset"; from: -12; to: 12; duration: 50 }
                    NumberAnimation { target: centerCard; property: "shakeOffset"; from: 12; to: -8; duration: 50 }
                    NumberAnimation { target: centerCard; property: "shakeOffset"; from: -8; to: 8; duration: 50 }
                    NumberAnimation { target: centerCard; property: "shakeOffset"; from: 8; to: 0; duration: 50 }
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 16


                    // 1. CLOCK & DATE
                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 4

                        Text {
                            id: lockClock
                            Layout.alignment: Qt.AlignHCenter
                            text: Qt.formatTime(new Date(), ConfigManager.clockFormat === "24h" ? "HH:mm" : "hh:mm")
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: 68
                            font.weight: Font.Light
                            color: Theme.colors.text
                        }

                        Text {
                            id: lockDate
                            Layout.alignment: Qt.AlignHCenter
                            text: Qt.formatDate(new Date(), "dddd, d MMMM yyyy")
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.typography.fontSizeRegular
                            color: Theme.colors.textSecondary
                        }
                    }

                    Item { Layout.preferredHeight: 20 }

                    // 2. USER AVATAR & NAME
                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            width: 72
                            height: 72
                            radius: 36
                            color: Theme.colors.surfaceVariant
                            border.color: Theme.colors.borderSubtle
                            border.width: 1

                            Rectangle {
                                anchors.centerIn: parent
                                width: 64
                                height: 64
                                radius: 32
                                color: Theme.colors.accent

                                SymbolicIcon {
                                    anchors.centerIn: parent
                                    iconSize: 32
                                    source: "avatar-default-symbolic"
                                    iconColor: Theme.textOnAccent
                                }
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.currentUser
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.typography.fontSizeLarge
                            font.weight: Font.DemiBold
                            color: Theme.colors.text
                        }
                    }

                    Item { Layout.preferredHeight: 10 }

                    // 3. PASSWORD INPUT CARD
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 280
                        Layout.preferredHeight: 44
                        radius: Theme.radiusMedium
                        color: Theme.colors.surface
                        border.color: pwdInput.activeFocus ? Theme.colors.accent : (errorMsg.text ? Theme.colors.urgent : Theme.hairline)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            spacing: 8

                            TextInput {
                                id: pwdInput
                                Layout.fillWidth: true
                                font.family: Theme.typography.fontFamily
                                font.hintingPreference: Theme.hintingPreference
                                font.pixelSize: Theme.typography.scaleBody.size
                                renderType: Theme.renderType
                                color: Theme.colors.text
                                echoMode: TextInput.Password
                                verticalAlignment: TextInput.AlignVCenter
                                selectByMouse: true
                                focus: true

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: "Enter Password"
                                    font.family: Theme.typography.fontFamily
                                    font.hintingPreference: Theme.hintingPreference
                                    font.pixelSize: Theme.typography.scaleBody.size
                                    renderType: Theme.renderType
                                    color: Theme.colors.textTertiary
                                    visible: !pwdInput.text && !pwdInput.activeFocus
                                }

                                Keys.onReturnPressed: {
                                    tryUnlock();
                                }
                            }

                            // Submit Button (Arrow)
                            DeloButton {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                variant: "ghost"
                                iconSource: "go-next-symbolic"
                                onClicked: tryUnlock()
                            }
                        }
                    }

                    // 4. ERROR MESSAGE / STATUS
                    Text {
                        id: errorMsg
                        Layout.alignment: Qt.AlignHCenter
                        text: ""
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: 11
                        color: Theme.colors.urgent
                        visible: text.length > 0
                    }
                }
            }

            // Clock update timer
            Timer {
                interval: 1000
                running: root.locked
                repeat: true
                onTriggered: {
                    lockClock.text = Qt.formatTime(new Date(), ConfigManager.clockFormat === "24h" ? "HH:mm" : "hh:mm");
                    lockDate.text = Qt.formatDate(new Date(), "dddd, d MMMM yyyy");
                }
            }

            // PAM Context
            PamContext {
                id: pam
                user: root.currentUser
                config: "hyprlock"

                onCompleted: result => {
                    if (result === PamResult.Success) {
                        errorMsg.text = "";
                        pwdInput.text = "";
                        root.locked = false;
                    } else {
                        errorMsg.text = "Incorrect password";
                        shakeAnim.restart();
                        pwdInput.text = "";
                        pwdInput.forceActiveFocus();
                    }
                }

                onError: err => {
                    errorMsg.text = "Authentication failed";
                    shakeAnim.restart();
                }

                onResponseRequiredChanged: {
                    if (responseRequired) {
                        pam.respond(pwdInput.text);
                    }
                }
            }

            function tryUnlock() {
                if (!pwdInput.text) return;
                errorMsg.text = "Verifying...";
                pam.start();
            }

            Component.onCompleted: {
                pwdInput.forceActiveFocus();
            }
        }
    }

    function lockSession() {
        root.locked = true;
    }
}
