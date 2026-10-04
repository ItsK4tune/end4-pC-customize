pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.services

/**
 * Service managing the ergonomic rest / break feature.
 * Coordinates trigger conditions (continuous work, Pomodoro break, manual),
 * screen overlay states, audio cues, and mindful unlocking.
 */
Singleton {
    id: root

    readonly property bool enabled: (Config.options.rest ? Config.options.rest.enable : true) && Config.ready
    readonly property bool restActive: GlobalStates.restOpen
    readonly property bool warningActive: GlobalStates.restWarningOpen

    property int secondsLeft: 0
    property int totalDuration: 0
    property int workSeconds: 0
    property int warningSecondsLeft: 0
    property string source: "manual" // "manual" | "focusflow" | "work_limit" | "schedule"

    readonly property int workMinutesLimit: Math.max(1, (Config.options.rest && Config.options.rest.triggers) ? Config.options.rest.triggers.workMinutes : 50)
    readonly property int warnSecondsBefore: Math.max(5, (Config.options.rest && Config.options.rest.triggers) ? Config.options.rest.triggers.warnSecondsBefore : 30)
    readonly property int defaultRestMinutes: Math.max(1, (Config.options.rest && Config.options.rest.unlock) ? Config.options.rest.unlock.restMinutes : 5)
    readonly property bool canUnlock: secondsLeft <= 0

    // Breathing Engine: 4-4-4-4 Box Breathing Cycle (16s total)
    // 0: Inhale (4s), 1: Hold (4s), 2: Exhale (4s), 3: Rest (4s)
    property int breathingPhase: 0
    property real breathingProgress: 0.0 // 0.0 to 1.0 within current phase
    property int breathingStepMs: 0

    readonly property var breathingTexts: [
        Translation.tr("Inhale gently..."),
        Translation.tr("Hold your breath..."),
        Translation.tr("Exhale smoothly..."),
        Translation.tr("Rest and relax...")
    ]

    readonly property var ergonomicTips: [
        Translation.tr("Rule 20-20-20: Look at something 20 feet away for 20 seconds."),
        Translation.tr("Roll your shoulders backward and gently relax your neck."),
        Translation.tr("Hydrate: Drink a refreshing glass of water."),
        Translation.tr("Stand up, stretch your spine, and shake out your wrists."),
        Translation.tr("Blink slowly several times to moisten and soothe your eyes.")
    ]

    property int currentTipIndex: 0

    function formatSeconds(secs) {
        const total = Math.max(0, Math.floor(secs));
        const m = Math.floor(total / 60);
        const s = total % 60;
        const mm = m < 10 ? "0" + m : "" + m;
        const ss = s < 10 ? "0" + s : "" + s;
        return `${mm}:${ss}`;
    }

    function startRest(durationSeconds = -1, triggerSource = "manual") {
        if (!root.enabled && triggerSource !== "manual") {
            return;
        }
        if (triggerSource === "focusflow") {
            const pomodoroSync = (Config.options.rest && Config.options.rest.triggers) 
                ? Config.options.rest.triggers.pomodoroSync 
                : true;
            const enforceRest = (Config.options.background.widgets.focusFlow && Config.options.background.widgets.focusFlow.enforceRest !== undefined)
                ? Config.options.background.widgets.focusFlow.enforceRest
                : true;
            if (!pomodoroSync || !enforceRest) {
                return;
            }
        }

        const duration = (durationSeconds > 0) ? durationSeconds : (defaultRestMinutes * 60);
        root.totalDuration = duration;
        root.secondsLeft = duration;
        root.source = triggerSource;
        root.currentTipIndex = Math.floor(Math.random() * root.ergonomicTips.length);
        root.breathingPhase = 0;
        root.breathingProgress = 0.0;
        root.breathingStepMs = 0;

        GlobalStates.restWarningOpen = false;
        GlobalStates.restOpen = true;

        // Pause media playback if requested
        if ((Config.options.rest && Config.options.rest.visual) ? Config.options.rest.visual.pauseMusic : true) {
            MprisController.pauseAll();
        }

        // Play singing bowl chime
        Quickshell.execDetached([`${Directories.scriptPath}/audio/focus-ambient.sh`, "chime"]);

        // Optionally play ambient sound during rest
        if ((Config.options.rest && Config.options.rest.visual) ? Config.options.rest.visual.playAmbientSound : true) {
            const soundType = (Config.options.rest && Config.options.rest.visual) ? Config.options.rest.visual.soundType : "rain";
            Quickshell.execDetached([`${Directories.scriptPath}/audio/focus-ambient.sh`, "play", soundType, "60"]);
        }
    }

    function startWarning(warnSeconds = -1, triggerSource = "work_limit") {
        root.warningSecondsLeft = (warnSeconds > 0) ? warnSeconds : root.warnSecondsBefore;
        root.source = triggerSource;
        GlobalStates.restWarningOpen = true;
    }

    function snooze(minutes = 5) {
        GlobalStates.restWarningOpen = false;
        if (GlobalStates.restOpen) {
            GlobalStates.restOpen = false;
            Quickshell.execDetached([`${Directories.scriptPath}/audio/focus-ambient.sh`, "stop"]);
        }
        // Delay work timer so it triggers again after `minutes`
        root.workSeconds = Math.max(0, (root.workMinutesLimit - minutes) * 60);
    }

    function finishRest() {
        GlobalStates.restOpen = false;
        GlobalStates.restWarningOpen = false;
        root.workSeconds = 0;

        // Stop ambient audio & play gentle completion chime
        Quickshell.execDetached([`${Directories.scriptPath}/audio/focus-ambient.sh`, "stop"]);
        Quickshell.execDetached([`${Directories.scriptPath}/audio/focus-ambient.sh`, "chime"]);

        // Update statistics
        if (Persistent.ready && Persistent.states.rest) {
            Persistent.states.rest.completedToday = (Persistent.states.rest.completedToday ?? 0) + 1;
        }

        Notifications.notify({
            "appName": "Rest & Health",
            "summary": Translation.tr("Break Completed!"),
            "body": Translation.tr("Feeling refreshed? You are ready to resume deep work.")
        });
    }

    function emergencyUnlock() {
        GlobalStates.restOpen = false;
        GlobalStates.restWarningOpen = false;
        root.workSeconds = 0;
        Quickshell.execDetached([`${Directories.scriptPath}/audio/focus-ambient.sh`, "stop"]);
    }

    // 1-second interval tracker for work, warning, and rest
    Timer {
        id: coreSecondTimer
        interval: 1000
        repeat: true
        running: root.enabled || GlobalStates.restOpen || GlobalStates.restWarningOpen
        onTriggered: {
            // Rest state
            if (GlobalStates.restOpen) {
                if (root.secondsLeft > 0) {
                    root.secondsLeft--;
                }
                return;
            }

            // Warning state
            if (GlobalStates.restWarningOpen) {
                if (root.warningSecondsLeft > 0) {
                    root.warningSecondsLeft--;
                } else {
                    root.startRest(-1, root.source);
                }
                return;
            }

            // Work tracking state
            if (root.enabled && ((Config.options.rest && Config.options.rest.triggers) ? Config.options.rest.triggers.continuousWork : true)) {
                if (!GlobalStates.screenLocked) {
                    root.workSeconds++;

                    // Trigger pre-rest warning
                    const warnAt = (root.workMinutesLimit * 60) - root.warnSecondsBefore;
                    if (root.workSeconds === warnAt) {
                        root.startWarning(root.warnSecondsBefore, "work_limit");
                    } else if (root.workSeconds >= root.workMinutesLimit * 60) {
                        root.startRest(-1, "work_limit");
                    }
                }
            }
        }
    }

    // 50ms interval driving smooth breathing animation and tip cycling
    Timer {
        id: breathingAnimTimer
        interval: 50
        repeat: true
        running: GlobalStates.restOpen
        onTriggered: {
            root.breathingStepMs += 50;
            // 4000ms per phase
            root.breathingProgress = Math.min(1.0, (root.breathingStepMs % 4000) / 4000);
            const currentP = Math.floor(root.breathingStepMs / 4000) % 4;
            if (currentP !== root.breathingPhase) {
                root.breathingPhase = currentP;
                if (currentP === 0) {
                    // Rotate tip every full cycle (16s)
                    root.currentTipIndex = (root.currentTipIndex + 1) % root.ergonomicTips.length;
                }
            }
        }
    }
}
