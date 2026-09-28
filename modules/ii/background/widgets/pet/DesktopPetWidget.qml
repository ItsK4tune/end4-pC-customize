pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "pet"

    readonly property real petScale: configEntry?.petScale ?? 1.0
    readonly property string petType: configEntry?.petType ?? "cat"
    readonly property string backgroundStyle: configEntry?.backgroundStyle ?? "glass" // "glass", "transparent", "solid", "dim"
    readonly property bool showSpeechBubble: configEntry?.showSpeechBubble ?? true
    readonly property bool reactToMusic: configEntry?.reactToMusic ?? true
    readonly property bool reactToSystem: configEntry?.reactToSystem ?? true
    readonly property bool reactToWeather: configEntry?.reactToWeather ?? true
    readonly property bool canWander: configEntry?.canWander ?? true
    readonly property int wanderInterval: (configEntry?.wanderInterval ?? 45) * 1000

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
        (Weather.currentCondition?.toLowerCase() ?? "").includes("rain") ||
        (Weather.currentCondition?.toLowerCase() ?? "").includes("drizzle") ||
        (Weather.currentCondition?.toLowerCase() ?? "").includes("shower")
    )
    property bool isWalking: false
    property bool facingLeft: false
    property string wanderQuip: ""
    property string customSpeechText: ""
    property bool isSleeping: idleSeconds > 35 && !isDancing && !isPetted && !isWalking

    property int idleSeconds: 0
    Timer {
        id: idleTracker
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            if (!root.containsMouse && !root.dragging && !chatOverlay.visible) {
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

    // Easter Egg: Rapid Affection Combo
    property int rapidClickCount: 0
    property bool isEasterEggActive: false

    Timer {
        id: rapidClickTimer
        interval: 2200
        onTriggered: root.rapidClickCount = 0
    }

    function triggerEasterEgg() {
        root.isEasterEggActive = true;
        root.rapidClickCount = 0;
        easterEggAnim.restart();

        const easterEggQuotes = [
            "(^◕ᴥ◕^) PETTING OVERLOAD!! +9999 Aura Points!",
            "meow~ compiling your dreams with 0 errors! 🚀",
            "git commit -m 'pet the cat until it purrs' --force ✨",
            "sudo systemctl restart happiness.service 💖",
            "₍ᐢ. .ᐢ₎ You're doing incredible today! Keep shining!",
            "☕ Hydrate, stretch, and take over the world! 🌸"
        ];
        root.customSpeechText = easterEggQuotes[Math.floor(Math.random() * easterEggQuotes.length)];
        bubbleDisplayTimer.interval = 6000;
        bubbleDisplayTimer.restart();

        Quickshell.execDetached([`${Directories.scriptPath}/audio/focus-ambient.sh`, "chime"]);
    }

    function pet() {
        root.resetIdle();
        root.isPetted = true;
        root.petHeartCount++;
        pettedCooldown.restart();
        heartBurstAnim.restart();
        bubbleDisplayTimer.interval = 4000;
        bubbleDisplayTimer.restart();
    }

    // Smooth movement animations for wandering
    NumberAnimation {
        id: wanderAnimX
        target: root
        property: "x"
        easing.type: Easing.InOutQuad
    }
    NumberAnimation {
        id: wanderAnimY
        target: root
        property: "y"
        easing.type: Easing.InOutQuad
        onFinished: {
            root.isWalking = false;
            root.commitPosition();
            wanderCooldownTimer.interval = Math.floor(Math.random() * 20000) + root.wanderInterval;
            wanderCooldownTimer.restart();
        }
    }

    Timer {
        id: wanderCooldownTimer
        interval: root.wanderInterval
        repeat: true
        running: root.canWander && !root.dragging && !root.isSleeping && !root.isDancing && !chatOverlay.visible
        onTriggered: {
            if (root.dragging || root.isSleeping || root.isDancing || chatOverlay.visible || root.containsMouse) return;

            // Pick a destination on screen
            var minX = 60;
            var maxX = Math.max(minX + 50, root.scaledScreenWidth - root.width - 60);
            var minY = 80;
            var maxY = Math.max(minY + 50, root.scaledScreenHeight - root.height - 80);

            var nextX = Math.floor(Math.random() * (maxX - minX)) + minX;
            var nextY = Math.floor(Math.random() * (maxY - minY)) + minY;

            var dist = Math.hypot(nextX - root.x, nextY - root.y);
            if (dist < 40) return; // too close

            var duration = Math.max(2200, Math.min(5000, dist * 6));

            root.facingLeft = (nextX < root.x);
            root.isWalking = true;

            const wanderQuips = ["*tiptoeing~*", "*sniffing around*", "*pitter-patter*", "*wandering*", "*exploring*", "🐾"];
            root.wanderQuip = wanderQuips[Math.floor(Math.random() * wanderQuips.length)];
            bubbleDisplayTimer.interval = duration;
            bubbleDisplayTimer.restart();

            wanderAnimX.duration = duration;
            wanderAnimX.from = root.x;
            wanderAnimX.to = nextX;

            wanderAnimY.duration = duration;
            wanderAnimY.from = root.y;
            wanderAnimY.to = nextY;

            wanderAnimX.restart();
            wanderAnimY.restart();
        }
    }

    // Speech bubble dynamic messages
    readonly property string speechText: {
        if (root.customSpeechText !== "") return root.customSpeechText;
        if (root.isWalking && root.wanderQuip !== "") return root.wanderQuip;
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

    // Pod backdrop container
    Item {
        id: podContainer
        anchors.fill: parent
        anchors.margins: 6
        visible: root.backgroundStyle !== "transparent"

        // 1. Glass acrylic option
        FastBlurred {
            id: podBg
            anchors.fill: parent
            visible: root.backgroundStyle === "glass"
            cardRadius: 28 * root.petScale
            blurSource: root.wallpaperItem
            tint: Appearance.colors.colLayer0
            tintOpacity: 0.35

            Rectangle {
                anchors.fill: parent
                radius: podBg.cardRadius
                color: "transparent"
                border.color: Appearance.m3colors.darkmode ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.12)
                border.width: 1
            }
        }

        // 2. Solid card option
        Rectangle {
            anchors.fill: parent
            visible: root.backgroundStyle === "solid"
            radius: 28 * root.petScale
            color: Appearance.colors.colPrimaryContainer
            border.color: Appearance.m3colors.darkmode ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.12)
            border.width: 1
        }

        // 3. Dim dark translucent option
        Rectangle {
            anchors.fill: parent
            visible: root.backgroundStyle === "dim"
            radius: 28 * root.petScale
            color: Qt.rgba(0, 0, 0, 0.5)
            border.color: Appearance.m3colors.darkmode ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(0, 0, 0, 0.15)
            border.width: 1
        }
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
                root.rapidClickCount++;
                rapidClickTimer.restart();
                if (root.rapidClickCount >= 5) {
                    root.triggerEasterEgg();
                } else {
                    root.pet();
                }
            }
        }
        onPositionChanged: root.resetIdle()
    }

    // Speech Bubble Component
    Item {
        id: speechBubble
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: -14
        width: Math.min(220 * root.petScale, Math.max(70, bubbleText.implicitWidth + 24))
        height: Math.max(28 * root.petScale, bubbleText.implicitHeight + 10)
        visible: root.showSpeechBubble && (root.isPetted || root.isDancing || root.isSweating || root.isSleeping || root.isWalking || root.customSpeechText !== "" || bubbleDisplayTimer.running)
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
                anchors.margins: 6
                width: Math.min(implicitWidth, 200 * root.petScale)
                wrapMode: Text.WordWrap
                text: root.speechText
                color: Appearance.colors.colOnPrimaryContainer
                font.pixelSize: Math.max(9, Math.round(10 * root.petScale))
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                maximumLineCount: 2
                elide: Text.ElideRight
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
        onTriggered: {
            root.customSpeechText = "";
            root.wanderQuip = "";
        }
    }

    // AI Chat trigger button (visible on hover or open)
    Rectangle {
        id: chatButton
        width: 26 * root.petScale
        height: 26 * root.petScale
        radius: width / 2
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 6
        z: 10
        color: chatOverlay.visible ? Appearance.colors.colPrimary : Appearance.colors.colPrimaryContainer
        border.color: Appearance.colors.colPrimary
        border.width: 1
        opacity: (petArea.containsMouse || chatOverlay.visible || chatBtnMouse.containsMouse) ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        MaterialSymbol {
            anchors.centerIn: parent
            iconSize: 14 * root.petScale
            text: chatOverlay.visible ? "close" : "forum"
            color: chatOverlay.visible ? Appearance.colors.colOnPrimary : Appearance.colors.colOnPrimaryContainer
        }

        MouseArea {
            id: chatBtnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                chatOverlay.visible = !chatOverlay.visible;
                if (chatOverlay.visible) {
                    petInput.forceActiveFocus();
                    root.resetIdle();
                }
            }
        }
        StyledToolTip {
            text: Translation.tr("Chat with your pet")
        }
    }

    // AI Chat Input Bar Overlay
    Rectangle {
        id: chatOverlay
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -38 * root.petScale
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(180 * root.petScale, 190)
        height: 32 * root.petScale
        radius: 16
        z: 20
        visible: false
        color: Appearance.colors.colLayer1
        border.color: Appearance.colors.colPrimary
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 4

            TextInput {
                id: petInput
                Layout.fillWidth: true
                Layout.leftMargin: 8
                font.pixelSize: Math.max(10, Math.round(11 * root.petScale))
                color: Appearance.colors.colOnLayer1
                clip: true
                selectByMouse: true
                onAccepted: root.sendPetMessage()

                Text {
                    anchors.fill: parent
                    text: Translation.tr("Talk to pet...")
                    color: Appearance.colors.colOnPrimaryContainer
                    opacity: 0.6
                    font.pixelSize: petInput.font.pixelSize
                    font.italic: true
                    visible: !petInput.text && !petInput.activeFocus
                }
            }

            Rectangle {
                implicitWidth: 24 * root.petScale
                implicitHeight: 24 * root.petScale
                radius: width / 2
                color: Appearance.colors.colPrimary
                opacity: petInput.text.trim().length > 0 ? 1.0 : 0.4

                MaterialSymbol {
                    anchors.centerIn: parent
                    iconSize: 12 * root.petScale
                    text: "send"
                    color: Appearance.colors.colOnPrimary
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.sendPetMessage()
                }
            }
        }
    }

    function sendPetMessage() {
        const text = petInput.text.trim();
        if (text.length === 0) return;
        petInput.text = "";
        root.resetIdle();
        root.customSpeechText = "*thinking...* 🐾";
        bubbleDisplayTimer.interval = 14000;
        bubbleDisplayTimer.restart();

        const provider = Config.options.background.widgets.pet?.aiProvider ?? "gemini";
        const apiKey = Config.options.background.widgets.pet?.aiApiKey ?? (KeyringStorage.keyringData?.apiKeys?.gemini ?? "");
        const prompt = Config.options.background.widgets.pet?.aiPrompt ?? "You are an adorable, affectionate desktop pet companion (cat/dog/chibi). Keep responses short (1-2 sentences max), warm, playful, and expressive with pet sounds like 'meow~', '*purrs*', '*tilts head*'.";

        petChatProc.command = [
            FileUtils.trimFileProtocol(Directories.scriptPath) + "/ai/pet-chat.py",
            "--provider", provider,
            "--api-key", apiKey,
            "--prompt", prompt,
            "--message", text
        ];
        petChatProc.running = true;
    }

    Process {
        id: petChatProc
        stdout: StdioCollector {
            onStreamFinished: {
                const reply = text.trim();
                if (reply.length > 0) {
                    root.customSpeechText = reply;
                    bubbleDisplayTimer.interval = 9000;
                    bubbleDisplayTimer.restart();
                    heartBurstAnim.restart();
                }
            }
        }
        onExited: (code) => {
            if (code !== 0 && root.customSpeechText === "*thinking...* 🐾") {
                root.customSpeechText = "Meow? *snuggles close* <3";
                bubbleDisplayTimer.interval = 4000;
                bubbleDisplayTimer.restart();
            }
        }
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

        // Animation Bobbing (Music Dancing / Breathing / Walking)
        property real danceTilt: 0
        property real danceBob: 0

        SequentialAnimation {
            running: root.isWalking
            loops: Animation.Infinite
            NumberAnimation { target: petContainer; property: "danceTilt"; from: -8; to: 8; duration: 180; easing.type: Easing.InOutQuad }
            NumberAnimation { target: petContainer; property: "danceTilt"; from: 8; to: -8; duration: 180; easing.type: Easing.InOutQuad }
        }
        SequentialAnimation {
            running: root.isWalking
            loops: Animation.Infinite
            NumberAnimation { target: petContainer; property: "danceBob"; from: 0; to: -5; duration: 90; easing.type: Easing.OutQuad }
            NumberAnimation { target: petContainer; property: "danceBob"; from: -5; to: 0; duration: 90; easing.type: Easing.InQuad }
        }

        SequentialAnimation {
            running: root.isDancing && !root.isWalking
            loops: Animation.Infinite
            NumberAnimation { target: petContainer; property: "danceTilt"; from: -7; to: 7; duration: 320; easing.type: Easing.InOutQuad }
            NumberAnimation { target: petContainer; property: "danceTilt"; from: 7; to: -7; duration: 320; easing.type: Easing.InOutQuad }
        }
        SequentialAnimation {
            running: root.isDancing && !root.isWalking
            loops: Animation.Infinite
            NumberAnimation { target: petContainer; property: "danceBob"; from: 0; to: -6; duration: 160; easing.type: Easing.OutQuad }
            NumberAnimation { target: petContainer; property: "danceBob"; from: -6; to: 0; duration: 160; easing.type: Easing.InQuad }
        }

        // Idle gentle breathing
        SequentialAnimation {
            running: !root.isDancing && !root.isSleeping && !root.isWalking
            loops: Animation.Infinite
            NumberAnimation { target: petContainer; property: "danceBob"; from: 0; to: -2; duration: 1200; easing.type: Easing.InOutSine }
            NumberAnimation { target: petContainer; property: "danceBob"; from: -2; to: 0; duration: 1200; easing.type: Easing.InOutSine }
        }

        // Sleeping gentle heave
        SequentialAnimation {
            running: root.isSleeping && !root.isWalking
            loops: Animation.Infinite
            NumberAnimation { target: petContainer; property: "danceBob"; from: 0; to: -1; duration: 2000; easing.type: Easing.InOutSine }
            NumberAnimation { target: petContainer; property: "danceBob"; from: -1; to: 0; duration: 2000; easing.type: Easing.InOutSine }
        }

        transform: [
            Rotation { origin.x: petContainer.width / 2; origin.y: petContainer.height; angle: petContainer.danceTilt },
            Translate { y: petContainer.danceBob },
            Scale {
                origin.x: petContainer.width / 2
                xScale: root.facingLeft ? -1 : 1
                Behavior on xScale { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
            }
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

    SequentialAnimation {
        id: easterEggAnim
        ParallelAnimation {
            NumberAnimation { target: petContainer; property: "rotation"; from: 0; to: 360; duration: 650; easing.type: Easing.OutBack }
            SequentialAnimation {
                NumberAnimation { target: petContainer; property: "scale"; from: 1.0; to: 1.45; duration: 300; easing.type: Easing.OutBack }
                NumberAnimation { target: petContainer; property: "scale"; from: 1.45; to: 1.0; duration: 350; easing.type: Easing.InOutQuad }
            }
        }
        ScriptAction { script: root.isEasterEggActive = false }
    }

    // Easter Egg Celebratory Sparkles Burst
    Repeater {
        model: ["💖", "✨", "🐾", "⭐", "🌸", "🚀"]
        delegate: Text {
            required property var modelData
            required property int index
            text: modelData
            font.pixelSize: 18 * root.petScale
            visible: root.isEasterEggActive
            x: (root.width / 2) - 10 + (index - 2.5) * 16
            y: root.height / 2
            opacity: 0

            SequentialAnimation on y {
                running: root.isEasterEggActive
                NumberAnimation { from: root.height / 2; to: (root.height / 2) - 50 - (index % 3) * 15; duration: 800; easing.type: Easing.OutQuad }
            }
            SequentialAnimation on opacity {
                running: root.isEasterEggActive
                NumberAnimation { from: 1.0; to: 0; duration: 800; easing.type: Easing.InQuad }
            }
        }
    }
}

