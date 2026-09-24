pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.modules.common

Variants {
    id: root
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData

        screen: modelData
        visible: (Config.options?.background?.widgets?.particles?.enable ?? false)
            && (Config.options?.background?.widgets?.particles?.layerMode === "window")

        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        WlrLayershell.namespace: "quickshell:particlesOverlay"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        ParticlesWidget {
            anchors.fill: parent
            screenWidth: win.width
            screenHeight: win.height
            scaledScreenWidth: win.width
            scaledScreenHeight: win.height
            wallpaperScale: 1
            isOverlayWindow: true
        }
    }
}
