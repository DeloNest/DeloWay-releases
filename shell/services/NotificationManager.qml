pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../theme"

Item {
    id: root

    // Real system notifications received via NotificationServer
    property var notifications: []
    property int unreadCount: 0

    signal toastRequested(var notif)

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: notif => {
            // Track notification in Quickshell
            notif.tracked = true;

            const notifItem = {
                id: notif.id,
                appName: notif.appName || "Application",
                appIcon: notif.appIcon || "dialog-information",
                summary: notif.summary || "Notification",
                body: notif.body || "",
                timeStr: Qt.formatTime(new Date(), "hh:mm AP"),
                timestamp: Date.now(),
                notificationRef: notif
            };

            // Prepend to notifications list
            let list = root.notifications.slice();
            list.unshift(notifItem);
            if (list.length > 50) list.pop();
            root.notifications = list;
            root.unreadCount++;

            // Emit toast for popup
            root.toastRequested(notifItem);

            notif.closed.connect(reason => {
                root.removeById(notif.id);
            });
        }
    }

    function removeById(id) {
        let list = root.notifications.filter(n => n.id !== id);
        root.notifications = list;
        if (root.unreadCount > 0) root.unreadCount = Math.max(0, root.unreadCount - 1);
    }

    function dismiss(id) {
        const item = root.notifications.find(n => n.id === id);
        if (item && item.notificationRef) {
            try {
                item.notificationRef.dismiss();
            } catch (e) {
                // Ignore if already dismissed
            }
        }
        removeById(id);
    }

    function postNotification(appName, summary, body, appIcon) {
        const notifItem = {
            id: Date.now(),
            appName: appName || "DeloOS",
            appIcon: appIcon || "software-store",
            summary: summary || "Notification",
            body: body || "",
            timeStr: Qt.formatTime(new Date(), "hh:mm AP"),
            timestamp: Date.now(),
            notificationRef: null
        };
        let list = root.notifications.slice();
        list.unshift(notifItem);
        if (list.length > 50) list.pop();
        root.notifications = list;
        root.unreadCount++;
        root.toastRequested(notifItem);
    }

    function postScreenshotNotification(filePath) {
        const notifItem = {
            id: Date.now(),
            appName: "Screenshot Tool",
            appIcon: "camera-photo",
            summary: "Screenshot Captured",
            body: "Image copied to clipboard and saved to disk.",
            imagePath: filePath,
            isScreenshot: true,
            timeStr: Qt.formatTime(new Date(), "hh:mm AP"),
            timestamp: Date.now(),
            notificationRef: null
        };
        let list = root.notifications.slice();
        list.unshift(notifItem);
        if (list.length > 50) list.pop();
        root.notifications = list;
        root.unreadCount++;
        root.toastRequested(notifItem);
    }

    function clearAll() {
        for (let i = 0; i < root.notifications.length; i++) {
            const item = root.notifications[i];
            if (item && item.notificationRef) {
                try { item.notificationRef.dismiss(); } catch (e) {}
            }
        }
        root.notifications = [];
        root.unreadCount = 0;
    }
}
