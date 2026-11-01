pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"
import "."

Item {
    id: root

    // Status: "idle" | "checking" | "up_to_date" | "update_available" | "updating" | "error" | "success"
    property string status: "idle"
    property int commitsBehind: 0
    property string currentCommit: ""
    property string currentVersion: "v2.0 OLED"
    property string currentCommitDate: ""
    property string currentCommitMsg: ""
    property var changelog: []
    property string errorMessage: ""
    property string lastChecked: ""
    property string repositoryUrl: "https://github.com/DeloNest/DeloWay-releases.git"

    readonly property string channel: (typeof ConfigManager !== "undefined" && ConfigManager.updateChannel)
        ? ConfigManager.updateChannel : "dev"
    readonly property bool hasUpdate: status === "update_available" && commitsBehind > 0
    readonly property bool isBusy: status === "checking" || status === "updating"

    // Project directory
    readonly property string projectDir: (typeof ConfigManager !== "undefined" && ConfigManager.projectDir)
        ? ConfigManager.projectDir : "/home/waleed/Projects/Deloway"

    // Initial check after startup
    Timer {
        id: startupTimer
        interval: 3500
        running: true
        repeat: false
        onTriggered: root.checkForUpdates()
    }

    // Process for checking updates
    Process {
        id: checkProc
        command: ["python3", root.projectDir + "/scripts/deloway-updater.py", "check", "--channel", root.channel]
        stdout: SplitParser {
            onRead: data => {
                root._handleCheckOutput(data);
            }
        }
        onExited: (code) => {
            if (code !== 0 && root.status === "checking") {
                root.status = "error";
                if (!root.errorMessage) {
                    root.errorMessage = I18n.tr("updates_error_network");
                }
            }
        }
    }

    // Process for applying updates
    Process {
        id: applyProc
        command: ["python3", root.projectDir + "/scripts/deloway-updater.py", "apply"]
        stdout: SplitParser {
            onRead: data => {
                root._handleApplyOutput(data);
            }
        }
        onExited: (code) => {
            if (code !== 0 && root.status === "updating") {
                root.status = "error";
                if (!root.errorMessage) {
                    root.errorMessage = I18n.tr("updates_error_apply");
                }
            }
        }
    }

    function checkForUpdates() {
        if (root.isBusy) return;
        root.status = "checking";
        root.errorMessage = "";
        checkProc.command = ["python3", root.projectDir + "/scripts/deloway-updater.py", "check", "--channel", root.channel];
        checkProc.running = true;
    }

    function applyUpdate() {
        if (root.isBusy) return;
        root.status = "updating";
        root.errorMessage = "";
        applyProc.running = true;
    }

    function _handleCheckOutput(raw) {
        if (!raw || !raw.trim()) return;
        try {
            const data = JSON.parse(raw);
            root.status = data.status || "up_to_date";
            root.commitsBehind = data.commits_behind || 0;
            if (data.current) {
                root.currentCommit = data.current.commit || "";
                root.currentVersion = data.current.version || "v2.0 OLED";
                root.currentCommitDate = data.current.date || "";
                root.currentCommitMsg = data.current.message || "";
                if (data.current.repository_url) root.repositoryUrl = data.current.repository_url;
            }
            root.changelog = data.changelog || [];
            root.errorMessage = data.error || "";
            const now = new Date();
            root.lastChecked = Qt.formatTime(now, "hh:mm AP");
        } catch (e) {
            root.status = "error";
            root.errorMessage = "Failed to parse response: " + e;
        }
    }

    function _handleApplyOutput(raw) {
        if (!raw || !raw.trim()) return;
        try {
            const data = JSON.parse(raw);
            if (data.success) {
                root.status = "success";
            } else {
                root.status = "error";
                root.errorMessage = data.error || "Update application failed";
            }
        } catch (e) {
            root.status = "error";
            root.errorMessage = "Failed to parse response: " + e;
        }
    }
}
