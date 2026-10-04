import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Scope {
    id: root

    // Warning Banner on Focused Monitor
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: warningWindow
            required property var modelData
            screen: modelData

            visible: GlobalStates.restWarningOpen && !GlobalStates.restOpen
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:rest-warning"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            color: "transparent"

            anchors {
                top: true
                left: true
                right: true
            }

            implicitHeight: 120

            mask: Region {
                item: warningCard
            }

            Rectangle {
                id: warningCard
                anchors.top: parent.top
                anchors.topMargin: 24
                anchors.horizontalCenter: parent.horizontalCenter
                implicitWidth: 440
                implicitHeight: 74
                radius: Appearance.rounding.verylarge
                color: Appearance.colors.colSurfaceContainerHigh
                border.width: 1
                border.color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.5)

                StyledRectangularShadow {
                    target: warningCard
                    z: -1
                    visible: true
                }

                RowLayout {
                    anchors {
                        fill: parent
                        margins: 14
                    }
                    spacing: 12

                    MaterialShapeWrappedMaterialSymbol {
                        shape: MaterialShape.Shape.Cookie12Sided
                        color: Appearance.colors.colPrimary
                        colSymbol: Appearance.colors.colOnPrimary
                        text: "spa"
                        iconSize: 20
                        implicitWidth: 40
                        implicitHeight: 40
                        padding: 8
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        StyledText {
                            text: Translation.tr("Time for a Rest Break")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnSurface
                        }
                        StyledText {
                            text: Translation.tr("Screen will rest in %1s to relieve eye strain.").arg(RestService.warningSecondsLeft)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: ColorUtils.transparentize(Appearance.colors.colOnSurface, 0.3)
                        }
                    }

                    // Snooze Button
                    Rectangle {
                        implicitWidth: 70
                        implicitHeight: 34
                        radius: 17
                        color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.75)
                        border.width: 1
                        border.color: ColorUtils.transparentize(Appearance.colors.colOnSurface, 0.8)

                        StyledText {
                            anchors.centerIn: parent
                            text: Translation.tr("Snooze")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnSurface
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: RestService.snooze(5)
                        }
                    }

                    // Rest Now Button
                    Rectangle {
                        implicitWidth: 84
                        implicitHeight: 34
                        radius: 17
                        color: Appearance.colors.colPrimary

                        StyledText {
                            anchors.centerIn: parent
                            text: Translation.tr("Rest Now")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnPrimary
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: RestService.startRest(-1, RestService.source)
                        }
                    }
                }
            }
        }
    }

    // Fullscreen Multi-monitor Zen Rest Overlay
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: restWindow
            required property var modelData
            screen: modelData

            visible: GlobalStates.restOpen
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:rest-overlay"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            implicitWidth: modelData.width
            implicitHeight: modelData.height

            // Mouse interception to lock the screen surface
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.AllButtons
            }

            // Dark Dimming Background
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0.04, 0.05, 0.08, (Config.options.rest && Config.options.rest.visual) ? Config.options.rest.visual.dimOpacity : 0.94)

                Behavior on opacity {
                    NumberAnimation { duration: 400; easing.type: Easing.OutQuad }
                }
            }

            // Keyboard interception
            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => {
                    // Prevent Escape from dismissing directly; user must use emergency hold
                    event.accepted = true;
                }
            }

            // Central Zen Content
            Item {
                anchors.centerIn: parent
                width: 480
                height: 580

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 16

                    // Header Tag
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8

                        MaterialShapeWrappedMaterialSymbol {
                            shape: MaterialShape.Shape.Cookie12Sided
                            color: Appearance.colors.colPrimary
                            colSymbol: Appearance.colors.colOnPrimary
                            text: "self_improvement"
                            iconSize: 20
                            implicitWidth: 36
                            implicitHeight: 36
                            padding: 6
                        }

                        StyledText {
                            text: RestService.source === "focusflow"
                                ? Translation.tr("FOCUS SESSION BREAK")
                                : Translation.tr("MINDFUL REST & RECHARGE")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Bold
                            font.letterSpacing: 1.5
                            color: Appearance.colors.colPrimary
                        }
                    }

                    // Breathing Ring Guide
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 220
                        Layout.preferredHeight: 220

                        // Outer glowing aura
                        Rectangle {
                            id: breathingAura
                            anchors.centerIn: parent
                            width: {
                                const base = 140;
                                const maxScale = 70;
                                if (RestService.breathingPhase === 0) { // Inhale
                                    return base + maxScale * RestService.breathingProgress;
                                } else if (RestService.breathingPhase === 1) { // Hold in
                                    return base + maxScale;
                                } else if (RestService.breathingPhase === 2) { // Exhale
                                    return base + maxScale * (1.0 - RestService.breathingProgress);
                                } else { // Rest
                                    return base;
                                }
                            }
                            height: width
                            radius: width / 2
                            color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85)
                            border.width: 2
                            border.color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.45)

                            Behavior on width {
                                NumberAnimation { duration: 60 }
                            }
                        }

                        // Inner solid circle
                        Rectangle {
                            anchors.centerIn: parent
                            width: 130
                            height: 130
                            radius: 65
                            color: Appearance.colors.colSurfaceContainerHigh
                            border.width: 1
                            border.color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.6)

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2

                                MaterialSymbol {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: RestService.breathingPhase === 0 ? "north" : (RestService.breathingPhase === 2 ? "south" : "pause")
                                    iconSize: 22
                                    color: Appearance.colors.colPrimary
                                }

                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: RestService.breathingTexts[RestService.breathingPhase] ?? ""
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnSurface
                                }
                            }
                        }
                    }

                    // Big Countdown Timer
                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 2

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: RestService.formatSeconds(RestService.secondsLeft)
                            font.pixelSize: 48
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnSurface
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Translation.tr("Time remaining to rest your eyes & mind")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: ColorUtils.transparentize(Appearance.colors.colOnSurface, 0.4)
                        }
                    }

                    // Ergonomic Tip Card
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 70
                        radius: Appearance.rounding.large
                        color: Appearance.colors.colSurfaceContainerHigh
                        border.width: 1
                        border.color: ColorUtils.transparentize(Appearance.colors.colOnSurface, 0.85)

                        RowLayout {
                            anchors {
                                fill: parent
                                margins: 12
                            }
                            spacing: 10

                            MaterialSymbol {
                                text: "lightbulb"
                                iconSize: 20
                                color: Appearance.colors.colPrimary
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: RestService.ergonomicTips[RestService.currentTipIndex] ?? ""
                                wrapMode: Text.Wrap
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnSurface
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Action Area: Continue Button or Emergency Hold
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 50

                        // Unlocked: Continue Button
                        Rectangle {
                            anchors.fill: parent
                            visible: RestService.canUnlock
                            radius: 25
                            color: Appearance.colors.colPrimary

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                MaterialSymbol {
                                    text: "check_circle"
                                    iconSize: 20
                                    color: Appearance.colors.colOnPrimary
                                }
                                StyledText {
                                    text: Translation.tr("Continue Working")
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    font.weight: Font.Bold
                                    color: Appearance.colors.colOnPrimary
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: RestService.finishRest()
                            }
                        }

                        // Locked: Emergency Hold to Skip (3s)
                        Rectangle {
                            id: emergencyHoldBox
                            anchors.fill: parent
                            visible: !RestService.canUnlock
                            radius: 25
                            color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.7)
                            border.width: 1
                            border.color: ColorUtils.transparentize(Appearance.colors.colOnSurface, 0.8)
                            clip: true

                            property real holdProgress: 0.0
                            property bool isHolding: false

                            // Progress fill
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: parent.width * emergencyHoldBox.holdProgress
                                color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.45)
                                radius: 25
                            }

                            Timer {
                                id: holdTimer
                                interval: 50
                                repeat: true
                                running: emergencyHoldBox.isHolding
                                onTriggered: {
                                    emergencyHoldBox.holdProgress = Math.min(1.0, emergencyHoldBox.holdProgress + (50 / 3000));
                                    if (emergencyHoldBox.holdProgress >= 1.0) {
                                        holdTimer.stop();
                                        emergencyHoldBox.isHolding = false;
                                        RestService.emergencyUnlock();
                                    }
                                }
                            }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                MaterialSymbol {
                                    text: "warning"
                                    iconSize: 18
                                    color: ColorUtils.transparentize(Appearance.colors.colOnSurface, 0.3)
                                }
                                StyledText {
                                    text: emergencyHoldBox.isHolding
                                        ? Translation.tr("Holding... Keep pressed (%1%)").arg(Math.round(emergencyHoldBox.holdProgress * 100))
                                        : Translation.tr("Press & Hold 3s to Override")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnSurface
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onPressed: {
                                    emergencyHoldBox.holdProgress = 0.0;
                                    emergencyHoldBox.isHolding = true;
                                }
                                onReleased: {
                                    emergencyHoldBox.isHolding = false;
                                    emergencyHoldBox.holdProgress = 0.0;
                                }
                                onCanceled: {
                                    emergencyHoldBox.isHolding = false;
                                    emergencyHoldBox.holdProgress = 0.0;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
