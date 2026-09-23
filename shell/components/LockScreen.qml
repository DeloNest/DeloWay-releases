import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pam
import "../theme"
import "../services"

WlSessionLock {
    id: root

    // Display name only. PamContext.user is left at its default (the real uid) unless
    // $USER is set: a made-up fallback name would make getpwnam fail and hang PAM.
    readonly property string envUser: Quickshell.env("USER") || ""
    property string currentUser: envUser || "DeloOS"

    // PAM service: DeloWay's own file (installed by install.sh), else hyprlock's, else
    // the system 'login' stack. Picked once at startup; never a file that is missing.
    property string pamService: "login"
    Process {
        running: true
        command: ["sh", "-c", "for s in deloway hyprlock; do [ -f /etc/pam.d/$s ] && { echo $s; exit 0; }; done; echo login"]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = this.text.trim();
                if (s) root.pamService = s;
            }
        }
    }
    property var now: new Date()

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
                            text: I18n.clockText(root.now, false)
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: 68
                            font.weight: Font.Light
                            color: Theme.colors.text
                        }

                        Text {
                            id: lockDate
                            Layout.alignment: Qt.AlignHCenter
                            text: I18n.fullDateText(root.now)
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
                                color: Theme.colors.surfaceElevated
                                border.color: Theme.colors.borderSubtle
                                border.width: 1

                                SymbolicIcon {
                                    anchors.centerIn: parent
                                    iconSize: 32
                                    source: "avatar-default-symbolic"
                                    iconColor: Theme.colors.text
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
                        border.color: pwdInput.activeFocus ? Theme.colors.borderHighlight : (errorMsg.text ? Theme.colors.urgent : Theme.hairline)
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
                                horizontalAlignment: TextInput.AlignLeft   // mirrored in Arabic
                                readOnly: pam.active
                                selectByMouse: true
                                focus: true

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignLeft
                                    text: I18n.tr("lock_placeholder")
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
                                // Points toward the reading end (the button sits there).
                                iconSource: I18n.isRTL ? "go-previous-symbolic" : "go-next-symbolic"
                                Accessible.name: I18n.tr("lock_unlock")
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

            // Clock update timer (only while locked)
            Timer {
                interval: 1000
                running: root.locked
                repeat: true
                triggeredOnStart: true
                onTriggered: root.now = new Date()
            }

            // PAM Context
            PamContext {
                id: pam
                config: root.pamService
                Component.onCompleted: if (root.envUser) pam.user = root.envUser

                onCompleted: result => {
                    if (result === PamResult.Success) {
                        errorMsg.text = "";
                        pwdInput.text = "";
                        root.locked = false;
                        return;
                    }
                    // PAM's own text wins when it explains why (e.g. faillock:
                    // "account locked … minutes left"); otherwise a clear local message.
                    const pamText = (pam.messageIsError && pam.message) ? pam.message : "";
                    errorMsg.text = pamText || (result === PamResult.MaxTries ? I18n.tr("lock_max_tries")
                                              : result === PamResult.Error ? I18n.tr("lock_error")
                                              : I18n.tr("lock_wrong"));
                    shakeAnim.restart();
                    pwdInput.text = "";
                    pwdInput.forceActiveFocus();
                }

                onResponseRequiredChanged: {
                    if (responseRequired) {
                        pam.respond(pwdInput.text);
                    }
                }
            }

            function tryUnlock() {
                if (pam.active) return;                 // one conversation at a time
                errorMsg.text = I18n.tr("lock_verifying");
                // start() returns false when the conversation cannot begin (missing PAM
                // file, unknown user): no signal follows, so report it here instead of
                // leaving "Verifying…" forever. Empty passwords are allowed (nullok).
                if (!pam.start()) {
                    errorMsg.text = I18n.tr("lock_unavailable");
                    shakeAnim.restart();
                }
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
