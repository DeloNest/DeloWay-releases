pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Io
import "../theme"

// NotificationManager — single source of truth for notifications.
// Every surface (Notch banner, Notch history, fallback toast) renders the SAME
// normalised item, so text sanitising, BiDi handling and time formatting live here once.
Item {
    id: root

    property var notifications: []
    property int unreadCount: 0

    signal toastRequested(var notif)

    // Coarse clock for relative timestamps ("now", "5m"). Ticks only while history exists.
    property real now: Date.now()
    Timer {
        interval: 30000
        repeat: true
        running: root.notifications.length > 0
        onTriggered: root.now = Date.now()
    }

    // ── Text normalisation ───────────────────────────────────────────────
    // Bodies may carry markup (bodyMarkupSupported). Rich text disables eliding and
    // mixes font metrics, so everything is rendered as clean PlainText.
    function plainText(s, singleLine) {
        if (!s) return "";
        let t = String(s)
            .replace(/<br\s*\/?>/gi, "\n")
            .replace(/<[^>]+>/g, "")
            .replace(/&nbsp;/g, " ")
            .replace(/&lt;/g, "<").replace(/&gt;/g, ">")
            .replace(/&quot;/g, "\"").replace(/&#0*39;|&apos;/g, "'")
            .replace(/&amp;/g, "&")
            .replace(/[ \t]+/g, " ")
            .replace(/\n{3,}/g, "\n\n")
            .trim();
        if (singleLine) t = t.replace(/\s*\n\s*/g, "  ");
        return t;
    }

    // Paragraph direction: any Arabic/Hebrew letter makes the paragraph RTL (RLM prefix),
    // so strings that merely *start* with a filename, number or Latin brand still read
    // right-to-left. Pure Latin text keeps its natural LTR order.
    readonly property var rtlPattern: /[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]/
    function isRtlText(s) { return root.rtlPattern.test(s || ""); }
    function bidi(s) {
        if (!s) return "";
        return root.isRtlText(s) ? "\u200F" + s : s;
    }

    // ── Localised time ───────────────────────────────────────────────────
    function clockLabel(ts) {
        const d = new Date(ts);
        return I18n.clockText(d, false);   // explicit 12h digits ("h:mm" alone stays 24h in Qt)
    }
    function timeLabel(ts) {
        if (!ts) return "";
        const diff = Math.max(0, root.now - ts);
        const rtl = I18n.isRTL;
        if (diff < 60000) return rtl ? "الآن" : "now";
        if (diff < 3600000) {
            const m = Math.floor(diff / 60000);
            return rtl ? "منذ " + m + " د" : m + "m";
        }
        const d = new Date(ts), today = new Date(root.now);
        if (d.toDateString() === today.toDateString()) return root.clockLabel(ts);
        const y = new Date(root.now - 86400000);
        if (d.toDateString() === y.toDateString()) return (rtl ? "أمس " : "Yesterday ") + root.clockLabel(ts);
        return Qt.formatDate(d, "d/M");
    }

    // ── Item factory ─────────────────────────────────────────────────────
    function makeItem(fields) {
        const ts = Date.now();
        return Object.assign({
            id: ts,
            appName: "",
            iconSource: "",
            summary: "",
            body: "",
            urgency: 1,           // 0 low · 1 normal · 2 critical
            imagePath: "",
            isScreenshot: false,
            timestamp: ts,
            timeStr: root.clockLabel(ts),   // back-compat for older consumers
            notificationRef: null
        }, fields);
    }

    // "Notification Sounds" (Settings → Notifications): short chime, silent in DND.
    readonly property string chimePath: "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga"
    Process { id: chimeProc }
    function chime(item) {
        if (!ConfigManager.notificationsSound || ConfigManager.notificationsDnd) return;
        if (item && item.urgency === 0) return;            // low-urgency stays silent
        if (chimeProc.running) return;                     // bursts → one chime
        chimeProc.exec(["sh", "-c", "pw-play '" + root.chimePath + "' 2>/dev/null || paplay '" + root.chimePath + "'"]);
    }

    function push(item) {
        root.now = Date.now();
        root.chime(item);
        const list = root.notifications.slice();
        list.unshift(item);
        if (list.length > 50) list.pop();
        root.notifications = list;
        root.unreadCount++;
        root.toastRequested(item);
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: notif => {
            notif.tracked = true;

            root.push(root.makeItem({
                id: notif.id,
                appName: root.plainText(notif.appName, true),
                // image hint (avatar / cover / icon name) wins over app_icon, then the desktop entry
                iconSource: notif.image || notif.appIcon || notif.desktopEntry || "",
                summary: root.plainText(notif.summary, true),
                body: root.plainText(notif.body, false),
                urgency: notif.urgency === NotificationUrgency.Critical ? 2
                         : (notif.urgency === NotificationUrgency.Low ? 0 : 1),
                notificationRef: notif
            }));

            notif.closed.connect(reason => root.removeById(notif.id));
        }
    }

    function removeById(id) {
        const before = root.notifications.length;
        root.notifications = root.notifications.filter(n => n.id !== id);
        if (root.notifications.length < before && root.unreadCount > 0)
            root.unreadCount = Math.max(0, root.unreadCount - 1);
    }

    function dismiss(id) {
        const item = root.notifications.find(n => n.id === id);
        if (item && item.notificationRef) {
            try { item.notificationRef.dismiss(); } catch (e) {}
        }
        root.removeById(id);
    }

    function postNotification(appName, summary, body, appIcon) {
        root.push(root.makeItem({
            appName: appName || "DeloOS",
            iconSource: appIcon || "",
            summary: summary || "",
            body: root.plainText(body, false)
        }));
    }

    function postScreenshotNotification(filePath) {
        root.push(root.makeItem({
            appName: I18n.isRTL ? "لقطة الشاشة" : "Screenshot",
            iconSource: "camera-photo",
            summary: I18n.isRTL ? "تم التقاط لقطة الشاشة" : "Screenshot captured",
            body: I18n.isRTL ? "نُسخت إلى الحافظة وحُفظت على القرص" : "Copied to clipboard and saved to disk",
            imagePath: filePath,
            isScreenshot: true
        }));
    }

    function clearAll() {
        for (const item of root.notifications) {
            if (item && item.notificationRef) {
                try { item.notificationRef.dismiss(); } catch (e) {}
            }
        }
        root.notifications = [];
        root.unreadCount = 0;
    }
}
