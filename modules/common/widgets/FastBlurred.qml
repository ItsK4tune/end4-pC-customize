import QtQuick
import Qt5Compat.GraphicalEffects
import qs.modules.common

Item {
    id: root
    required property Item blurSource
    property Item sharedBlurSource: null
    property real cardRadius: 30
    property color tint: "white"
    property real tintOpacity: 0.15
    property real blurRadius: Config.options.background.widgets.blurRadius ?? 32
    property real trackX: 0
    property real trackY: 0

    readonly property Item effectiveSharedBlur: root.sharedBlurSource ?? root.blurSource?.sharedBlurTexture ?? null
    readonly property bool useSharedBlur: (effectiveSharedBlur !== null) && (Config.options.background.widgets.useSharedBlur ?? true)

    readonly property real oversample: blurRadius * 1.5

    readonly property bool isEffectActive: root.visible && root.opacity > 0 && root.width > 0 && root.height > 0 && root.blurSource !== null

    layer.enabled: root.isEffectActive
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: root.width; height: root.height
            radius: root.cardRadius
        }
    }

    // High performance Shared Desktop Blur Pipeline (Dual-Kawase pass, 0 extra GPU blur passes)
    ShaderEffectSource {
        id: sharedSourceCrop
        anchors.fill: parent
        visible: root.isEffectActive && root.useSharedBlur
        sourceItem: root.useSharedBlur ? root.effectiveSharedBlur : null
        sourceRect: {
            if (!root.isEffectActive || !root.effectiveSharedBlur) return Qt.rect(0, 0, 0, 0)
            var _fx = root.trackX
            var _fy = root.trackY
            var pt = root.mapToItem(root.effectiveSharedBlur, 0, 0)
            return Qt.rect(pt.x, pt.y, root.width, root.height)
        }
        hideSource: false
        smooth: true
        live: root.effectiveSharedBlur?.isDynamic ?? false
    }

    // Fallback local FastBlur path (used when shared blur is unavailable)
    FastBlur {
        id: blur
        x: -root.oversample
        y: -root.oversample
        width: root.width + root.oversample * 2
        height: root.height + root.oversample * 2
        radius: root.blurRadius
        visible: root.isEffectActive && !root.useSharedBlur
        source: (root.isEffectActive && !root.useSharedBlur) ? shaderSource : null

        ShaderEffectSource {
            id: shaderSource
            sourceItem: (root.isEffectActive && !root.useSharedBlur) ? root.blurSource : null
            sourceRect: {
                if (!root.isEffectActive || root.useSharedBlur) return Qt.rect(0, 0, 0, 0)
                var _fx = root.trackX
                var _fy = root.trackY
                var pt = root.mapToItem(root.blurSource, -root.oversample, -root.oversample)
                return Qt.rect(pt.x, pt.y, blur.width, blur.height)
            }
            hideSource: false
            live: root.isEffectActive && !root.useSharedBlur
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.cardRadius
        color: root.tint
        opacity: root.tintOpacity
    }
}