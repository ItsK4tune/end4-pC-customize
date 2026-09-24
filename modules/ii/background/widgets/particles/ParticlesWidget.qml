import QtQuick
import Qt5Compat.GraphicalEffects
import qs
import qs.services
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
    z: (configEntry && configEntry.layerMode === "above") ? 1000 : -500

    property bool isOverlayWindow: false
    visible: isOverlayWindow ? true : (!configEntry || configEntry.layerMode !== "window")

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

    readonly property real bassGainValue: configEntry?.bassGain ?? 1.0
    readonly property real midGainValue: configEntry?.midGain ?? 1.0
    readonly property real trebleGainValue: configEntry?.trebleGain ?? 1.0
    readonly property real windAngleValue: configEntry?.windAngle ?? 0.0
    readonly property bool clickBurstValue: configEntry?.clickBurst ?? true
    readonly property bool autoSyncWallpaperValue: configEntry?.autoSyncWallpaper ?? false
    readonly property string fpsCapValue: configEntry?.fpsCap ?? "auto"
    readonly property bool pauseFullscreenValue: configEntry?.pauseFullscreen ?? true

    readonly property bool isFullscreenActive: WM.windowList.some(w => w.fullscreen)
    readonly property bool isAnimationPaused: root.pauseFullscreenValue && root.isFullscreenActive

    property real fpsCapInterval: root.fpsCapValue === "30" ? (1.0 / 30.0) : (root.fpsCapValue === "60" ? (1.0 / 60.0) : 0.0)
    property real frameAccumulator: 0.0
    property real accumulatedTime: 0.0

    FrameAnimation {
        running: root.visible && root.opacity > 0 && !root.isAnimationPaused
        onTriggered: {
            root.frameAccumulator += frameTime;
            if (root.fpsCapInterval > 0.0 && root.frameAccumulator < root.fpsCapInterval) {
                return;
            }
            root.accumulatedTime += root.frameAccumulator * root.speedValue;
            root.frameAccumulator = 0.0;
        }
    }

    readonly property string effectiveWallpaperPath: Wallpapers.previewPath || Wallpapers.confirmedPath || Config.options?.background?.wallpaperPath || ""

    function syncPresetWithWallpaper(path) {
        if (!root.autoSyncWallpaperValue || !path || root.isOverlayWindow) return;
        const p = path.toLowerCase();
        let match = "";
        if (p.includes("snow") || p.includes("winter") || p.includes("frost") || p.includes("ice") || p.includes("blizzard")) match = "snow";
        else if (p.includes("rain") || p.includes("storm") || p.includes("drizzle") || p.includes("shower")) match = "rain";
        else if (p.includes("leaf") || p.includes("leaves") || p.includes("autumn") || p.includes("fall") || p.includes("maple")) match = "leaves";
        else if (p.includes("sakura") || p.includes("blossom") || p.includes("cherry") || p.includes("spring") || p.includes("petal") || p.includes("flower")) match = "sakura";
        else if (p.includes("firefl") || p.includes("glow") || p.includes("magical")) match = "fireflies";
        else if (p.includes("star") || p.includes("space") || p.includes("galaxy") || p.includes("nebula") || p.includes("cosmos")) match = "starfield";
        else if (p.includes("bubble") || p.includes("ocean") || p.includes("sea") || p.includes("underwater") || p.includes("aquarium")) match = "bubbles";

        if (match !== "" && configEntry && configEntry.preset !== match) {
            configEntry.preset = match;
        }
    }

    onEffectiveWallpaperPathChanged: syncPresetWithWallpaper(effectiveWallpaperPath)
    onAutoSyncWallpaperValueChanged: syncPresetWithWallpaper(effectiveWallpaperPath)
    Component.onCompleted: syncPresetWithWallpaper(effectiveWallpaperPath)

    VisualizerEngine {
        id: levelEngine
        active: root.audioReactiveValue
    }

    property real clickTime: -9999.0
    property vector2d clickPos: Qt.vector2d(-9999.0, -9999.0)

    readonly property real clickElapsed: root.accumulatedTime - root.clickTime
    readonly property real clickProgress: (root.clickElapsed >= 0.0 && root.clickElapsed <= 1.0) ? (root.clickElapsed / 1.0) : 1.0

    property real midLevel: 0.0
    property real trebleLevel: 0.0

    Connections {
        target: levelEngine
        function onFrame() {
            if (!root.audioReactiveValue) {
                root.midLevel = 0.0;
                root.trebleLevel = 0.0;
                return;
            }
            const lvls = levelEngine.levels;
            let m = 0;
            for (let i = 6; i < 22; i++) m += lvls[i];
            root.midLevel = Math.min(1.0, (m / 16.0) * 1.5);

            let tr = 0;
            for (let i = 22; i < 48; i++) tr += lvls[i];
            root.trebleLevel = Math.min(1.0, (tr / 26.0) * 2.0);
        }
    }

    readonly property real effectiveBass: root.audioReactiveValue ? Math.min(2.0, levelEngine.bass * root.bassGainValue) : 0.0
    readonly property real effectiveMid: root.audioReactiveValue ? Math.min(2.0, root.midLevel * root.midGainValue) : 0.0
    readonly property real effectiveTreble: root.audioReactiveValue ? Math.min(2.0, root.trebleLevel * root.trebleGainValue) : 0.0

    HoverHandler {
        id: hoverHandler
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
        cursorShape: Qt.ArrowCursor
    }

    TapHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
        acceptedButtons: Qt.LeftButton
        onTapped: (point) => {
            if (!root.clickBurstValue) return;
            root.clickPos = Qt.vector2d(point.position.x, point.position.y);
            root.clickTime = root.accumulatedTime;
        }
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
        bass: root.effectiveBass
        mid: root.effectiveMid
        treble: root.effectiveTreble
        windAngle: (root.windAngleValue * Math.PI) / 180.0
        clickProgress: root.clickProgress
        clickPos: root.clickPos
        mousePos: Qt.vector2d(root.smoothMouseX, root.smoothMouseY)
        primaryColor: root.effectivePrimaryColor
        secondaryColor: root.effectiveSecondaryColor
    }
}
