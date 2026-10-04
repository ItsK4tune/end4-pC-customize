import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "focusFlow"
    hoverEnabled: true

    readonly property real singleWidth: 132
    readonly property real cardSpacing: 12
    readonly property real cardHeight: 120
    readonly property real doubleHeight: root.cardHeight * 2 + root.cardSpacing // 252

    readonly property real snapWidth1: root.singleWidth // 132
    readonly property real snapWidth2: root.singleWidth * 2 + root.cardSpacing // 276
    readonly property real snapWidth3: root.singleWidth * 3 + root.cardSpacing * 2 // 420
    readonly property real snapWidth4: root.singleWidth * 4 + root.cardSpacing * 3 // 564

    property string sizeMode: (root.configEntry && root.configEntry.sizeMode) ? root.configEntry.sizeMode : "2x2"

    property real widgetWidth: {
        switch (root.sizeMode) {
            case "1x1": return root.snapWidth1
            case "1x2": return root.snapWidth2
            case "2x1": return root.snapWidth2
            case "2x2": return root.snapWidth2
            case "2x3": return root.snapWidth3
            case "4x2": return root.snapWidth4
            default:    return root.snapWidth3
        }
    }
    property real widgetHeight: root.isCompact ? root.cardHeight : root.doubleHeight

    readonly property bool isCompact: root.sizeMode === "1x2" || root.sizeMode === "2x1"
    readonly property bool isWide: root.sizeMode === "4x2" || root.sizeMode === "2x3"

    implicitWidth: widgetWidth
    implicitHeight: widgetHeight

    Behavior on widgetWidth {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }
    Behavior on widgetHeight {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    function modeForDrag(dx, dy, startWidth) {
        if (dy < -40) return "1x2";
        const w = startWidth + dx;
        if (w > (snapWidth3 + snapWidth4) / 2) return "4x2";
        if (w > (snapWidth2 + snapWidth3) / 2) return "2x3";
        return "2x2";
    }

    readonly property color widgetBorderColor: Appearance.m3colors.darkmode 
        ? Qt.rgba(1, 1, 1, 0.22) 
        : Qt.rgba(0, 0, 0, 0.12)

    // Pomodoro Configuration
    readonly property int focusMinutes: (Config.options.background.widgets.focusFlow && Config.options.background.widgets.focusFlow.focusDuration) ? Config.options.background.widgets.focusFlow.focusDuration : 25
    readonly property int shortBreakMinutes: (Config.options.background.widgets.focusFlow && Config.options.background.widgets.focusFlow.shortBreakDuration) ? Config.options.background.widgets.focusFlow.shortBreakDuration : 5
    readonly property int longBreakMinutes: (Config.options.background.widgets.focusFlow && Config.options.background.widgets.focusFlow.longBreakDuration) ? Config.options.background.widgets.focusFlow.longBreakDuration : 15
    // Enforce Rest (Break Screen overlay trigger)
    readonly property bool restGlobalEnabled: (Config.options.rest ? Config.options.rest.enable : true) && Config.ready
    property bool enforceRest: {
        const ffRest = (Config.options.background.widgets.focusFlow && Config.options.background.widgets.focusFlow.enforceRest !== undefined)
            ? Config.options.background.widgets.focusFlow.enforceRest
            : true;
        const pSync = (Config.options.rest && Config.options.rest.triggers && Config.options.rest.triggers.pomodoroSync !== undefined)
            ? Config.options.rest.triggers.pomodoroSync
            : true;
        return root.restGlobalEnabled && ffRest && pSync;
    }

    function toggleEnforceRest() {
        const newState = !root.enforceRest;
        root.enforceRest = newState;

        if (Config.options.rest) {
            if (Config.options.rest.triggers) {
                Config.options.rest.triggers.pomodoroSync = newState;
            }
            if (newState && !Config.options.rest.enable) {
                Config.options.rest.enable = true;
            }
        }
        if (Config.options.background.widgets.focusFlow) {
            Config.options.background.widgets.focusFlow.enforceRest = newState;
        }
    }

    // State: "focus" | "short_break" | "long_break"
    property string currentMode: "focus"
    property bool isRunning: false
    property int remainingSeconds: focusMinutes * 60
    property int totalSeconds: focusMinutes * 60
    property int completedCycles: 0

    // Audio Engine
    property string activeSound: "off" // "off" | "rain" | "waves" | "brook" | "fireplace"
    property real soundVolume: 0.8

    function cycleSound() {
        const order = ["off", "rain", "waves", "fireplace"];
        const idx = order.indexOf(activeSound);
        activeSound = order[(idx + 1) % order.length];
    }

    function soundIcon(sound) {
        switch (sound) {
            case "rain": return "water_drop";
            case "waves": return "tsunami";
            case "fireplace": return "local_fire_department";
            default: return "volume_off";
        }
    }

    function updateAudio() {
        if (activeSound === "off") {
            Quickshell.execDetached([`${Directories.scriptPath}/audio/focus-ambient.sh`, "stop"]);
        } else {
            const volPct = Math.round(soundVolume * 100);
            Quickshell.execDetached([`${Directories.scriptPath}/audio/focus-ambient.sh`, "play", activeSound, String(volPct)]);
        }
    }

    onActiveSoundChanged: updateAudio()
    onSoundVolumeChanged: updateAudio()

    Component.onDestruction: {
        Quickshell.execDetached([`${Directories.scriptPath}/audio/focus-ambient.sh`, "stop"]);
    }

    function togglePlay() {
        if (isRunning) {
            isRunning = false;
            pomodoroTimer.stop();
        } else {
            isRunning = true;
            pomodoroTimer.start();
        }
    }

    function resetTimer() {
        isRunning = false;
        pomodoroTimer.stop();
        if (currentMode === "focus") {
            totalSeconds = focusMinutes * 60;
        } else if (currentMode === "short_break") {
            totalSeconds = shortBreakMinutes * 60;
        } else {
            totalSeconds = longBreakMinutes * 60;
        }
        remainingSeconds = totalSeconds;
        progressCanvas2x2.requestPaint();
        progressCanvasWide.requestPaint();
    }

    function switchMode(newMode) {
        currentMode = newMode;
        resetTimer();
    }

    function nextPhase() {
        if (currentMode === "focus") {
            completedCycles = completedCycles + 1;
            if (completedCycles % 4 === 0) {
                switchMode("long_break");
            } else {
                switchMode("short_break");
            }

            // If enforce rest is enabled, trigger the Rest Screen immediately
            if (root.enforceRest) {
                RestService.startRest(root.remainingSeconds, "focusflow");
            }
        } else {
            switchMode("focus");
        }

        // Play singing bowl chime
        Quickshell.execDetached([`${Directories.scriptPath}/audio/focus-ambient.sh`, "chime"]);

        // Send desktop notification
        Notifications.notify({
            "appName": "Focus Flow",
            "summary": currentMode === "focus" ? "Time to Focus!" : "Break Time!",
            "body": currentMode === "focus" ? "Dive into your next deep work session." : "Rest your eyes, stretch and breathe."
        });
    }

    Timer {
        id: pomodoroTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (root.remainingSeconds > 0) {
                root.remainingSeconds--;
                progressCanvas2x2.requestPaint();
                progressCanvasWide.requestPaint();
            } else {
                root.nextPhase();
            }
        }
    }

    function formatTime(secs) {
        const m = Math.floor(secs / 60);
        const s = secs % 60;
        const mm = m < 10 ? "0" + m : "" + m;
        const ss = s < 10 ? "0" + s : "" + s;
        return `${mm}:${ss}`;
    }

    Item {
        id: cardWrapper
        anchors.fill: parent

        StyledRectangularShadow { 
            target: contentRect 
            z: -2
            visible: Config.options.background.widgets.shadow
        }

        Rectangle {
            id: contentRect
            anchors.fill: parent
            color: Appearance.colors.colPrimaryContainer
            radius: Appearance.rounding.verylarge
            border.width: 1
            border.color: root.widgetBorderColor
            clip: true

            FastBlurred {
                anchors.fill: parent
                blurSource: root.wallpaperItem
                cardRadius: contentRect.radius
                tint: Appearance.colors.colLayer1
                tintOpacity: 0.55
                trackX: root.x  
                trackY: root.y
                visible: Config.options.background.widgets.blurWidgets 
            }

            // Compact 1x2 Mode Layout (276 x 120)
            ColumnLayout {
                visible: root.isCompact
                anchors { fill: parent; margins: 12 }
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        spacing: 6
                        Layout.alignment: Qt.AlignVCenter
                        StyledText {
                            text: root.formatTime(root.remainingSeconds)
                            font.pixelSize: 22
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        Rectangle {
                            implicitWidth: mode1x2Label.implicitWidth + 8
                            implicitHeight: 18
                            radius: 9
                            color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.75)
                            StyledText {
                                id: mode1x2Label
                                anchors.centerIn: parent
                                text: root.currentMode === "focus" ? Translation.tr("FOCUS") : Translation.tr("BREAK")
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: Appearance.colors.colPrimary
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Enforce Rest Toggle Button
                    Rectangle {
                        width: 24; height: 24; radius: 12
                        color: root.enforceRest ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.75)
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "spa"
                            iconSize: 14
                            color: root.enforceRest ? Appearance.colors.colOnPrimary : Appearance.colors.colOnPrimaryContainer
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleEnforceRest()
                        }
                    }

                    // Play / Pause Button
                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: Appearance.colors.colPrimary
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: root.isRunning ? "pause" : "play_arrow"
                            iconSize: 16
                            color: Appearance.colors.colOnPrimary
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.togglePlay()
                        }
                    }
                }

                // Horizontal Progress Bar
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 5
                    radius: 2.5
                    color: Qt.rgba(1, 1, 1, 0.12)

                    Rectangle {
                        width: parent.width * (root.totalSeconds > 0 ? (root.remainingSeconds / root.totalSeconds) : 0)
                        height: parent.height
                        radius: 2.5
                        color: Appearance.colors.colPrimary
                    }
                }

                // Mode Buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: [
                            { id: "focus", label: Translation.tr("Focus") },
                            { id: "short_break", label: Translation.tr("Short") },
                            { id: "long_break", label: Translation.tr("Long") }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 22
                            radius: 11
                            color: root.currentMode === modelData.id ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                            StyledText {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: root.currentMode === modelData.id ? Font.Bold : Font.Normal
                                color: root.currentMode === modelData.id ? Appearance.colors.colOnPrimary : Appearance.colors.colOnPrimaryContainer
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.switchMode(modelData.id)
                            }
                        }
                    }
                }
            }

            // Standard 2x2 Mode Layout (276 x 252 - Abstract, Balanced & Zero Overflow)
            ColumnLayout {
                visible: !root.isCompact && !root.isWide
                anchors { fill: parent; margins: 12 }
                spacing: 6

                // Top Header: Mode Switcher & Session Status
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        spacing: 3
                        Repeater {
                            model: [
                                { id: "focus", label: Translation.tr("Focus") },
                                { id: "short_break", label: Translation.tr("Short") },
                                { id: "long_break", label: Translation.tr("Long") }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                implicitWidth: modeBtnText.implicitWidth + 12
                                implicitHeight: 22
                                radius: 11
                                color: root.currentMode === modelData.id 
                                    ? Appearance.colors.colPrimary 
                                    : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                                border.width: 1
                                border.color: root.currentMode === modelData.id ? Appearance.colors.colPrimary : root.widgetBorderColor

                                StyledText {
                                    id: modeBtnText
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.pixelSize: 10
                                    font.weight: root.currentMode === modelData.id ? Font.Bold : Font.Normal
                                    color: root.currentMode === modelData.id ? Appearance.colors.colOnPrimary : Appearance.colors.colOnPrimaryContainer
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.switchMode(modelData.id)
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Enforce Rest Toggle Icon (Auto-Rest Screen on break)
                    Rectangle {
                        id: restToggle2x2
                        width: 22; height: 22; radius: 11
                        color: root.enforceRest ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.2) : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                        border.width: 1
                        border.color: root.enforceRest ? Appearance.colors.colPrimary : root.widgetBorderColor
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "spa"
                            iconSize: 13
                            color: root.enforceRest ? Appearance.colors.colOnPrimary : Appearance.colors.colOnPrimaryContainer
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleEnforceRest()
                        }
                    }

                    // Pomodoro Cycle Progress Badge (e.g. 1/4 sessions)
                    Rectangle {
                        id: cycleBadge2x2
                        implicitWidth: cycleBadgeRow.implicitWidth + 8
                        implicitHeight: 22
                        radius: 11
                        color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                        border.width: 1
                        border.color: root.widgetBorderColor

                        RowLayout {
                            id: cycleBadgeRow
                            anchors.centerIn: parent
                            spacing: 4

                            StyledText {
                                text: `${(root.completedCycles % 4) + 1}/4`
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: Appearance.colors.colPrimary
                            }

                            // 4 cycle progress dots
                            RowLayout {
                                spacing: 2.5
                                Repeater {
                                    model: 4
                                    delegate: Rectangle {
                                        required property int index
                                        width: 5; height: 5; radius: 2.5
                                        color: (index < (root.completedCycles % 4))
                                            ? Appearance.colors.colPrimary
                                            : Qt.rgba(1, 1, 1, 0.2)
                                    }
                                }
                            }
                        }
                    }
                }

                // Center Timer Dial
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 110

                    // Pulsing breathing ring behind dial
                    Rectangle {
                        anchors.centerIn: parent
                        width: 104; height: 104; radius: 52
                        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.8)
                        visible: root.isRunning

                        SequentialAnimation on scale {
                            running: root.isRunning
                            loops: Animation.Infinite
                            NumberAnimation { to: 1.12; duration: 4000; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 4000; easing.type: Easing.InOutSine }
                        }
                    }

                    Canvas {
                        id: progressCanvas2x2
                        anchors.centerIn: parent
                        width: 100; height: 100

                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            const cx = width / 2;
                            const cy = height / 2;
                            const r = (width / 2) - 5;

                            ctx.beginPath();
                            ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                            ctx.strokeStyle = "rgba(255, 255, 255, 0.12)";
                            ctx.lineWidth = 5;
                            ctx.stroke();

                            const fraction = root.totalSeconds > 0 ? (root.remainingSeconds / root.totalSeconds) : 0;
                            const startAngle = -Math.PI / 2;
                            const endAngle = startAngle + (2 * Math.PI * fraction);

                            ctx.beginPath();
                            ctx.arc(cx, cy, r, startAngle, endAngle, false);
                            ctx.strokeStyle = Appearance.colors.colPrimary;
                            ctx.lineWidth = 5;
                            ctx.lineCap = "round";
                            ctx.stroke();
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: -2
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.formatTime(root.remainingSeconds)
                            font.pixelSize: 26
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.currentMode.replace("_", " ").toUpperCase()
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colPrimary
                        }
                    }
                }

                // Action Controls & Ambient Audio Cycle
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12

                    // Reset Button
                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: resetMouse2.containsMouse ? ColorUtils.transparentize(Appearance.colors.colLayer0, 0.6) : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                        border.width: 1
                        border.color: root.widgetBorderColor
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "replay"
                            iconSize: 15
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        MouseArea {
                            id: resetMouse2
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.resetTimer()
                        }
                    }

                    // Main Play/Pause Button
                    Rectangle {
                        width: 36; height: 36; radius: 18
                        color: Appearance.colors.colPrimary

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: root.isRunning ? "pause" : "play_arrow"
                            iconSize: 20
                            color: Appearance.colors.colOnPrimary
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.togglePlay()
                        }
                    }

                    // Skip Button
                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: skipMouse2.containsMouse ? ColorUtils.transparentize(Appearance.colors.colLayer0, 0.6) : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                        border.width: 1
                        border.color: root.widgetBorderColor
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "skip_next"
                            iconSize: 15
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        MouseArea {
                            id: skipMouse2
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.nextPhase()
                        }
                    }

                    // Sound Toggle Pill (Cycle on tap)
                    Rectangle {
                        implicitWidth: soundPillRow.implicitWidth + 10
                        implicitHeight: 28
                        radius: 14
                        color: root.activeSound !== "off" 
                            ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.2) 
                            : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                        border.width: 1
                        border.color: root.activeSound !== "off" ? Appearance.colors.colPrimary : root.widgetBorderColor

                        RowLayout {
                            id: soundPillRow
                            anchors.centerIn: parent
                            spacing: 4
                            MaterialSymbol {
                                text: root.soundIcon(root.activeSound)
                                iconSize: 14
                                color: root.activeSound !== "off" ? Appearance.colors.colOnPrimary : Appearance.colors.colOnPrimaryContainer
                            }
                            StyledText {
                                text: root.activeSound === "off" ? Translation.tr("Sound") : root.activeSound.toUpperCase()
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: root.activeSound !== "off" ? Appearance.colors.colOnPrimary : Appearance.colors.colOnPrimaryContainer
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cycleSound()
                        }
                    }
                }
            }

            // Wide Modes Layout: 4x2 & 2x3 (Side-by-side 2-column layout - ZERO OVERFLOW)
            RowLayout {
                visible: root.isWide
                anchors { fill: parent; margins: 14 }
                spacing: 14

                // Left Column: Timer Dial & Controls
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 6

                    // Mode Switcher Pills
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 4

                        Repeater {
                            model: [
                                { id: "focus", label: Translation.tr("Focus") },
                                { id: "short_break", label: Translation.tr("Short Break") },
                                { id: "long_break", label: Translation.tr("Long Break") }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                implicitWidth: wideModeText.implicitWidth + 14
                                implicitHeight: 22
                                radius: 11
                                color: root.currentMode === modelData.id 
                                    ? Appearance.colors.colPrimary 
                                    : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                                border.width: 1
                                border.color: root.currentMode === modelData.id ? Appearance.colors.colPrimary : root.widgetBorderColor

                                StyledText {
                                    id: wideModeText
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.pixelSize: 10
                                    font.weight: root.currentMode === modelData.id ? Font.Bold : Font.Normal
                                    color: root.currentMode === modelData.id ? Appearance.colors.colOnPrimary : Appearance.colors.colOnPrimaryContainer
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.switchMode(modelData.id)
                                }
                            }
                        }
                    }

                    // Timer Dial
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Rectangle {
                            anchors.centerIn: parent
                            width: 100; height: 100; radius: 50
                            color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.8)
                            visible: root.isRunning

                            SequentialAnimation on scale {
                                running: root.isRunning
                                loops: Animation.Infinite
                                NumberAnimation { to: 1.12; duration: 4000; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 4000; easing.type: Easing.InOutSine }
                            }
                        }

                        Canvas {
                            id: progressCanvasWide
                            anchors.centerIn: parent
                            width: 96; height: 96

                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                const cx = width / 2;
                                const cy = height / 2;
                                const r = (width / 2) - 5;

                                ctx.beginPath();
                                ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                                ctx.strokeStyle = "rgba(255, 255, 255, 0.12)";
                                ctx.lineWidth = 5;
                                ctx.stroke();

                                const fraction = root.totalSeconds > 0 ? (root.remainingSeconds / root.totalSeconds) : 0;
                                const startAngle = -Math.PI / 2;
                                const endAngle = startAngle + (2 * Math.PI * fraction);

                                ctx.beginPath();
                                ctx.arc(cx, cy, r, startAngle, endAngle, false);
                                ctx.strokeStyle = Appearance.colors.colPrimary;
                                ctx.lineWidth = 5;
                                ctx.lineCap = "round";
                                ctx.stroke();
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: -2
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.formatTime(root.remainingSeconds)
                                font.pixelSize: 24
                                font.weight: Font.Bold
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.currentMode.replace("_", " ").toUpperCase()
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colPrimary
                            }
                        }
                    }

                    // Action Controls
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 12

                        Rectangle {
                            width: 28; height: 28; radius: 14
                            color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                            border.width: 1
                            border.color: root.widgetBorderColor
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "replay"
                                iconSize: 15
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.resetTimer()
                            }
                        }

                        Rectangle {
                            width: 36; height: 36; radius: 18
                            color: Appearance.colors.colPrimary
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: root.isRunning ? "pause" : "play_arrow"
                                iconSize: 20
                                color: Appearance.colors.colOnPrimary
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.togglePlay()
                            }
                        }

                        Rectangle {
                            width: 28; height: 28; radius: 14
                            color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                            border.width: 1
                            border.color: root.widgetBorderColor
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "skip_next"
                                iconSize: 15
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.nextPhase()
                            }
                        }
                    }
                }

                // Vertical Divider
                Rectangle {
                    width: 1
                    Layout.fillHeight: true
                    Layout.topMargin: 8
                    Layout.bottomMargin: 8
                    color: Appearance.colors.colLayer0Border
                    opacity: 0.5
                }

                // Right Column: Session Stats & Ambient Soundscape Matrix
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8

                    // Session Info & Rest Screen Toggle
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        // Cycle Badge + Dots with Tooltip
                        Rectangle {
                            id: cycleBadgeWide
                            implicitWidth: cycleWideRow.implicitWidth + 8
                            implicitHeight: 22
                            radius: 11
                            color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                            border.width: 1
                            border.color: root.widgetBorderColor

                            RowLayout {
                                id: cycleWideRow
                                anchors.centerIn: parent
                                spacing: 4

                                StyledText {
                                    text: `#${(root.completedCycles % 4) + 1}/4`
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: Appearance.colors.colPrimary
                                }

                                RowLayout {
                                    spacing: 3
                                    Repeater {
                                        model: 4
                                        delegate: Rectangle {
                                            required property int index
                                            width: 5; height: 5; radius: 2.5
                                            color: (index < (root.completedCycles % 4))
                                                ? Appearance.colors.colPrimary
                                                : Qt.rgba(1, 1, 1, 0.2)
                                        }
                                    }
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Enforce Rest Badge / Button
                        Rectangle {
                            id: restBadgeWide
                            implicitWidth: restBadgeRow.implicitWidth + 10
                            implicitHeight: 22
                            radius: 11
                            color: root.enforceRest ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.2) : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                            border.width: 1
                            border.color: root.enforceRest ? Appearance.colors.colPrimary : root.widgetBorderColor

                            RowLayout {
                                id: restBadgeRow
                                anchors.centerIn: parent
                                spacing: 3
                                MaterialSymbol {
                                    text: "spa"
                                    iconSize: 13
                                    color: root.enforceRest ? Appearance.colors.colOnPrimary : Appearance.colors.colOnPrimaryContainer
                                }
                                StyledText {
                                    text: root.enforceRest ? Translation.tr("Rest ON") : Translation.tr("Rest OFF")
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    color: root.enforceRest ? Appearance.colors.colOnPrimary : Appearance.colors.colOnPrimaryContainer
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleEnforceRest()
                            }
                        }
                    }

                    // Ambient Audio 2x2 Grid
                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 2
                        rowSpacing: 6
                        columnSpacing: 6

                        Repeater {
                            model: [
                                { id: "off",       label: Translation.tr("Mute"),  icon: "volume_off" },
                                { id: "rain",      label: Translation.tr("Rain"),  icon: "water_drop" },
                                { id: "waves",     label: Translation.tr("Ocean"), icon: "tsunami" },
                                { id: "fireplace", label: Translation.tr("Fire"),  icon: "local_fire_department" }
                            ]
                            delegate: Rectangle {
                                id: soundCard
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Appearance.rounding.small
                                color: root.activeSound === soundCard.modelData.id 
                                    ? Appearance.colors.colPrimary 
                                    : (soundCardMouse.containsMouse ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.8) : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78))
                                border.width: 1
                                border.color: root.activeSound === soundCard.modelData.id ? Appearance.colors.colPrimary : root.widgetBorderColor

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    MaterialSymbol {
                                        text: soundCard.modelData.icon
                                        iconSize: 14
                                        color: root.activeSound === soundCard.modelData.id ? Appearance.colors.colOnPrimary : Appearance.colors.colOnPrimaryContainer
                                    }
                                    StyledText {
                                        text: soundCard.modelData.label
                                        font.pixelSize: 11
                                        font.weight: root.activeSound === soundCard.modelData.id ? Font.Bold : Font.Normal
                                        color: root.activeSound === soundCard.modelData.id ? Appearance.colors.colOnPrimary : Appearance.colors.colOnPrimaryContainer
                                    }
                                }

                                MouseArea {
                                    id: soundCardMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.activeSound = soundCard.modelData.id
                                }
                            }
                        }
                    }
                }
            }
        }

        ResizeHandler {
            anchorItem: contentRect
            handleSize: 28
            hoverActive: root.containsMouse
            locked: Config.options.background.widgetsLocked
            currentWidth: root.widgetWidth
            resizeMode: "diagonal"
            onResizedXY: (dx, dy, startWidth) => { root.sizeMode = root.modeForDrag(dx, dy, startWidth) }
            onResizeFinished: {
                if (root.configEntry) {
                    root.configEntry.sizeMode = root.sizeMode
                }
            }
        }
    }
}
