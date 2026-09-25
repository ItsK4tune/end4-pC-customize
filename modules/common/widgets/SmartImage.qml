pragma ComponentBehavior: Bound

import QtQuick
import QtMultimedia
import qs
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property string source: ""
    property int fillMode: Image.PreserveAspectCrop
    property bool asynchronous: true
    property bool paused: GlobalStates.screenLocked
    property real sourceWidth: parent?.width ?? 0
    property real sourceHeight: parent?.height ?? 0
    property string loopMode: "end to front" // "none" | "boomerang" | "end to front"

    readonly property string cleanSource: {
        if (!source || source === "") return "";
        return source.trim();
    }

    readonly property string fileExtension: {
        if (!cleanSource) return "";
        let s = cleanSource.split("?")[0].split("#")[0];
        let idx = s.lastIndexOf(".");
        return idx !== -1 ? s.substring(idx + 1).toLowerCase() : "";
    }

    readonly property var videoExtensions: ["mp4", "webm", "mkv", "avi", "mov", "ogv", "m4v", "flv"]

    readonly property bool isVideo: {
        return videoExtensions.indexOf(fileExtension) !== -1;
    }

    readonly property bool isAnimated: {
        return !isVideo && fileExtension === "gif";
    }

    readonly property bool isStatic: {
        return !isVideo && !isAnimated && cleanSource !== "";
    }

    readonly property string mediaUrl: {
        if (!cleanSource || cleanSource === "") return "";
        if (cleanSource.startsWith("file://") || cleanSource.startsWith("http://") || cleanSource.startsWith("https://")) {
            return cleanSource;
        }
        if (cleanSource.startsWith("/")) {
            return "file://" + cleanSource;
        }
        return cleanSource;
    }

    // Video playback
    MediaPlayer {
        id: mediaPlayer
        audioOutput: AudioOutput {
            muted: true
            volume: 0.0
        }
        videoOutput: videoOutput
        source: root.isVideo ? root.mediaUrl : ""
        loops: root.loopMode === "end to front" ? MediaPlayer.Infinite : 1

        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.LoadedMedia) {
                if (!root.paused) {
                    mediaPlayer.play();
                }
            } else if (mediaStatus === MediaPlayer.EndOfMedia) {
                if (root.loopMode === "boomerang") {
                    boomerangReverseTimer.running = true;
                } else if (root.loopMode === "none") {
                    mediaPlayer.pause();
                }
            }
        }

        Component.onCompleted: {
            if (root.isVideo && !root.paused) {
                mediaPlayer.play();
            }
        }
    }

    Timer {
        id: boomerangReverseTimer
        interval: 33
        repeat: true
        running: false
        onTriggered: {
            if (root.paused) return;
            if (mediaPlayer.position > 80) {
                mediaPlayer.position = Math.max(0, mediaPlayer.position - 66);
            } else {
                boomerangReverseTimer.running = false;
                mediaPlayer.position = 0;
                mediaPlayer.play();
            }
        }
    }

    Connections {
        target: root
        function onPausedChanged() {
            if (root.isVideo) {
                if (root.paused) {
                    mediaPlayer.pause();
                } else {
                    if (!boomerangReverseTimer.running) {
                        mediaPlayer.play();
                    }
                }
            }
        }
        function onLoopModeChanged() {
            if (root.loopMode !== "boomerang") {
                boomerangReverseTimer.running = false;
            }
            if (root.isVideo && !root.paused) {
                if (mediaPlayer.playbackState !== MediaPlayer.PlayingState) {
                    mediaPlayer.play();
                }
            }
        }
    }

    VideoOutput {
        id: videoOutput
        anchors.fill: parent
        fillMode: {
            if (root.fillMode === Image.PreserveAspectFit) return VideoOutput.PreserveAspectFit;
            if (root.fillMode === Image.Stretch) return VideoOutput.Stretch;
            return VideoOutput.PreserveAspectCrop;
        }
        visible: root.isVideo && root.cleanSource !== ""
    }

    // Animated GIF
    property bool gifReversing: false

    AnimatedImage {
        id: animImage
        anchors.fill: parent
        source: root.isAnimated && root.cleanSource !== "" ? root.cleanSource : ""
        fillMode: root.fillMode
        playing: !root.paused && (root.loopMode !== "boomerang" || !root.gifReversing)
        paused: root.paused || (root.loopMode === "none" && currentFrame >= frameCount - 1 && frameCount > 1)
        cache: false
        visible: root.isAnimated && root.cleanSource !== "" && status === Image.Ready

        onCurrentFrameChanged: {
            if (root.loopMode === "boomerang" && frameCount > 1) {
                if (currentFrame >= frameCount - 1 && !root.gifReversing) {
                    root.gifReversing = true;
                    gifReverseTimer.running = true;
                }
            }
        }
    }

    Timer {
        id: gifReverseTimer
        interval: 60
        repeat: true
        running: false
        onTriggered: {
            if (root.paused) return;
            if (animImage.currentFrame > 0) {
                animImage.currentFrame = animImage.currentFrame - 1;
            } else {
                gifReverseTimer.running = false;
                root.gifReversing = false;
            }
        }
    }

    // Static image
    StyledImage {
        id: staticImage
        anchors.fill: parent
        source: root.isStatic ? root.cleanSource : ""
        fillMode: root.fillMode
        cache: false
        antialiasing: true
        sourceSize.width: root.sourceWidth > 0 ? root.sourceWidth : parent.width
        sourceSize.height: root.sourceHeight > 0 ? root.sourceHeight : parent.height
        visible: root.isStatic
    }
}
