pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "pet"

    readonly property real petScale: configEntry?.petScale ?? 1.0
    readonly property string petType: configEntry?.petType ?? "cat"
    readonly property bool showSpeechBubble: configEntry?.showSpeechBubble ?? true
    readonly property bool reactToMusic: configEntry?.reactToMusic ?? true
    readonly property bool reactToSystem: configEntry?.reactToSystem ?? true
    readonly property bool reactToWeather: configEntry?.reactToWeather ?? true

    implicitWidth: 190 * petScale
    implicitHeight: 170 * petScale
    width: implicitWidth
    height: implicitHeight

    // State machine
    property bool isPetted: false
    property int petHeartCount: 0
    property bool isDancing: reactToMusic && MprisController.isPlaying
    property bool isSweating: reactToSystem && (ResourceUsage.cpuUsage > 0.75)
    property bool isRaining: reactToWeather && (
        Weather.currentCondition.toLowerCase().includes("rain") ||
        Weather.currentCondition.toLowerCase().includes("drizzle") ||
        Weather.currentCondition.toLowerCase().includes("shower")
    )
    property bool isSleeping: idleSeconds > 35 && !isDancing && !isPetted

    property int idleSeconds: 0
    Timer {
        id: idleTracker
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            if (!root.containsMouse && !root.dragging) {
                root.idleSeconds++;
            }
        }
    }

    function resetIdle() {
        root.idleSeconds = 0;
    }

    // Blinking timer
    property bool eyesBlinking: false
    Timer {
        id: blinkTimer
        interval: Math.floor(Math.random() * 3000) + 2500
        repeat: true
        running: !root.isSleeping
        onTriggered: {
            root.eyesBlinking = true;
            blinkResetTimer.restart();
            interval = Math.floor(Math.random() * 3000) + 2500;
        }
    }
    Timer {
        id: blinkResetTimer
        interval: 150
        onTriggered: root.eyesBlinking = false
    }

    // Pet action
    Timer {
        id: pettedCooldown
        interval: 3500
        onTriggered: root.isPetted = false
    }

    function pet() {
        root.resetIdle();
        root.isPetted = true;
        root.petHeartCount++;
        pettedCooldown.restart();
        heartBurstAnim.restart();
        bubbleDisplayTimer.restart();
    }

    // Speech bubble dynamic messages
    readonly property string speechText: {
        if (root.isPetted) {
            const petQuips = ["Purrrr! <3", "Meow meow~", "You are the best!", "*nuzzles hand*", "Nyaa~ <3"];
            return petQuips[root.petHeartCount % petQuips.length];
        }
        if (root.isDancing) {
            const track = MprisController.trackTitle;
            return track ? `Vibing to: ${track.slice(0, 18)}..` : "Vibing to the beat! 🎶";
        }
        if (root.isSweating) {
            return `Hot hot! CPU at ${Math.round(ResourceUsage.cpuUsage * 100)}% 💧`;
        }
        if (root.isRaining) {
            return "Stay cozy and dry! 🌧️";
        }
        if (root.isSleeping) {
            return "Zzz... 💤";
        }
        if (root.idleSeconds > 15) {
            return "Just chillin' here~";
        }
        return "Meow! Welcome!";
    }

    // Glass backdrop pod
    FastBlurred {
        id: podBg
        anchors.fill: parent
        anchors.margins: 6
        cardRadius: 28 * root.petScale
        blurSource: root.wallpaperItem
        tint: Appearance.colors.colLayer0
        tintOpacity: 0.35
        border.color: Appearance.colors.colOutlineVariant
        border.width: 1
    }

    // Main Interactive Area
    MouseArea {
        id: petArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onPressed: (mouse) => {
            root.resetIdle();
            if (!root.dragging) {
                root.pet();
            }
        }
        onPositionChanged: root.resetIdle()
    }

    // Speech Bubble Component
    Item {
        id: speechBubble
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: -8
        width: Math.min(180 * root.petScale, bubbleText.implicitWidth + 24)
        height: 28 * root.petScale
        visible: root.showSpeechBubble && (root.isPetted || root.isDancing || root.isSweating || root.isSleeping || bubbleDisplayTimer.running)
        scale: visible ? 1.0 : 0.8
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Appearance.colors.colPrimaryContainer
            border.color: Appearance.colors.colPrimary
            border.width: 1

            Text {
                id: bubbleText
                anchors.centerIn: parent
                text: root.speechText
                color: Appearance.colors.colOnPrimaryContainer
                font.pixelSize: Math.max(9, Math.round(10 * root.petScale))
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        // Little speech pointer triangle
        Rectangle {
            width: 8
            height: 8
            rotation: 45
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -4
            color: Appearance.colors.colPrimaryContainer
            border.color: Appearance.colors.colPrimary
            border.width: 1
        }
    }

    Timer {
        id: bubbleDisplayTimer
        interval: 4000
        running: false
    }

    // Pixel Pet Character Canvas / Construction
    Item {
        id: petContainer
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 10 * root.petScale
        width: 100 * root.petScale
        height: 90 * root.petScale

        // Colors
        readonly property color coatColor: Appearance.colors.colPrimary
        readonly property color bellyColor: Appearance.colors.colSecondaryContainer
        readonly property color innerEarColor: "#ffb4ab"
        readonly property color eyeColor: Appearance.colors.colOnPrimary
        readonly property color pupilColor: "#111111"
        readonly property color cheekBlushColor: "#ff8fa3"

        // Animation Bobbing (Music Dancing / Breathing)
        property real danceTilt: 0
        property real danceBob: 0

        SequentialAnimation {
            running: root.isDancing
            loops: Animation.Infinite
            NumberAnimation { target: petContainer; property: "danceTilt"; from: -7; to: 7; duration: 320; easing.type: Easing.InOutQuad }
            NumberAnimation { target: petContainer; property: "danceTilt"; from: 7; to: -7; duration: 320; easing.type: Easing.InOutQuad }
        }
        SequentialAnimation {
            running: root.isDancing
            loops: Animation.Infinite
            NumberAnimation { target: petContainer; property: "danceBob"; from: 0; to: -6; duration: 160; easing.type: Easing.OutQuad }
            NumberAnimation { target: petContainer; property: "danceBob"; from: -6; to: 0; duration: 160; easing.type: Easing.InQuad }
        }

        // Idle gentle breathing
        SequentialAnimation {
            running: !root.isDancing && !root.isSleeping
            loops: Animation.Infinite
            NumberAnimation { target: petContainer; property: "danceBob"; from: 0; to: -2; duration: 1200; easing.type: Easing.InOutSine }
            NumberAnimation { target: petContainer; property: "danceBob"; from: -2; to: 0; duration: 1200; easing.type: Easing.InOutSine }
        }

        // Sleeping gentle heave
        SequentialAnimation {
            running: root.isSleeping
            loops: Animation.Infinite
            NumberAnimation { target: petContainer; property: "danceBob"; from: 0; to: -1; duration: 2000; easing.type: Easing.InOutSine }
            NumberAnimation { target: petContainer; property: "danceBob"; from: -1; to: 0; duration: 2000; easing.type: Easing.InOutSine }
        }

        transform: [
            Rotation { origin.x: petContainer.width / 2; origin.y: petContainer.height; angle: petContainer.danceTilt },
            Translate { y: petContainer.danceBob }
        ]

        // --- Tail ---
        Item {
            id: petTail
            x: 75 * root.petScale
            y: 50 * root.petScale
            width: 28 * root.petScale
            height: 28 * root.petScale
            transformOrigin: Item.BottomLeft
            rotation: 15

            SequentialAnimation on rotation {
                running: true
                loops: Animation.Infinite
                NumberAnimation { from: 10; to: root.isPetted ? 45 : (root.isDancing ? 35 : 20); duration: root.isPetted ? 120 : (root.isDancing ? 200 : 800); easing.type: Easing.InOutQuad }
                NumberAnimation { from: root.isPetted ? 45 : (root.isDancing ? 35 : 20); to: 10; duration: root.isPetted ? 120 : (root.isDancing ? 200 : 800); easing.type: Easing.InOutQuad }
            }

            Rectangle {
                width: 10 * root.petScale
                height: 22 * root.petScale
                radius: 5 * root.petScale
                color: petContainer.coatColor
                rotation: 30
            }
        }

        // --- Ears ---
        // Left Ear
        Rectangle {
            x: 14 * root.petScale
            y: root.isPetted ? 10 * root.petScale : (root.containsMouse ? 2 * root.petScale : 4 * root.petScale)
            width: 22 * root.petScale
            height: 24 * root.petScale
            radius: 4 * root.petScale
            rotation: -25
            color: petContainer.coatColor
            Behavior on y { NumberAnimation { duration: 150 } }

            Rectangle {
                anchors.centerIn: parent
                width: 12 * root.petScale
                height: 14 * root.petScale
                radius: 2 * root.petScale
                color: petContainer.innerEarColor
            }
        }
        // Right Ear
        Rectangle {
            x: 64 * root.petScale
            y: root.isPetted ? 10 * root.petScale : (root.containsMouse ? 2 * root.petScale : 4 * root.petScale)
            width: 22 * root.petScale
            height: 24 * root.petScale
            radius: 4 * root.petScale
            rotation: 25
            color: petContainer.coatColor
            Behavior on y { NumberAnimation { duration: 150 } }

            Rectangle {
                anchors.centerIn: parent
                width: 12 * root.petScale
                height: 14 * root.petScale
                radius: 2 * root.petScale
                color: petContainer.innerEarColor
            }
        }

        // --- Main Body / Head ---
        Rectangle {
            id: petBody
            x: 15 * root.petScale
            y: 18 * root.petScale
            width: 70 * root.petScale
            height: 58 * root.petScale
            radius: 26 * root.petScale
            color: petContainer.coatColor

            // Belly patch
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 2 * root.petScale
                width: 38 * root.petScale
                height: 26 * root.petScale
                radius: 14 * root.petScale
                color: petContainer.bellyColor
            }

            // Blushing Cheeks (when petted or dancing)
            Rectangle {
                x: 8 * root.petScale
                y: 30 * root.petScale
                width: 10 * root.petScale
                height: 6 * root.petScale
                radius: 3 * root.petScale
                color: petContainer.cheekBlushColor
                opacity: (root.isPetted || root.isDancing) ? 0.85 : 0.2
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }
            Rectangle {
                x: 52 * root.petScale
                y: 30 * root.petScale
                width: 10 * root.petScale
                height: 6 * root.petScale
                radius: 3 * root.petScale
                color: petContainer.cheekBlushColor
                opacity: (root.isPetted || root.isDancing) ? 0.85 : 0.2
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            // Eyes Group
            Item {
                id: eyesGroup
                anchors.fill: parent

                // Left Eye
                Item {
                    x: 18 * root.petScale
                    y: 20 * root.petScale
                    width: 12 * root.petScale
                    height: 14 * root.petScale

                    // Normal Eye
                    Rectangle {
                        anchors.fill: parent
                        radius: 6 * root.petScale
                        color: petContainer.pupilColor
                        visible: !root.isSleeping && !root.isPetted && !root.eyesBlinking

                        // Specular catchlight
                        Rectangle {
                            x: 2 * root.petScale; y: 2 * root.petScale
                            width: 4 * root.petScale; height: 4 * root.petScale
                            radius: 2 * root.petScale
                            color: "white"
                        }
                    }

                    // Happy / Pet / Sleeping Eye (^ shaped arc)
                    Text {
                        anchors.centerIn: parent
                        text: "^"
                        font.pixelSize: 14 * root.petScale
                        font.bold: true
                        color: petContainer.pupilColor
                        visible: root.isSleeping || root.isPetted || root.eyesBlinking
                    }
                }

                // Right Eye
                Item {
                    x: 40 * root.petScale
                    y: 20 * root.petScale
                    width: 12 * root.petScale
                    height: 14 * root.petScale

                    // Normal Eye
                    Rectangle {
                        anchors.fill: parent
                        radius: 6 * root.petScale
                        color: petContainer.pupilColor
                        visible: !root.isSleeping && !root.isPetted && !root.eyesBlinking

                        // Specular catchlight
                        Rectangle {
                            x: 2 * root.petScale; y: 2 * root.petScale
                            width: 4 * root.petScale; height: 4 * root.petScale
                            radius: 2 * root.petScale
                            color: "white"
                        }
                    }

                    // Happy / Pet / Sleeping Eye (^ shaped arc)
                    Text {
                        anchors.centerIn: parent
                        text: "^"
                        font.pixelSize: 14 * root.petScale
                        font.bold: true
                        color: petContainer.pupilColor
                        visible: root.isSleeping || root.isPetted || root.eyesBlinking
                    }
                }
            }

            // Snout & Nose
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 29 * root.petScale
                width: 6 * root.petScale
                height: 4 * root.petScale
                radius: 2 * root.petScale
                color: petContainer.innerEarColor
            }

            // Mouth (ω shape)
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 32 * root.petScale
                text: root.isSweating ? "o" : (root.isPetted ? "w" : "3")
                font.pixelSize: 10 * root.petScale
                font.bold: true
                color: petContainer.pupilColor
            }
        }

        // Paws
        Rectangle {
            x: 26 * root.petScale
            y: 68 * root.petScale
            width: 14 * root.petScale
            height: 10 * root.petScale
            radius: 5 * root.petScale
            color: petContainer.bellyColor
            border.color: petContainer.coatColor
            border.width: 1
        }
        Rectangle {
            x: 58 * root.petScale
            y: 68 * root.petScale
            width: 14 * root.petScale
            height: 10 * root.petScale
            radius: 5 * root.petScale
            color: petContainer.bellyColor
            border.color: petContainer.coatColor
            border.width: 1
        }

        // --- Accessories & Status FX ---

        // DJ Headphones (when dancing to music)
        Item {
            id: headphones
            anchors.fill: petBody
            visible: root.isDancing

            // Headband arc
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: -6 * root.petScale
                width: 58 * root.petScale
                height: 12 * root.petScale
                radius: 6 * root.petScale
                color: Appearance.colors.colTertiary
            }
            // Left Ear Cup
            Rectangle {
                x: -5 * root.petScale
                y: 14 * root.petScale
                width: 14 * root.petScale
                height: 20 * root.petScale
                radius: 5 * root.petScale
                color: Appearance.colors.colTertiary
                border.color: "white"
                border.width: 1
            }
            // Right Ear Cup
            Rectangle {
                x: 61 * root.petScale
                y: 14 * root.petScale
                width: 14 * root.petScale
                height: 20 * root.petScale
                radius: 5 * root.petScale
                color: Appearance.colors.colTertiary
                border.color: "white"
                border.width: 1
            }
        }

        // Sweat Drop (High CPU load)
        Text {
            id: sweatDrop
            x: 74 * root.petScale
            y: 16 * root.petScale
            text: "💧"
            font.pixelSize: 16 * root.petScale
            visible: root.isSweating

            SequentialAnimation on y {
                running: root.isSweating
                loops: Animation.Infinite
                NumberAnimation { from: 14 * root.petScale; to: 24 * root.petScale; duration: 600; easing.type: Easing.InQuad }
                NumberAnimation { from: 24 * root.petScale; to: 14 * root.petScale; duration: 200 }
            }
        }

        // Rain Umbrella (Rainy weather)
        Text {
            x: -8 * root.petScale
            y: -12 * root.petScale
            text: "☂️"
            font.pixelSize: 22 * root.petScale
            visible: root.isRaining && !root.isDancing
        }
    }

    // Floating Particles Container (Hearts on pet, Notes on music, Zzz on sleep)
    Item {
        id: particleOverlay
        anchors.fill: parent

        // Hearts Burst on pet
        Repeater {
            model: 3
            delegate: Text {
                id: heartParticle
                required property int index
                text: "❤️"
                font.pixelSize: (12 + index * 3) * root.petScale
                opacity: 0
                x: (root.width / 2) + (index === 0 ? -25 : (index === 1 ? 20 : 0)) * root.petScale
                y: root.height / 2

                ParallelAnimation {
                    id: heartAnim
                    NumberAnimation { target: heartParticle; property: "y"; from: root.height / 2; to: (root.height / 2) - 45 - index * 15; duration: 800 + index * 150; easing.type: Easing.OutQuad }
                    NumberAnimation { target: heartParticle; property: "opacity"; from: 1; to: 0; duration: 800 + index * 150 }
                    NumberAnimation { target: heartParticle; property: "scale"; from: 0.5; to: 1.2; duration: 800 + index * 150 }
                }

                Connections {
                    target: root
                    function onPetHeartCountChanged() {
                        heartAnim.restart();
                    }
                }
            }
        }

        // Music Notes (when dancing)
        Repeater {
            model: 2
            delegate: Text {
                id: noteParticle
                required property int index
                text: index === 0 ? "♪" : "♫"
                font.pixelSize: 14 * root.petScale
                color: Appearance.colors.colPrimary
                x: (root.width / 2) + (index === 0 ? 35 : -35) * root.petScale
                y: root.height / 2
                visible: root.isDancing

                SequentialAnimation on y {
                    running: root.isDancing
                    loops: Animation.Infinite
                    NumberAnimation { from: root.height / 2; to: (root.height / 2) - 35; duration: 900 + index * 300; easing.type: Easing.OutQuad }
                    NumberAnimation { from: (root.height / 2) - 35; to: root.height / 2; duration: 0 }
                }
                SequentialAnimation on opacity {
                    running: root.isDancing
                    loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 0; duration: 900 + index * 300 }
                    NumberAnimation { from: 0; to: 1; duration: 0 }
                }
            }
        }

        // Sleep Z's (when sleeping)
        Repeater {
            model: 2
            delegate: Text {
                id: zParticle
                required property int index
                text: "Z"
                font.pixelSize: (11 + index * 3) * root.petScale
                font.bold: true
                color: Appearance.colors.colTertiary
                x: (root.width / 2) + 20 + index * 10
                y: root.height / 2
                visible: root.isSleeping

                SequentialAnimation on y {
                    running: root.isSleeping
                    loops: Animation.Infinite
                    NumberAnimation { from: root.height / 2; to: (root.height / 2) - 30; duration: 1500 + index * 400; easing.type: Easing.OutQuad }
                    NumberAnimation { from: (root.height / 2) - 30; to: root.height / 2; duration: 0 }
                }
                SequentialAnimation on opacity {
                    running: root.isSleeping
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.9; to: 0; duration: 1500 + index * 400 }
                    NumberAnimation { from: 0; to: 0.9; duration: 0 }
                }
            }
        }
    }

    SequentialAnimation {
        id: heartBurstAnim
        NumberAnimation { target: petContainer; property: "scale"; from: 1.0; to: 1.15; duration: 120; easing.type: Easing.OutBack }
        NumberAnimation { target: petContainer; property: "scale"; from: 1.15; to: 1.0; duration: 150; easing.type: Easing.InOutQuad }
    }
}
