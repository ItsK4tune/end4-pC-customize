pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common

Item {
    id: root

    required property Item sourceItem
    property real blurRadius: Config.options.background.blurRadius ?? 48
    property bool isDynamic: false

    readonly property Item blurTexture: blurOutput

    width: sourceItem ? sourceItem.width : 0
    height: sourceItem ? sourceItem.height : 0
    visible: true
    opacity: 0.0001 // Keeps FBO active in Qt Quick SceneGraph without visible double-drawing

    function scheduleUpdate() {
        downPass0.scheduleUpdate();
        downPass1Source.scheduleUpdate();
        downPass2Source.scheduleUpdate();
        blurOutput.scheduleUpdate();
    }

    onSourceItemChanged: {
        updateTimer.restart();
    }

    Timer {
        id: updateTimer
        interval: 16
        onTriggered: root.scheduleUpdate()
    }

    // Pass 0: Initial downsample from full wallpaper to 1/2 resolution
    ShaderEffectSource {
        id: downPass0
        anchors.fill: parent
        sourceItem: root.sourceItem
        textureSize: Qt.size(
            Math.max(1, Math.ceil(root.width / 2)),
            Math.max(1, Math.ceil(root.height / 2))
        )
        smooth: true
        recursive: false
        hideSource: false
        live: root.isDynamic
    }

    // Pass 1: Kawase downsampling shader
    ShaderEffect {
        id: downPass1
        width: downPass0.textureSize.width
        height: downPass0.textureSize.height
        property var source: downPass0
        property vector2d halfpixel: Qt.vector2d(0.5 / Math.max(1, width), 0.5 / Math.max(1, height))
        property vector2d offset: Qt.vector2d(1.5, 1.5)
        fragmentShader: Qt.resolvedUrl("shaders/kawase_down.frag.qsb")
    }

    // Pass 1 Source: Downsample from 1/2 to 1/4 resolution
    ShaderEffectSource {
        id: downPass1Source
        sourceItem: downPass1
        textureSize: Qt.size(
            Math.max(1, Math.ceil(root.width / 4)),
            Math.max(1, Math.ceil(root.height / 4))
        )
        smooth: true
        recursive: false
        live: root.isDynamic
    }

    // Pass 2: Kawase second downsample
    ShaderEffect {
        id: downPass2
        width: downPass1Source.textureSize.width
        height: downPass1Source.textureSize.height
        property var source: downPass1Source
        property vector2d halfpixel: Qt.vector2d(0.5 / Math.max(1, width), 0.5 / Math.max(1, height))
        property vector2d offset: Qt.vector2d(2.0, 2.0)
        fragmentShader: Qt.resolvedUrl("shaders/kawase_down.frag.qsb")
    }

    // Pass 2 Source: Upsample from 1/4 to 1/2 resolution
    ShaderEffectSource {
        id: downPass2Source
        sourceItem: downPass2
        textureSize: Qt.size(
            Math.max(1, Math.ceil(root.width / 2)),
            Math.max(1, Math.ceil(root.height / 2))
        )
        smooth: true
        recursive: false
        live: root.isDynamic
    }

    // Pass 3: Kawase upsampling pass
    ShaderEffect {
        id: upPass1
        width: downPass2Source.textureSize.width
        height: downPass2Source.textureSize.height
        property var source: downPass2Source
        property vector2d halfpixel: Qt.vector2d(0.5 / Math.max(1, width), 0.5 / Math.max(1, height))
        property vector2d offset: Qt.vector2d(2.0, 2.0)
        fragmentShader: Qt.resolvedUrl("shaders/kawase_up.frag.qsb")
    }

    // Output: Final blurred texture representation
    ShaderEffectSource {
        id: blurOutput
        sourceItem: upPass1
        textureSize: Qt.size(
            Math.max(1, Math.ceil(root.width)),
            Math.max(1, Math.ceil(root.height))
        )
        smooth: true
        recursive: false
        hideSource: false
        live: root.isDynamic
    }
}
