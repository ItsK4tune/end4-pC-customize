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

    readonly property real snapWidth1: 300
    readonly property real snapWidth2: 420
    readonly property real cardHeight1: 120
    readonly property real cardHeight2: 252

    property string sizeMode: root.configEntry?.sizeMode ?? "2x2"

    property real widgetWidth: root.sizeMode === "2x3" ? snapWidth2 : snapWidth1
    property real widgetHeight: root.sizeMode === "1x2" ? cardHeight1 : cardHeight2

    implicitWidth: widgetWidth
    implicitHeight: widgetHeight

    Behavior on widgetWidth {
        NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
    }
    Behavior on widgetHeight {
        NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
    }

    function modeForDrag(dx, dy, startWidth) {
        const mid = (snapWidth1 + snapWidth2) / 2;
        const newWidth = startWidth + dx;
        if (newWidth >= mid) return "2x3";
        if (dy < -40) return "1x2";
        if (dy > 40) return "2x2";
        return root.sizeMode;
    }

    readonly property color widgetBorderColor: Appearance.m3colors.darkmode 
        ? Qt.rgba(1, 1, 1, 0.22) 
        : Qt.rgba(0, 0, 0, 0.12)

    // Pomodoro Configuration
    readonly property int focusMinutes: Config.options.background.widgets.focusFlow?.focusDuration ?? 25
    readonly property int shortBreakMinutes: Config.options.background.widgets.focusFlow?.shortBreakDuration ?? 5
    readonly property int longBreakMinutes: Config.options.background.widgets.focusFlow?.longBreakDuration ?? 15

    // State: "focus" | "short_break" | "long_break"
    property string currentMode: "focus"
    property bool isRunning: false
    property int remainingSeconds: focusMinutes * 60
    property int totalSeconds: focusMinutes * 60
    property int completedCycles: 0 // completed focus sessions

    // Audio Engine
    property string activeSound: "off" // "off" | "rain" | "waves" | "brook" | "fireplace"
    property real soundVolume: 0.8

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
        progressCanvas.requestPaint();
    }

    function switchMode(newMode) {
        currentMode = newMode;
        resetTimer();
    }

    function nextPhase() {
        if (currentMode === "focus") {
            completedCycles = (completedCycles + 1);
            if (completedCycles % 4 === 0) {
                switchMode("long_break");
            } else {
                switchMode("short_break");
            }
        } else {
            switchMode("focus");
        }

        // Play gentle authentic completion singing bowl chime
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
                progressCanvas.requestPaint();
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

        StyledDropShadow { 
            target: contentRect 
            visible: Config.options.background.widgets.shadow
        }

        Rectangle {
            id: contentRect
            anchors.fill: parent
            color: Appearance.colors.colPrimaryContainer
            radius: Appearance.rounding?.verylarge ?? 30
            border.width: 1
            border.color: root.widgetBorderColor

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

            // Compact 1x2 Mode Layout
            ColumnLayout {
                visible: root.sizeMode === "1x2"
                anchors { fill: parent; margins: 14 }
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        spacing: 6
                        StyledText {
                            text: root.currentMode === "focus" 
                                ? Translation.tr("Focus") 
                                : (root.currentMode === "short_break" ? Translation.tr("Short Break") : Translation.tr("Long Break"))
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        Rectangle {
                            implicitWidth: cycleText1.implicitWidth + 8
                            implicitHeight: 18
                            radius: 9
                            color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.75)
                            StyledText {
                                id: cycleText1
                                anchors.centerIn: parent
                                text: `#${root.completedCycles + 1}`
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colPrimary
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Big Compact Timer Digits
                    StyledText {
                        text: root.formatTime(root.remainingSeconds)
                        font.pixelSize: 26
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnPrimaryContainer
                    }

                    // Compact Play/Pause
                    Rectangle {
                        width: 32; height: 32; radius: 16
                        color: Appearance.colors.colPrimary
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: root.isRunning ? "pause" : "play_arrow"
                            iconSize: 18
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
                    implicitHeight: 6
                    radius: 3
                    color: Qt.rgba(1, 1, 1, 0.12)

                    Rectangle {
                        width: parent.width * (root.totalSeconds > 0 ? (root.remainingSeconds / root.totalSeconds) : 0)
                        height: parent.height
                        radius: 3
                        color: Appearance.colors.colPrimary
                    }
                }

                // Quick Mode Switch Buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: [
                            { id: "focus", label: "Focus" },
                            { id: "short_break", label: "Short" },
                            { id: "long_break", label: "Long" }
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

            // Standard 2x2 and 2x3 Modes Layout
            ColumnLayout {
                visible: root.sizeMode !== "1x2"
                anchors { fill: parent; margins: 14 }
                spacing: 8

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        spacing: 6
                        StyledText {
                            text: root.currentMode === "focus" 
                                ? Translation.tr("Focus Session") 
                                : (root.currentMode === "short_break" ? Translation.tr("Short Break") : Translation.tr("Long Break"))
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        Rectangle {
                            implicitWidth: cycleText2.implicitWidth + 8
                            implicitHeight: 18
                            radius: 9
                            color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.75)
                            StyledText {
                                id: cycleText2
                                anchors.centerIn: parent
                                text: `#${root.completedCycles + 1}`
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colPrimary
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Cycle Dots
                    RowLayout {
                        spacing: 4
                        Repeater {
                            model: 4
                            delegate: Rectangle {
                                required property int index
                                width: 8; height: 8; radius: 4
                                color: (index < (root.completedCycles % 4))
                                    ? Appearance.colors.colPrimary
                                    : Qt.rgba(1, 1, 1, 0.2)
                                border.width: 1
                                border.color: root.widgetBorderColor
                            }
                        }
                    }
                }

                // Mode Tabs (Enlarged for readability & ergonomics)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Repeater {
                        model: [
                            { id: "focus", label: Translation.tr("Focus") },
                            { id: "short_break", label: Translation.tr("Short Break") },
                            { id: "long_break", label: Translation.tr("Long Break") }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 26
                            radius: 13
                            color: root.currentMode === modelData.id 
                                ? Appearance.colors.colPrimary
                                : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                            border.width: 1
                            border.color: root.currentMode === modelData.id ? Appearance.colors.colPrimary : root.widgetBorderColor

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

                // Main Content Body (Adapts in 2x3 dashboard mode)
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12

                    // Center Timer Display with Circular Dial
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        // Breathing guide glow circle
                        Rectangle {
                            id: breathingGlow
                            anchors.centerIn: parent
                            width: 104; height: 104; radius: 52
                            color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.75)
                            visible: root.isRunning

                            SequentialAnimation on scale {
                                running: root.isRunning
                                loops: Animation.Infinite
                                NumberAnimation { to: 1.15; duration: 4000; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 4000; easing.type: Easing.InOutSine }
                            }
                            SequentialAnimation on opacity {
                                running: root.isRunning
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.85; duration: 4000; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 0.2; duration: 4000; easing.type: Easing.InOutSine }
                            }
                        }

                        Canvas {
                            id: progressCanvas
                            anchors.centerIn: parent
                            width: 100; height: 100

                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                const cx = width / 2;
                                const cy = height / 2;
                                const r = (width / 2) - 6;

                                // Background Track
                                ctx.beginPath();
                                ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                                ctx.strokeStyle = "rgba(255, 255, 255, 0.12)";
                                ctx.lineWidth = 5;
                                ctx.stroke();

                                // Progress Arc
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
                            spacing: 1
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.formatTime(root.remainingSeconds)
                                font.pixelSize: 28
                                font.weight: Font.Bold
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.currentMode.replace("_", " ").toUpperCase()
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colPrimary
                            }
                        }
                    }

                    // Extra Side Panel for 2x3 Mode (Soundscape Controls & Stats)
                    ColumnLayout {
                        visible: root.sizeMode === "2x3"
                        implicitWidth: 150
                        Layout.fillHeight: true
                        spacing: 8

                        StyledText {
                            text: Translation.tr("Ambient Sound")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnPrimaryContainer
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Repeater {
                                model: [
                                    { id: "off",       label: "Off",       icon: "volume_off" },
                                    { id: "rain",      label: "Rain",      icon: "water_drop" },
                                    { id: "waves",     label: "Ocean",     icon: "tsunami" },
                                    { id: "brook",     label: "Brook",     icon: "waves" },
                                    { id: "fireplace", label: "Fireplace", icon: "local_fire_department" }
                                ]
                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 24
                                    radius: 12
                                    color: root.activeSound === modelData.id ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                                    border.width: 1
                                    border.color: root.activeSound === modelData.id ? Appearance.colors.colPrimary : root.widgetBorderColor

                                    RowLayout {
                                        anchors { fill: parent; margins: 4; leftMargin: 8; rightMargin: 8 }
                                        spacing: 6
                                        MaterialSymbol {
                                            text: modelData.icon
                                            iconSize: 14
                                            color: root.activeSound === modelData.id ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                                        }
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: modelData.label
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            font.weight: root.activeSound === modelData.id ? Font.Bold : Font.Normal
                                            color: root.activeSound === modelData.id ? Appearance.colors.colOnPrimary : Appearance.colors.colOnPrimaryContainer
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.activeSound = modelData.id
                                    }
                                }
                            }
                        }
                    }
                }

                // Action Controls: Play/Pause, Reset, Skip
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 14

                    // Reset Button
                    Rectangle {
                        width: 32; height: 32; radius: 16
                        color: resetMouse.containsMouse ? ColorUtils.transparentize(Appearance.colors.colLayer0, 0.6) : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                        border.width: 1
                        border.color: root.widgetBorderColor
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "replay"
                            iconSize: 17
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        MouseArea {
                            id: resetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.resetTimer()
                        }
                    }

                    // Main Play/Pause Button
                    Rectangle {
                        width: 40; height: 40; radius: 20
                        color: Appearance.colors.colPrimary
                        border.width: 1
                        border.color: root.widgetBorderColor

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: root.isRunning ? "pause" : "play_arrow"
                            iconSize: 22
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
                        width: 32; height: 32; radius: 16
                        color: skipMouse.containsMouse ? ColorUtils.transparentize(Appearance.colors.colLayer0, 0.6) : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                        border.width: 1
                        border.color: root.widgetBorderColor
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "skip_next"
                            iconSize: 17
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        MouseArea {
                            id: skipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.nextPhase()
                        }
                    }
                }

                // Soundscape Mixer Section (Shown in 2x2 mode)
                RowLayout {
                    visible: root.sizeMode === "2x2"
                    Layout.fillWidth: true
                    Layout.rightMargin: 20
                    Layout.bottomMargin: 4
                    spacing: 4

                    MaterialSymbol {
                        text: root.activeSound === "off" ? "volume_off" : "graphic_eq"
                        iconSize: 16
                        color: root.activeSound === "off" ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colPrimary
                    }

                    Repeater {
                        model: [
                            { id: "off",       label: "Off" },
                            { id: "rain",      label: "Rain" },
                            { id: "waves",     label: "Ocean" },
                            { id: "brook",     label: "Brook" },
                            { id: "fireplace", label: "Fire" }
                        ]
                        delegate: Rectangle {
                            id: soundPill
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 24
                            radius: 12
                            color: root.activeSound === soundPill.modelData.id 
                                ? Appearance.colors.colPrimary
                                : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                            border.width: 1
                            border.color: root.activeSound === soundPill.modelData.id ? Appearance.colors.colPrimary : root.widgetBorderColor

                            StyledText {
                                anchors.centerIn: parent
                                text: soundPill.modelData.label
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: root.activeSound === soundPill.modelData.id ? Font.Bold : Font.Normal
                                color: root.activeSound === soundPill.modelData.id ? Appearance.colors.colOnPrimary : Appearance.colors.colOnPrimaryContainer
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.activeSound = soundPill.modelData.id;
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
