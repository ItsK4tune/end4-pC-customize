pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    readonly property MprisPlayer activePlayer: MprisController.activePlayer

    property var lyricsLines: []
    property int activeIndex: -1
    property string status: "loading"
    property var slots: ["", "", "", "", "", "", ""]

    readonly property int before: 3
    readonly property int after:  3
    readonly property int total:  7

    function buildSlots(idx) {
        let result = []
        for (let i = 0; i < root.total; i++) {
            let lineIdx = idx - root.before + i
            if (lineIdx >= 0 && lineIdx < root.lyricsLines.length)
                result.push(root.lyricsLines[lineIdx].text || "♪")
            else
                result.push("")
        }
        return result
    }

    property real manualOffset: 0.0
    property var savedOffsets: ({})
    readonly property string offsetsFilePath: FileUtils.trimFileProtocol(`${Directories.cache}/lyrics_offsets.json`)

    FileView {
        id: offsetFileView
        path: root.offsetsFilePath
        onLoaded: {
            try {
                const parsed = JSON.parse(offsetFileView.text())
                root.savedOffsets = (parsed && typeof parsed === "object") ? parsed : {}
            } catch(e) {
                root.savedOffsets = {}
            }
        }
        onLoadFailed: (error) => {
            root.savedOffsets = {}
        }
    }

    property var manualOverrides: ({})
    readonly property string manualOverridesFilePath: FileUtils.trimFileProtocol(`${Directories.cache}/lyrics_manual_overrides.json`)

    FileView {
        id: manualOverridesFileView
        path: root.manualOverridesFilePath
        onLoaded: {
            try {
                const parsed = JSON.parse(manualOverridesFileView.text())
                root.manualOverrides = (parsed && typeof parsed === "object") ? parsed : {}
            } catch(e) {
                root.manualOverrides = {}
            }
        }
        onLoadFailed: (error) => {
            root.manualOverrides = {}
        }
    }

    function saveManualOverrides() {
        try {
            manualOverridesFileView.setText(JSON.stringify(root.manualOverrides, null, 2))
        } catch(e) {
            console.warn("Failed to write lyrics manual overrides:", e)
        }
    }

    function saveCurrentOffset() {
        if (!root.lastTrackKey) return
        root.savedOffsets[root.lastTrackKey] = root.manualOffset
        try {
            offsetFileView.setText(JSON.stringify(root.savedOffsets, null, 2))
        } catch(e) {
            console.warn("Failed to write lyrics offset:", e)
        }
    }

    function setOffset(val) {
        const num = parseFloat(val)
        if (!isNaN(num)) {
            root.manualOffset = Math.round(num * 10) / 10
            root.saveCurrentOffset()
        }
    }

    function adjustOffset(delta) {
        root.manualOffset = Math.round((root.manualOffset + delta) * 10) / 10
        root.saveCurrentOffset()
    }

    function resetOffset() {
        root.manualOffset = 0.0
        root.saveCurrentOffset()
    }

    function seekToLine(idx) {
        if (idx >= 0 && idx < root.lyricsLines.length && root.activePlayer && (root.activePlayer.canSeek ?? false)) {
            const targetTime = Math.max(0, root.lyricsLines[idx].time - root.manualOffset)
            root.activePlayer.position = targetTime
        }
    }

    function syncLineToCurrentTime(idx) {
        if (idx >= 0 && idx < root.lyricsLines.length && root.activePlayer) {
            const playerPos = root.activePlayer.position ?? 0
            const lineTime = root.lyricsLines[idx].time
            // pos = playerPos + manualOffset => manualOffset = lineTime - playerPos
            root.manualOffset = Math.round((lineTime - playerPos) * 10) / 10
            root.saveCurrentOffset()
        }
    }

    Timer {
        id: syncTimer
        interval: 150
        repeat: true
        running: root.status === "ok" && root.lyricsLines.length > 0
        onTriggered: {
            const pos = (root.activePlayer?.position ?? 0) + root.manualOffset
            let idx = -1
            for (let i = 0; i < root.lyricsLines.length; i++) {
                if (root.lyricsLines[i].time <= pos) idx = i
                else break
            }
            if (idx !== root.activeIndex) {
                root.activeIndex = idx
                root.slots = root.buildSlots(idx)
            }
        }
    }

    property int currentReqId: 0

    function handleLyricsOutput(rawText, reqId) {
        if (!reqId || reqId !== root.currentReqId) return

        const trimmed = (rawText || "").trim()
        if (!trimmed || trimmed === "not_found") {
            root.status = "not_found"
            return
        }
        if (trimmed === "no_info") {
            root.status = "no_info"
            return
        }

        const parts = trimmed.split("§")
        if (parts.length < 3 || parts[parts.length - 1].trim() !== "ok") {
            root.status = "not_found"
            return
        }

        let lines = []
        for (let i = 0; i < parts.length - 1; i += 2) {
            const t = parseFloat(parts[i])
            const txt = parts[i + 1] || ""
            if (!isNaN(t)) lines.push({ time: t, text: txt })
        }

        if (lines.length === 0) {
            root.status = "not_found"
            return
        }

        root.lyricsLines = lines
        root.activeIndex = -1
        root.slots = root.buildSlots(-1)
        root.status = "ok"
    }

    Timer {
        id: exitCheckTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (root.status === "loading") {
                root.status = "not_found"
            }
        }
    }

    Process {
        id: lyricsProc
        running: false
        property int reqId: 0
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text && this.text.trim()) {
                    console.warn("lyricsProc stderr:", this.text.trim())
                }
            }
        }
        stdout: StdioCollector {
            id: lyricsStdout
            onStreamFinished: {
                root.handleLyricsOutput(this.text, lyricsProc.reqId)
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (lyricsProc.reqId === root.currentReqId && root.status === "loading") {
                exitCheckTimer.start()
            }
        }
    }

    property string lastTrackKey: ""

    function searchManual(title, artist) {
        title = (title || "").trim()
        artist = (artist || "").trim()
        if (!title) return

        const origTitle  = root.activePlayer?.trackTitle  ?? ""
        const origArtist = root.activePlayer?.trackArtist ?? ""
        const trackKey   = origTitle + ":::" + origArtist

        if (trackKey !== ":::") {
            root.manualOverrides[trackKey] = { title: title, artist: artist }
            root.saveManualOverrides()
        }

        root.lastTrackKey = trackKey
        root.currentReqId++
        const thisReqId = root.currentReqId
        lyricsProc.reqId = 0
        lyricsProc.running = false
        root.lyricsLines = []
        root.activeIndex = -1
        root.slots = ["", "", "", "", "", "", ""]
        root.status = "loading"
        root.manualOffset = root.savedOffsets[trackKey] ?? 0.0

        const duration = root.activePlayer?.length ?? 0
        const durSec = (duration && !isNaN(duration) && duration > 0) ? String(Math.floor(duration)) : "0"
        const dbusName = root.activePlayer?.dbusName ?? ""
        const scriptFile = FileUtils.trimFileProtocol(`${Directories.scriptPath}/lyrics/lyrics.py`)

        lyricsProc.reqId = thisReqId
        lyricsProc.command = [
            "python3",
            scriptFile,
            title, artist, durSec, dbusName, "--manual"
        ]
        lyricsProc.running = true
    }

    function restartLyrics(force = false) {
        let title    = root.activePlayer?.trackTitle  ?? ""
        let artist   = root.activePlayer?.trackArtist ?? ""
        const duration = root.activePlayer?.length       ?? 0
        const durSec   = (duration && !isNaN(duration) && duration > 0) ? String(Math.floor(duration)) : "0"
        const trackKey = title + ":::" + artist

        if (!force && trackKey === root.lastTrackKey && (root.status === "ok" || root.status === "not_found" || root.status === "loading")) {
            return
        }

        root.lastTrackKey = trackKey

        let isManual = false
        if (root.manualOverrides && root.manualOverrides[trackKey]) {
            const override = root.manualOverrides[trackKey]
            if (override && override.title) {
                title = override.title
                artist = override.artist || ""
                isManual = true
            }
        }

        root.currentReqId++
        const thisReqId = root.currentReqId
        lyricsProc.reqId = 0
        lyricsProc.running = false
        root.lyricsLines = []
        root.activeIndex = -1
        root.slots = ["", "", "", "", "", "", ""]
        root.status = "loading"
        root.manualOffset = root.savedOffsets[trackKey] ?? 0.0

        if (!title) {
            root.status = "no_info"
            return
        }

        const dbusName = root.activePlayer?.dbusName ?? ""
        const scriptFile = FileUtils.trimFileProtocol(`${Directories.scriptPath}/lyrics/lyrics.py`)
        lyricsProc.reqId = thisReqId
        let cmd = [
            "python3",
            scriptFile,
            title, artist, durSec, dbusName
        ]
        if (isManual) {
            cmd.push("--manual")
        }
        lyricsProc.command = cmd
        lyricsProc.running = true
    }

    Timer {
        id: triggerDebounceTimer
        interval: 150
        repeat: false
        onTriggered: root.restartLyrics(false)
    }

    function queueRestart() {
        triggerDebounceTimer.restart()
    }

    property string trackTitle: root.activePlayer?.trackTitle ?? ""
    property string trackArtist: root.activePlayer?.trackArtist ?? ""

    onTrackTitleChanged: root.queueRestart()
    onTrackArtistChanged: root.queueRestart()

    Connections {
        target: MprisController
        function onTrackChanged() { root.queueRestart() }
        function onActivePlayerChanged() { root.queueRestart() }
    }

    IpcHandler {
        target: "lyrics"
        function restart(): void { root.restartLyrics(true); }
        function searchManual(title: string, artist: string): void { root.searchManual(title, artist); }
        function setOffset(val: real): void { root.setOffset(val); }
        function adjustOffset(delta: real): void { root.adjustOffset(delta); }
        function resetOffset(): void { root.resetOffset(); }
        function seekToLine(idx: int): void { root.seekToLine(idx); }
        function syncLineToCurrentTime(idx: int): void { root.syncLineToCurrentTime(idx); }
        property real manualOffset: root.manualOffset
        property string status: root.status
        property int linesCount: root.lyricsLines.length
        property real playerPos: root.activePlayer?.position ?? 0
        property real playerLen: root.activePlayer?.length ?? 0
        property string currentSlots: JSON.stringify(root.slots)
        property int currentIdx: root.activeIndex
    }

    Component.onCompleted: root.restartLyrics()
}