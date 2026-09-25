import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Effects

Canvas { // Visualizer
    id: root
    property list<var> points
    property real maxVisualizerValue: 1000
    property int smoothing: 2
    property bool live: true
    property color color: Appearance.m3colors.m3primary

    readonly property bool isVisualizerActive: root.visible && root.live && root.opacity > 0 && root.width > 0 && root.height > 0
    property bool paintPending: false

    onPointsChanged: {
        if (!root.isVisualizerActive) return;
        // Cava can emit frames much faster than we need to redraw + re-blur this canvas.
        // Coalesce bursts to the throttle's rate instead of repainting (and re-rendering
        // the blur layer) on every single frame, which is what was driving unbounded
        // memory growth while a track played.
        if (!paintThrottle.running) {
            paintThrottle.start();
            root.requestPaint();
        } else {
            root.paintPending = true;
        }
    }

    onIsVisualizerActiveChanged: {
        if (!root.isVisualizerActive) {
            paintThrottle.stop();
            root.paintPending = false;
        }
    }

    Timer {
        id: paintThrottle
        interval: 33 // ~30fps cap
        onTriggered: {
            if (root.paintPending && root.isVisualizerActive) {
                root.paintPending = false;
                root.requestPaint();
                paintThrottle.start();
            } else {
                root.paintPending = false;
            }
        }
    }

    anchors.fill: parent
    onPaint: {
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        if (!root.isVisualizerActive) return;

        var points = root.points;
        var maxVal = root.maxVisualizerValue || 1;
        var h = height;
        var w = width;
        var n = points.length;
        if (n < 2) return;

        // Smoothing: simple moving average (optional)
        // Local array (not a QML property) so we're not marshalling through the
        // property system and firing change notifications on every repaint.
        var smoothWindow = root.smoothing; // adjust for more/less smoothing
        var smoothPoints = [];
        for (var i = 0; i < n; ++i) {
            var sum = 0, count = 0;
            for (var j = -smoothWindow; j <= smoothWindow; ++j) {
                var idx = Math.max(0, Math.min(n - 1, i + j));
                sum += points[idx];
                count++;
            }
            smoothPoints.push(sum / count);
        }
        if (!root.live) smoothPoints.fill(0); // If not playing, show no points

        ctx.beginPath();
        ctx.moveTo(0, h);
        for (var i = 0; i < n; ++i) {
            var x = i * w / (n - 1);
            var y = h - (smoothPoints[i] / maxVal) * h;
            ctx.lineTo(x, y);
        }
        ctx.lineTo(w, h);
        ctx.closePath();

        ctx.fillStyle = Qt.rgba(
            root.color.r,
            root.color.g,
            root.color.b,
            0.15
        );
        ctx.fill();
    }

    layer.enabled: root.isVisualizerActive
    layer.effect: MultiEffect { // Blur a bit to obscure away the points
        source: root
        saturation: 0.2
        blurEnabled: true
        blurMax: 7
        blur: 1
    }
}