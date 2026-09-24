import QtQuick
import Qt5Compat.GraphicalEffects
import qs
import qs.modules.common
import qs.modules.ii.background.widgets.visualizer

Item {
    id: root

    required property int screenWidth
    required property int screenHeight
    required property int scaledScreenWidth
    required property int scaledScreenHeight
    required property real wallpaperScale
    property Item wallpaperItem: null

    readonly property var configEntry: Config.options.background.widgets.particles

    implicitWidth: screenWidth
    implicitHeight: screenHeight
    width: screenWidth
    height: screenHeight

    x: 0
    y: 0
    z: (configEntry?.layerMode ?? "below") === "above" ? 1000 : -500

    readonly property string preset: configEntry?.preset ?? "sakura"
    readonly property real speedValue: configEntry?.speed ?? 1.0
    readonly property real densityValue: configEntry?.density ?? 1.0
    readonly property real particleSizeValue: configEntry?.particleSize ?? 1.0
    readonly property real particleAlphaValue: configEntry?.particleAlpha ?? 0.8
    readonly property real mouseRadiusValue: configEntry?.mouseRadius ?? 180.0
    readonly property real mouseStrengthValue: configEntry?.mouseStrength ?? 1.0
    readonly property real backgroundDimAlphaValue: configEntry?.backgroundDimAlpha ?? 0.0
    readonly property string backgroundDimColorValue: configEntry?.backgroundDimColor ?? "#000000"
    readonly property string colorModeValue: configEntry?.colorMode ?? "preset"
    readonly property string customColorValue: configEntry?.customColor ?? "#ffb7c5"
    readonly property real particleBlurValue: configEntry?.particleBlur ?? 0.0
    readonly property real backgroundBlurValue: configEntry?.backgroundBlur ?? 0
    readonly property bool audioReactiveValue: configEntry?.audioReactive ?? false

    readonly property color effectivePrimaryColor: {
        if (root.colorModeValue === "theme") return Appearance.colors.colPrimary;
        if (root.colorModeValue === "custom") return root.customColorValue;
        return Qt.rgba(0, 0, 0, 0);
    }

    readonly property color effectiveSecondaryColor: {
        if (root.colorModeValue === "theme") return Appearance.colors.colSecondary;
        if (root.colorModeValue === "custom") return root.customColorValue;
        return Qt.rgba(0, 0, 0, 0);
    }

    readonly property real mouseModeValue: {
        switch (configEntry?.mouseInteraction ?? "repel") {
            case "repel": return 1.0;
            case "attract": return 2.0;
            case "glow": return 3.0;
            case "swirl": return 4.0;
            default: return 0.0;
        }
    }

    property real accumulatedTime: 0.0

    FrameAnimation {
        running: root.visible && root.opacity > 0
        onTriggered: {
            root.accumulatedTime += frameTime * root.speedValue;
        }
    }

    VisualizerEngine {
        id: levelEngine
        active: root.audioReactiveValue
    }

    Loader {
        anchors.fill: parent
        z: -700
        active: root.backgroundBlurValue > 0 && root.wallpaperItem !== null
        sourceComponent: FastBlur {
            anchors.fill: parent
            source: root.wallpaperItem
            radius: root.backgroundBlurValue
        }
    }

    Rectangle {
        id: bgDimLayer
        anchors.fill: parent
        z: -600
        color: root.backgroundDimColorValue
        opacity: root.backgroundDimAlphaValue
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
    }

    HoverHandler {
        id: hoverHandler
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
        cursorShape: Qt.ArrowCursor
    }

    property real smoothMouseX: hoverHandler.hovered ? hoverHandler.point.position.x : -9999.0
    property real smoothMouseY: hoverHandler.hovered ? hoverHandler.point.position.y : -9999.0

    Behavior on smoothMouseX {
        NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
    }
    Behavior on smoothMouseY {
        NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
    }

    ParticlesShader {
        id: shaderEffect
        anchors.fill: parent
        style: root.preset
        time: root.accumulatedTime
        speed: 1.0
        density: root.densityValue
        particleSize: root.particleSizeValue
        particleAlpha: root.particleAlphaValue
        particleBlur: root.particleBlurValue
        mouseRadius: root.mouseRadiusValue
        mouseStrength: root.mouseStrengthValue
        mouseMode: root.mouseModeValue
        bass: root.audioReactiveValue ? levelEngine.bass : 0.0
        mousePos: Qt.vector2d(root.smoothMouseX, root.smoothMouseY)
        primaryColor: root.effectivePrimaryColor
        secondaryColor: root.effectiveSecondaryColor
    }
}
