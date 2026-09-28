pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common

Scope {
    id: root

    // Reactive glow color: blends secondary accent when music plays, or Monet primary
    property color activeGlowColor: {
        if ((Config.options.appearance?.ambientEdgeGlow?.syncWithMusic ?? true) && (MprisController.activePlayer?.isPlaying ?? false)) {
            return Appearance.colors.colSecondary;
        }
        return Appearance.colors.colPrimary;
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: glowWindow
            required property var modelData
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            mask: Region {} // 100% Click-through: never intercepts cursor or window interaction
            WlrLayershell.layer: WlrLayer.Bottom // Rendered right above wallpaper, under windows
            WlrLayershell.namespace: "quickshell:ambientEdgeGlow"

            // Breathing / Pulse factor when music is playing
            property real pulseFactor: 1.0
            SequentialAnimation on pulseFactor {
                running: (Config.options.appearance?.ambientEdgeGlow?.pulseEffect ?? true) && (MprisController.activePlayer?.isPlaying ?? false)
                loops: Animation.Infinite
                NumberAnimation { to: 1.35; duration: 1200; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 1200; easing.type: Easing.InOutSine }
            }

            Rectangle {
                id: glowCanvas
                anchors.fill: parent
                color: "transparent"
                border.width: (Config.options.appearance?.ambientEdgeGlow?.thickness ?? 18) * glowWindow.pulseFactor
                border.color: root.activeGlowColor
                opacity: (Config.options.appearance?.ambientEdgeGlow?.opacity ?? 0.45)

                Behavior on border.color {
                    ColorAnimation { duration: 800; easing.type: Easing.InOutCubic }
                }

                layer.enabled: true
                layer.effect: FastBlur {
                    radius: 48
                }
            }
        }
    }
}
