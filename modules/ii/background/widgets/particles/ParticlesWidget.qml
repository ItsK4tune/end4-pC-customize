import QtQuick
import Qt5Compat.GraphicalEffects
import qs
import qs.services
import qs.modules.common
import qs.modules.ii.background.widgets.visualizer
import Quickshell.Hyprland

Item {
    id: root

    property var screen: null
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

    readonly property vector4d effectivePrimaryVec: {
        const c = root.effectivePrimaryColor;
        return Qt.vector4d(c.r, c.g, c.b, c.a);
    }

    readonly property vector4d effectiveSecondaryVec: {
        const c = root.effectiveSecondaryColor;
        return Qt.vector4d(c.r, c.g, c.b, c.a);
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
    readonly property string pauseModeValue: configEntry?.pauseMode ?? ((configEntry?.pauseFullscreen ?? true) ? "fullscreen" : "none")

    readonly property var effectiveScreen: root.screen ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
    readonly property string monitorName: root.effectiveScreen?.name ?? ""

    property int stateRevision: 0

    function notifyStateChanged() {
        root.stateRevision++;
    }

    Connections {
        target: Hyprland.workspaces
        enabled: WM.compositor === "hyprland"
        function onValuesChanged() { root.notifyStateChanged(); }
    }

    Connections {
        target: Hyprland
        enabled: WM.compositor === "hyprland"
        function onFocusedWorkspaceChanged() { root.notifyStateChanged(); }
        function onFocusedMonitorChanged() { root.notifyStateChanged(); }
    }

    Connections {
        target: HyprlandData
        enabled: WM.compositor === "hyprland"
        function onWindowListChanged() { root.notifyStateChanged(); }
        function onWorkspacesChanged() { root.notifyStateChanged(); }
        function onActiveWorkspaceChanged() { root.notifyStateChanged(); }
    }

    Connections {
        target: WM
        function onWindowListChanged() { root.notifyStateChanged(); }
        function onWorkspacesChanged() { root.notifyStateChanged(); }
        function onActiveWorkspaceChanged() { root.notifyStateChanged(); }
    }

    readonly property bool isFullscreenActive: {
        root.stateRevision;
        if (WM.compositor === "hyprland") {
            const monName = root.monitorName;
            const wsList = Hyprland.workspaces?.values || [];
            const matchingWs = wsList.filter(ws => ws && (!monName || (ws.monitor && ws.monitor.name === monName)));
            return matchingWs.some(ws => ws.active && (
                ws.hasfullscreen
                || (ws.toplevels?.values?.some(w => w.wayland?.fullscreen))
            ));
        }
        return WM.fullscreenOnMonitor(root.monitorName);
    }

    readonly property bool hasWindowsOnWorkspace: {
        root.stateRevision;
        if (WM.compositor === "hyprland") {
            const monName = root.monitorName;
            const wsList = Hyprland.workspaces?.values || [];
            const matchingWs = wsList.filter(ws => ws && (!monName || (ws.monitor && ws.monitor.name === monName)));
            const activeWs = matchingWs.find(ws => ws.active);
            if (activeWs) {
                if (activeWs.toplevels?.values?.length > 0) return true;
                if (activeWs.windows !== undefined) return activeWs.windows > 0;
            }
            const activeId = Hyprland.focusedWorkspace?.id ?? HyprlandData.activeWorkspace?.id ?? WM.activeWorkspace?.id;
            if (activeId !== undefined && activeId !== null) {
                const wsById = wsList.find(ws => ws && ws.id === activeId);
                if (wsById) {
                    if (wsById.toplevels?.values?.length > 0) return true;
                    if (wsById.windows !== undefined) return wsById.windows > 0;
                }
                const rawWinList = HyprlandData.windowList || [];
                return rawWinList.some(w => w?.workspace?.id === activeId && !w.hidden);
            }
            return false;
        }
        return WM.hasWindowsOnActiveWorkspace(root.monitorName);
    }

    readonly property bool isAnimationPaused: {
        if (root.pauseModeValue === "hasWindows") return root.hasWindowsOnWorkspace || root.isFullscreenActive;
        if (root.pauseModeValue === "fullscreen") return root.isFullscreenActive;
        return false;
    }

    Connections {
        target: GlobalStates
        function onDesktopClicked(x, y) {
            root.triggerClickBurst(x, y);
        }
    }

    property real fpsCapInterval: root.fpsCapValue === "30" ? (1.0 / 30.0) : (root.fpsCapValue === "60" ? (1.0 / 60.0) : 0.0)
    property real frameAccumulator: 0.0
    property real accumulatedTime: 0.0
    property real accumulatedWindDrift: 0.0
    property real smoothedBass: 0.0
    property real smoothedMid: 0.0
    property real smoothedTreble: 0.0

    FrameAnimation {
        running: root.visible && root.opacity > 0 && !root.isAnimationPaused
        onTriggered: {
            root.frameAccumulator += frameTime;
            if (root.fpsCapInterval > 0.0 && root.frameAccumulator < root.fpsCapInterval) {
                return;
            }
            const dt = root.frameAccumulator;
            root.accumulatedTime += dt * root.speedValue;
            root.accumulatedWindDrift += dt * Math.tan((root.windAngleValue * Math.PI) / 180.0);

            const targetBass = root.audioReactiveValue ? Math.min(1.0, levelEngine.bass * root.bassGainValue * 0.7) : 0.0;
            const targetMid = root.audioReactiveValue ? Math.min(1.0, root.midLevel * root.midGainValue * 0.7) : 0.0;
            const targetTreble = root.audioReactiveValue ? Math.min(1.0, root.trebleLevel * root.trebleGainValue * 0.7) : 0.0;

            const attackRate = 1.0 - Math.exp(-dt * 20.0);
            const decayRate = 1.0 - Math.exp(-dt * 5.0);

            root.smoothedBass += (targetBass > root.smoothedBass ? attackRate : decayRate) * (targetBass - root.smoothedBass);
            root.smoothedMid += (targetMid > root.smoothedMid ? attackRate : decayRate) * (targetMid - root.smoothedMid);
            root.smoothedTreble += (targetTreble > root.smoothedTreble ? attackRate : decayRate) * (targetTreble - root.smoothedTreble);

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

    property var clickTimes: [-9999.0, -9999.0, -9999.0, -9999.0]
    property var clickPositionsX: [-9999.0, -9999.0, -9999.0, -9999.0]
    property var clickPositionsY: [-9999.0, -9999.0, -9999.0, -9999.0]
    property int clickRingIndex: 0

    function triggerClickBurst(x, y) {
        if (!root.clickBurstValue) return;
        const idx = root.clickRingIndex;
        let times = root.clickTimes.slice();
        let posX = root.clickPositionsX.slice();
        let posY = root.clickPositionsY.slice();
        posX[idx] = x;
        posY[idx] = y;
        times[idx] = root.accumulatedTime;
        root.clickPositionsX = posX;
        root.clickPositionsY = posY;
        root.clickTimes = times;
        root.clickRingIndex = (idx + 1) % 4;
    }

    readonly property vector4d clickProgresses: {
        const t = root.accumulatedTime;
        const p0 = (t - root.clickTimes[0] >= 0.0 && t - root.clickTimes[0] <= 1.0) ? (t - root.clickTimes[0]) : 1.0;
        const p1 = (t - root.clickTimes[1] >= 0.0 && t - root.clickTimes[1] <= 1.0) ? (t - root.clickTimes[1]) : 1.0;
        const p2 = (t - root.clickTimes[2] >= 0.0 && t - root.clickTimes[2] <= 1.0) ? (t - root.clickTimes[2]) : 1.0;
        const p3 = (t - root.clickTimes[3] >= 0.0 && t - root.clickTimes[3] <= 1.0) ? (t - root.clickTimes[3]) : 1.0;
        return Qt.vector4d(p0, p1, p2, p3);
    }

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

    readonly property real effectiveBass: root.smoothedBass
    readonly property real effectiveMid: root.smoothedMid
    readonly property real effectiveTreble: root.smoothedTreble

    HoverHandler {
        id: hoverHandler
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
        cursorShape: Qt.ArrowCursor
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        hoverEnabled: false
        onPressed: (mouse) => {
            root.triggerClickBurst(mouse.x, mouse.y);
            mouse.accepted = false;
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
        windDrift: root.accumulatedWindDrift
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
        clickProgress: root.clickProgresses
        clickPos0: Qt.vector2d(root.clickPositionsX[0], root.clickPositionsY[0])
        clickPos1: Qt.vector2d(root.clickPositionsX[1], root.clickPositionsY[1])
        clickPos2: Qt.vector2d(root.clickPositionsX[2], root.clickPositionsY[2])
        clickPos3: Qt.vector2d(root.clickPositionsX[3], root.clickPositionsY[3])
        mousePos: Qt.vector2d(root.smoothMouseX, root.smoothMouseY)
        primaryColor: root.effectivePrimaryVec
        secondaryColor: root.effectiveSecondaryVec
    }
}
