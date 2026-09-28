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

    readonly property real cardWidth: 280
    readonly property real cardHeight: 252
    implicitWidth: root.cardWidth
    implicitHeight: root.cardHeight

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
    property string activeSound: "off" // "off" | "rain" | "waves" | "alpha" | "theta"
    property real soundVolume: 0.8 // default audible volume

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

        // Play gentle completion chime
        Quickshell.execDetached([`${Directories.scriptPath}/audio/focus-ambient.sh`, "chime"]);

        // Send notification
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

            ColumnLayout {
                anchors { fill: parent; margins: 12 }
                spacing: 6

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        width: 26; height: 26; radius: 13
                        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.75)
                        border.width: 1
                        border.color: root.widgetBorderColor
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "psychology"
                            iconSize: 16
                            color: Appearance.colors.colPrimary
                        }
                    }

                    StyledText {
                        text: Translation.tr("Focus Flow")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnPrimaryContainer
                    }

                    Item { Layout.fillWidth: true }

                    // Cycle Dots
                    RowLayout {
                        spacing: 4
                        Repeater {
                            model: 4
                            delegate: Rectangle {
                                required property int index
                                width: 7; height: 7; radius: 3.5
                                color: (index < (root.completedCycles % 4))
                                    ? Appearance.colors.colPrimary
                                    : Qt.rgba(1, 1, 1, 0.2)
                                border.width: 1
                                border.color: root.widgetBorderColor
                            }
                        }
                    }
                }

                // Mode Tabs
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 22
                        radius: 11
                        color: root.currentMode === "focus" 
                            ? Appearance.colors.colPrimary
                            : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                        StyledText {
                            anchors.centerIn: parent
                            text: Translation.tr("Focus")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: root.currentMode === "focus" ? Font.Bold : Font.Normal
                            color: root.currentMode === "focus" ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.switchMode("focus")
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 22
                        radius: 11
                        color: root.currentMode === "short_break" 
                            ? Appearance.colors.colPrimary
                            : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                        StyledText {
                            anchors.centerIn: parent
                            text: Translation.tr("Short Break")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: root.currentMode === "short_break" ? Font.Bold : Font.Normal
                            color: root.currentMode === "short_break" ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.switchMode("short_break")
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 22
                        radius: 11
                        color: root.currentMode === "long_break" 
                            ? Appearance.colors.colPrimary
                            : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                        StyledText {
                            anchors.centerIn: parent
                            text: Translation.tr("Long Break")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: root.currentMode === "long_break" ? Font.Bold : Font.Normal
                            color: root.currentMode === "long_break" ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.switchMode("long_break")
                        }
                    }
                }

                // Center Timer Display with Circular Dial
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 100

                    // Breathing guide glow circle
                    Rectangle {
                        id: breathingGlow
                        anchors.centerIn: parent
                        width: 96; height: 96; radius: 48
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
                            NumberAnimation { to: 0.8; duration: 4000; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0.2; duration: 4000; easing.type: Easing.InOutSine }
                        }
                    }

                    Canvas {
                        id: progressCanvas
                        anchors.centerIn: parent
                        width: 92; height: 92

                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            const cx = width / 2;
                            const cy = height / 2;
                            const r = (width / 2) - 5;

                            // Background Track
                            ctx.beginPath();
                            ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                            ctx.strokeStyle = "rgba(255, 255, 255, 0.12)";
                            ctx.lineWidth = 4;
                            ctx.stroke();

                            // Progress Arc
                            const fraction = root.totalSeconds > 0 ? (root.remainingSeconds / root.totalSeconds) : 0;
                            const startAngle = -Math.PI / 2;
                            const endAngle = startAngle + (2 * Math.PI * fraction);

                            ctx.beginPath();
                            ctx.arc(cx, cy, r, startAngle, endAngle, false);
                            ctx.strokeStyle = Appearance.colors.colPrimary;
                            ctx.lineWidth = 4;
                            ctx.lineCap = "round";
                            ctx.stroke();
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 0
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.formatTime(root.remainingSeconds)
                            font.pixelSize: 22
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.currentMode.replace("_", " ").toUpperCase()
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colSubtext
                        }
                    }
                }

                // Action Controls: Play/Pause, Reset, Skip
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12

                    // Reset
                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: resetMouse.containsMouse ? ColorUtils.transparentize(Appearance.colors.colLayer0, 0.6) : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                        border.width: 1
                        border.color: root.widgetBorderColor
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "replay"
                            iconSize: 15
                            color: Appearance.colors.colSubtext
                        }
                        MouseArea {
                            id: resetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.resetTimer()
                        }
                    }

                    // Main Play/Pause
                    Rectangle {
                        width: 36; height: 36; radius: 18
                        color: Appearance.colors.colPrimary
                        border.width: 1
                        border.color: root.widgetBorderColor

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

                    // Skip
                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: skipMouse.containsMouse ? ColorUtils.transparentize(Appearance.colors.colLayer0, 0.6) : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                        border.width: 1
                        border.color: root.widgetBorderColor
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "skip_next"
                            iconSize: 15
                            color: Appearance.colors.colSubtext
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

                // Soundscape Mixer Section
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    MaterialSymbol {
                        text: root.activeSound === "off" ? "volume_off" : "graphic_eq"
                        iconSize: 15
                        color: root.activeSound === "off" ? Appearance.colors.colSubtext : Appearance.colors.colPrimary
                    }

                    Repeater {
                        model: [
                            { id: "off",   label: "Off" },
                            { id: "rain",  label: "Rain" },
                            { id: "waves", label: "Waves" },
                            { id: "alpha", label: "α 10Hz" },
                            { id: "theta", label: "θ 6Hz" }
                        ]
                        delegate: Rectangle {
                            id: soundPill
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 20
                            radius: 10
                            color: root.activeSound === soundPill.modelData.id 
                                ? Appearance.colors.colPrimary
                                : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                            border.width: 1
                            border.color: root.activeSound === soundPill.modelData.id ? Appearance.colors.colPrimary : root.widgetBorderColor

                            StyledText {
                                anchors.centerIn: parent
                                text: soundPill.modelData.label
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.weight: root.activeSound === soundPill.modelData.id ? Font.Bold : Font.Normal
                                color: root.activeSound === soundPill.modelData.id ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
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
    }
}
