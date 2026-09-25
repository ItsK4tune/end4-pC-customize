pragma ComponentBehavior: Bound

import QtQuick
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

    readonly property bool isAnimated: {
        const s = source.toLowerCase();
        return s.endsWith(".gif");
    }

    AnimatedImage {
        id: animImage
        anchors.fill: parent
        source: root.isAnimated && root.source !== "" ? root.source : ""
        fillMode: root.fillMode
        playing: true
        paused: root.paused
        cache: false
        visible: root.isAnimated && root.source !== "" && status === Image.Ready
    }

    StyledImage {
        id: staticImage
        anchors.fill: parent
        source: !root.isAnimated && root.source !== "" ? root.source : ""
        fillMode: root.fillMode
        cache: false
        antialiasing: true
        sourceSize.width: root.sourceWidth > 0 ? root.sourceWidth : parent.width
        sourceSize.height: root.sourceHeight > 0 ? root.sourceHeight : parent.height
        visible: !root.isAnimated && root.source !== ""
    }
}
