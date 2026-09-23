pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

// TimeKeeperService — reminders, alarm clock and countdown timer for the Time Capsule.
//
// Scheduling model: there is NO always-on polling. A single-shot `scheduler` Timer is
// armed for the earliest due moment (alarm, snooze, reminder or timer end), capped at
// 60s so wall-clock jumps / suspend are corrected within a minute. The UI-facing 1Hz
// tick only runs while a countdown is live.
//
// State persists to ~/.local/state/deloway/timekeeper.json (atomic writes).
Item {
    id: root

    // ── Public state ─────────────────────────────────────────────────────
    property var events: []            // [{ id, date: "YYYY-MM-DD", time: "HH:MM" | "", title, notified }]

    property bool alarmEnabled: false
    property int alarmHour: 7
    property int alarmMinute: 0
    property bool alarmRepeatDaily: true
    property real nextAlarmAt: 0       // epoch ms of the next ring (0 = none)
    property bool alarmRinging: false
    property real snoozeAt: 0

    property int timerTotalSec: 300
    property bool timerRunning: false
    property bool timerFinished: false
    property real timerEndAt: 0        // epoch ms while running
    property int timerPausedRemaining: 300

    property real nowMs: Date.now()
    readonly property int timerRemainingSec: root.timerRunning
        ? Math.max(0, Math.ceil((root.timerEndAt - root.nowMs) / 1000))
        : root.timerPausedRemaining
    readonly property bool timerActive: root.timerRunning || (root.timerPausedRemaining !== root.timerTotalSec && !root.timerFinished)

    readonly property int snoozeMinutes: 5
    readonly property string soundAlarm: "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
    readonly property string soundDone: "/usr/share/sounds/freedesktop/stereo/complete.oga"
    readonly property string soundReminder: "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga"

    // ── Formatting / date helpers ────────────────────────────────────────
    function pad2(n) { return (n < 10 ? "0" : "") + n; }
    function dateKey(d) { return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate()); }
    function digits(n) {
        const s = String(n);
        return (I18n.isRTL && ConfigManager.timeCapsuleArabicDigits)
               ? s.replace(/\d/g, d => "٠١٢٣٤٥٦٧٨٩"[d]) : s;
    }
    function formatClock(sec) {
        sec = Math.max(0, Math.round(sec));
        const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60;
        return h > 0 ? h + ":" + pad2(m) + ":" + pad2(s) : pad2(m) + ":" + pad2(s);
    }
    function formatIn(ms) {
        const mins = Math.max(0, Math.round(ms / 60000));
        const h = Math.floor(mins / 60), m = mins % 60;
        const U = I18n.isRTL ? { h: "س", m: "د" } : { h: "h", m: "m" };
        return h > 0 ? h + U.h + " " + m + U.m : m + U.m;
    }
    function parseTime(t) {
        const m = /^\s*(\d{1,2})[:.](\d{2})\s*$/.exec(t || "");
        if (!m) return null;
        const h = parseInt(m[1]), mi = parseInt(m[2]);
        return (h < 24 && mi < 60) ? pad2(h) + ":" + pad2(mi) : null;
    }
    function eventAt(ev) {
        if (!ev.time) return 0;
        const p = ev.date.split("-"), t = ev.time.split(":");
        return new Date(+p[0], +p[1] - 1, +p[2], +t[0], +t[1], 0).getTime();
    }

    // ── Events / reminders ───────────────────────────────────────────────
    function eventsFor(key) {
        return root.events.filter(e => e.date === key)
                          .sort((a, b) => (a.time || "99:99").localeCompare(b.time || "99:99"));
    }
    function hasEvents(key) {
        for (const e of root.events) if (e.date === key) return true;
        return false;
    }
    function addEvent(key, title, time) {
        const clean = (title || "").trim();
        if (!clean) return false;
        const t = time ? root.parseTime(time) : "";
        if (time && t === null) return false;
        const ev = { id: String(Date.now()) + Math.floor(Math.random() * 1000), date: key, time: t || "", title: clean, notified: false };
        ev.notified = ev.time !== "" && root.eventAt(ev) <= Date.now();   // don't fire for the past
        root.events = root.events.concat([ev]);
        root.persist();
        root.reschedule();
        return true;
    }
    function removeEvent(id) {
        root.events = root.events.filter(e => e.id !== id);
        root.persist();
        root.reschedule();
    }

    // ── Alarm ────────────────────────────────────────────────────────────
    function computeNextAlarm(afterMs) {
        const base = new Date(afterMs);
        const t = new Date(base.getFullYear(), base.getMonth(), base.getDate(), root.alarmHour, root.alarmMinute, 0);
        if (t.getTime() <= afterMs) t.setDate(t.getDate() + 1);
        return t.getTime();
    }
    function setAlarmTime(h, m) {
        root.alarmHour = ((h % 24) + 24) % 24;
        root.alarmMinute = ((m % 60) + 60) % 60;
        if (root.alarmEnabled) root.nextAlarmAt = root.computeNextAlarm(Date.now());
        root.persist();
        root.reschedule();
    }
    function nudgeAlarm(deltaMinutes) {
        const total = (root.alarmHour * 60 + root.alarmMinute + deltaMinutes + 1440) % 1440;
        root.setAlarmTime(Math.floor(total / 60), total % 60);
    }
    function setAlarmEnabled(on) {
        root.alarmEnabled = on;
        root.nextAlarmAt = on ? root.computeNextAlarm(Date.now()) : 0;
        if (!on) { root.snoozeAt = 0; root.stopRinging(); }
        root.persist();
        root.reschedule();
    }
    function setAlarmRepeat(on) {
        root.alarmRepeatDaily = on;
        root.persist();
    }
    function ringAlarm() {
        root.alarmRinging = true;
        root.notify(I18n.tr("tk_alarm", "Alarm"), root.pad2(root.alarmHour) + ":" + root.pad2(root.alarmMinute), "alarm-symbolic", "critical");
        alarmSound.running = true;
        ringTimeout.restart();
        // Surface the Stop / Snooze controls wherever the user is.
        ShellState.timeCapsuleTab = 0;
        ShellState.openTimeCapsule();
    }
    function stopRinging() {
        root.alarmRinging = false;
        alarmSound.running = false;
        ringTimeout.stop();
    }
    function snooze() {
        root.stopRinging();
        root.snoozeAt = Date.now() + root.snoozeMinutes * 60000;
        root.reschedule();
    }
    function dismissAlarm() {
        root.stopRinging();
        root.snoozeAt = 0;
        root.reschedule();
    }

    // ── Timer ────────────────────────────────────────────────────────────
    function setTimerMinutes(min) {
        if (root.timerRunning) return;
        root.timerTotalSec = Math.max(60, Math.min(99 * 60, Math.round(min * 60)));
        root.timerPausedRemaining = root.timerTotalSec;
        root.timerFinished = false;
    }
    function nudgeTimer(deltaMinutes) {
        if (root.timerRunning) return;
        root.setTimerMinutes(Math.round(root.timerTotalSec / 60) + deltaMinutes);
    }
    function startTimer() {
        if (root.timerRunning) return;
        if (root.timerFinished || root.timerPausedRemaining <= 0) root.timerPausedRemaining = root.timerTotalSec;
        root.timerFinished = false;
        root.nowMs = Date.now();
        root.timerEndAt = root.nowMs + root.timerPausedRemaining * 1000;
        root.timerRunning = true;
        root.reschedule();
    }
    function pauseTimer() {
        if (!root.timerRunning) return;
        root.nowMs = Date.now();
        root.timerPausedRemaining = root.timerRemainingSec;
        root.timerRunning = false;
        root.reschedule();
    }
    function toggleTimer() { root.timerRunning ? root.pauseTimer() : root.startTimer(); }
    function resetTimer() {
        root.timerRunning = false;
        root.timerFinished = false;
        root.timerPausedRemaining = root.timerTotalSec;
        root.reschedule();
    }

    // ── Scheduler ────────────────────────────────────────────────────────
    function reschedule() {
        const now = Date.now();
        let due = now + 60000;
        if (root.alarmEnabled && root.nextAlarmAt > 0) due = Math.min(due, root.nextAlarmAt);
        if (root.snoozeAt > 0) due = Math.min(due, root.snoozeAt);
        if (root.timerRunning) due = Math.min(due, root.timerEndAt);
        for (const e of root.events) {
            if (!e.notified && e.time) due = Math.min(due, root.eventAt(e));
        }
        scheduler.interval = Math.max(50, due - now);
        scheduler.restart();
    }

    function processDue() {
        const now = Date.now();
        root.nowMs = now;

        if (root.timerRunning && now >= root.timerEndAt - 50) {
            root.timerRunning = false;
            root.timerPausedRemaining = 0;
            root.timerFinished = true;
            root.notify(I18n.tr("tk_timer", "Timer"), I18n.tr("tk_timer_done", "Time's up"), "alarm-symbolic");
            root.play(root.soundDone);
        }

        if (root.alarmEnabled && root.nextAlarmAt > 0 && now >= root.nextAlarmAt - 500) {
            if (root.alarmRepeatDaily) {
                root.nextAlarmAt = root.computeNextAlarm(now + 60000);
            } else {
                root.alarmEnabled = false;
                root.nextAlarmAt = 0;
            }
            root.persist();
            root.ringAlarm();
        }

        if (root.snoozeAt > 0 && now >= root.snoozeAt - 500) {
            root.snoozeAt = 0;
            root.ringAlarm();
        }

        let changed = false;
        const evs = root.events.map(e => Object.assign({}, e));
        for (const e of evs) {
            if (!e.notified && e.time && now >= root.eventAt(e) - 500) {
                e.notified = true;
                changed = true;
                // Only announce reminders that are actually current (not stale after downtime).
                if (now - root.eventAt(e) < 10 * 60000) {
                    root.notify(I18n.tr("tk_reminder", "Reminder"), e.time + " · " + e.title, "x-office-calendar-symbolic");
                    root.play(root.soundReminder);
                }
            }
        }
        if (changed) { root.events = evs; root.persist(); }

        root.reschedule();
    }

    Timer {
        id: scheduler
        repeat: false
        onTriggered: root.processDue()
    }

    // Live countdown tick: only while a timer is actually running.
    Timer {
        interval: 250
        repeat: true
        running: root.timerRunning
        onTriggered: root.nowMs = Date.now()
    }

    // Ringing auto-stops after one minute.
    Timer {
        id: ringTimeout
        interval: 60000
        onTriggered: root.stopRinging()
    }

    // ── Side effects ─────────────────────────────────────────────────────
    Process { id: notifyProc }
    Process { id: soundProc }
    Process {
        id: alarmSound
        command: ["bash", "-c", "for i in $(seq 1 40); do pw-play '" + root.soundAlarm + "' 2>/dev/null || paplay '" + root.soundAlarm + "'; sleep 0.3; done"]
    }

    function notify(title, body, icon, urgency) {
        notifyProc.exec(["notify-send", "-a", "DeloWay", "-i", icon || "alarm-symbolic",
                         "-u", urgency || "normal", title, body]);
    }
    function play(file) {
        soundProc.exec(["bash", "-c", "pw-play '" + file + "' 2>/dev/null || paplay '" + file + "'"]);
    }

    // ── Persistence ──────────────────────────────────────────────────────
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/deloway"
    property bool _loaded: false

    Process {
        id: mkdirProc
        command: ["mkdir", "-p", root.stateDir]
        running: true
    }

    FileView {
        id: store
        path: root.stateDir + "/timekeeper.json"
        preload: true
        atomicWrites: true
        printErrors: false
        onLoaded: root.load()
        onLoadFailed: { root._loaded = true; root.reschedule(); }
    }

    function load() {
        try {
            const d = JSON.parse(store.text() || "{}");
            root.events = Array.isArray(d.events) ? d.events : [];
            if (d.alarm) {
                root.alarmHour = d.alarm.hour ?? 7;
                root.alarmMinute = d.alarm.minute ?? 0;
                root.alarmRepeatDaily = d.alarm.repeatDaily ?? true;
                root.alarmEnabled = !!d.alarm.enabled;
            }
            if (d.timerTotalSec) { root.timerTotalSec = d.timerTotalSec; root.timerPausedRemaining = d.timerTotalSec; }
        } catch (e) {
            root.events = [];
        }
        // Alarms missed while the shell was down are skipped, not fired late.
        root.nextAlarmAt = root.alarmEnabled ? root.computeNextAlarm(Date.now()) : 0;
        root._loaded = true;
        root.processDue();
    }

    function persist() {
        if (!root._loaded) return;
        // Keep the file bounded: drop events older than 60 days.
        const cutoff = root.dateKey(new Date(Date.now() - 60 * 86400000));
        const kept = root.events.filter(e => e.date >= cutoff);
        store.setText(JSON.stringify({
            events: kept,
            alarm: { enabled: root.alarmEnabled, hour: root.alarmHour, minute: root.alarmMinute, repeatDaily: root.alarmRepeatDaily },
            timerTotalSec: root.timerTotalSec
        }, null, 2));
    }

    onTimerTotalSecChanged: persist()
}
