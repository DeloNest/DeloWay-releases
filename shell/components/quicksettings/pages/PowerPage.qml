import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../../../theme"
import "../../../services"
import "../.."
import ".."

// PowerPage — session actions + power profile.
// Destructive actions (log out / restart / shut down) need a second tap within 3s:
// the row switches to "Tap again to …" instead of opening a separate dialog.
ColumnLayout {
    id: root

    required property var qs
    spacing: 10

    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true
    function t(ar, en) { return I18n.isRTL ? ar : en; }

    property string armed: ""
    Timer { id: disarm; interval: 3000; onTriggered: root.armed = "" }

    function run(a) {
        if (a.confirm && root.armed !== a.id) {
            root.armed = a.id;
            disarm.restart();
            return;
        }
        root.armed = "";
        ShellState.closeQuickSettingsCapsule();
        if (a.id === "lock") ShellState.lock();
        else if (a.id === "logout") Hyprland.dispatch("exit");
        else Quickshell.execDetached(a.cmd);
    }

    readonly property var actions: [
        { id: "lock",     icon: "system-lock-screen-symbolic", label: root.t("قفل الشاشة", "Lock"),        confirm: false },
        { id: "suspend",  icon: "system-suspend-symbolic",     label: root.t("سكون", "Suspend"),           confirm: false, cmd: ["systemctl", "suspend"] },
        { id: "logout",   icon: "system-log-out-symbolic",     label: root.t("تسجيل الخروج", "Log Out"),   confirm: true },
        { id: "reboot",   icon: "system-reboot-symbolic",      label: root.t("إعادة التشغيل", "Restart"),  confirm: true,  cmd: ["systemctl", "reboot"] },
        { id: "poweroff", icon: "system-shutdown-symbolic",    label: root.t("إيقاف التشغيل", "Shut Down"), confirm: true, cmd: ["systemctl", "poweroff"] }
    ]

    QSPageHeader {
        title: root.t("الطاقة", "Power")
        subtitle: ControlCenterService.userName + (ControlCenterService.hostName ? "@" + ControlCenterService.hostName : "")
        onBackClicked: ShellState.quickSettingsCapsuleView = "main"
    }

    Repeater {
        model: root.actions
        delegate: QSRow {
            required property var modelData
            Layout.fillWidth: true
            iconName: modelData.icon
            title: root.armed === modelData.id ? root.t("اضغط مرة أخرى للتأكيد", "Tap again to confirm") : modelData.label
            subtitle: root.armed === modelData.id ? modelData.label : ""
            selected: root.armed === modelData.id
            onClicked: root.run(modelData)
        }
    }

    // Power profile (only with power-profiles-daemon)
    Text {
        visible: ControlCenterService.powerProfilesAvailable
        Layout.fillWidth: true
        Layout.topMargin: 6
        Layout.leftMargin: 10
        text: root.t("وضع الطاقة", "Power mode")
        horizontalAlignment: Text.AlignLeft
        font.family: Theme.typography.fontFamily
        font.pixelSize: Theme.fontSize(10)
        font.weight: Font.DemiBold
        color: Theme.notchTextTertiary
        renderType: Theme.renderType
    }
    Repeater {
        model: ControlCenterService.powerProfilesAvailable ? ControlCenterService.powerProfiles : []
        delegate: QSRow {
            required property string modelData
            Layout.fillWidth: true
            iconName: "power-profile-" + modelData + "-symbolic"
            title: ({ "power-saver": root.t("توفير الطاقة", "Power Saver"),
                      "balanced": root.t("متوازن", "Balanced"),
                      "performance": root.t("أداء عالٍ", "Performance") })[modelData]
            selected: ControlCenterService.powerProfile === modelData
            onClicked: ControlCenterService.setPowerProfile(modelData)
        }
    }

    Item { Layout.fillHeight: true }
}
