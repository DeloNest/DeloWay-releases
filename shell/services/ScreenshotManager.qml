pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: root

    property bool isCapturing: false
    property string lastScreenshotPath: ""

    signal screenshotSaved(string filePath)

    Process {
        id: captureProcess
        stdout: SplitParser {
            onRead: function(data) {
                const line = data.trim();
                if (line.length > 0 && line.startsWith("/")) {
                    root.lastScreenshotPath = line;
                    root.screenshotSaved(line);
                    NotificationManager.postScreenshotNotification(line);
                }
            }
        }
        onExited: {
            root.isCapturing = false;
        }
    }

    function captureArea() {
        if (root.isCapturing) return;
        root.isCapturing = true;
        captureProcess.exec([ConfigManager.projectDir + "/scripts/screenshot.sh", "area"]);
    }

    function captureWindow() {
        if (root.isCapturing) return;
        root.isCapturing = true;
        captureProcess.exec([ConfigManager.projectDir + "/scripts/screenshot.sh", "window"]);
    }

    function captureFullScreen() {
        if (root.isCapturing) return;
        root.isCapturing = true;
        captureProcess.exec([ConfigManager.projectDir + "/scripts/screenshot.sh", "full"]);
    }
}
