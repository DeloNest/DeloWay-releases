import QtQuick
import "../../theme"

// TrendChart — right-aligned rolling history (newest sample on the right).
// Series are separated by luminance and weight only (monochrome identity):
//   { data: [..], alpha: 0..1, width: px, fill: bool }
Canvas {
    id: root

    property var series: []
    property int samples: 30
    property real maxValue: 1.0      // 0 = auto-scale to the largest sample
    property bool gridLines: true
    property bool active: true

    LayoutMirroring.enabled: false
    antialiasing: true

    onSeriesChanged: if (active) requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onActiveChanged: if (active) requestPaint()

    Connections {
        target: Theme
        function onModeChanged() { root.requestPaint(); }
    }

    function tone(a) {
        const c = Theme.notchText;
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const w = width, h = height;
        if (w <= 0 || h <= 0) return;

        if (gridLines) {
            ctx.strokeStyle = tone(0.08);
            ctx.lineWidth = 1;
            for (const f of [0.5]) {
                const y = Math.round(h * f) + 0.5;
                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke();
            }
        }

        let top = maxValue;
        if (top <= 0) {
            top = 1;
            for (const s of series) for (const v of (s.data || [])) top = Math.max(top, v);
            top *= 1.15;
        }

        const step = w / Math.max(1, samples - 1);
        const pad = 2;

        for (const s of series) {
            const d = s.data || [];
            const n = Math.min(d.length, samples);
            if (n < 2) continue;
            const off = d.length - n;
            const px = i => w - (n - 1 - i) * step;
            const py = i => h - pad - Math.max(0, Math.min(1, d[off + i] / top)) * (h - pad * 2);

            ctx.beginPath();
            ctx.moveTo(px(0), py(0));
            for (let i = 1; i < n; i++) ctx.lineTo(px(i), py(i));
            ctx.lineJoin = "round";
            ctx.lineCap = "round";
            ctx.lineWidth = s.width || 1.5;
            ctx.strokeStyle = tone(s.alpha !== undefined ? s.alpha : 1.0);
            ctx.stroke();

            if (s.fill) {
                ctx.lineTo(px(n - 1), h);
                ctx.lineTo(px(0), h);
                ctx.closePath();
                const g = ctx.createLinearGradient(0, 0, 0, h);
                g.addColorStop(0, tone(0.18));
                g.addColorStop(1, tone(0.0));
                ctx.fillStyle = g;
                ctx.fill();
            }
        }
    }
}
