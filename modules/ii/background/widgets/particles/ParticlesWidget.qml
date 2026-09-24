import QtQuick
import qs
import qs.modules.common
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "particles"

    implicitWidth: screenWidth
    implicitHeight: screenHeight
    width: screenWidth
    height: screenHeight

    x: 0
    y: 0
    targetZ: (configEntry?.layerMode ?? "below") === "above" ? 1000 : -500
    z: targetZ

    draggable: false
    hoverEnabled: false

    function restoreXYBinding() {
        root.x = 0;
        root.y = 0;
        root.z = Qt.binding(() => root.targetZ);
    }

    readonly property string preset: configEntry?.preset ?? "sakura"
    readonly property real speedValue: configEntry?.speed ?? 1.0
    readonly property real densityValue: configEntry?.density ?? 1.0
    readonly property real particleSizeValue: configEntry?.particleSize ?? 1.0
    readonly property real particleAlphaValue: configEntry?.particleAlpha ?? 0.8
    readonly property real mouseRadiusValue: configEntry?.mouseRadius ?? 180.0
    readonly property real mouseStrengthValue: configEntry?.mouseStrength ?? 1.0
    readonly property real backgroundDimAlphaValue: configEntry?.backgroundDimAlpha ?? 0.0
    readonly property string backgroundDimColorValue: configEntry?.backgroundDimColor ?? "#000000"

    readonly property real mouseModeValue: {
        switch (configEntry?.mouseInteraction ?? "repel") {
            case "repel": return 1.0;
            case "attract": return 2.0;
            case "glow": return 3.0;
            default: return 0.0;
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
        speed: root.speedValue
        density: root.densityValue
        particleSize: root.particleSizeValue
        particleAlpha: root.particleAlphaValue
        mouseRadius: root.mouseRadiusValue
        mouseStrength: root.mouseStrengthValue
        mouseMode: root.mouseModeValue
        mousePos: Qt.vector2d(root.smoothMouseX, root.smoothMouseY)
        primaryColor: Appearance.colors.colPrimary
        secondaryColor: Appearance.colors.colSecondary
    }
}
