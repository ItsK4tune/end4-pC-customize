pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "customImage"
    hoverEnabled: true

    property int instanceIndex: -1
    property var instanceConfig: null
    customConfigEntry: instanceConfig

    property string imagePath: (instanceConfig?.path ?? Config.options.background.widgets.customImage.path) ?? ""
    property real widgetSize: (instanceConfig?.size ?? Config.options.background.widgets.customImage.size) ?? 200
    property string division: (instanceConfig?.division ?? Config.options.background.widgets.customImage.division) ?? "1x1"
    property real gap: (instanceConfig?.gap ?? Config.options.background.widgets.customImage.gap) ?? 4
    property var imagesList: (instanceConfig?.images ?? Config.options.background.widgets.customImage.images) ?? []
    property string shapeName: (instanceConfig?.shape ?? Config.options.background.widgets.customImage.shape) ?? "Cookie4Sided"

    implicitWidth: contentItem.implicitWidth
    implicitHeight: contentItem.implicitHeight

    Timer {
        id: savePositionTimer
        interval: 350
        repeat: false
        onTriggered: {
            if (root.instanceIndex >= 0) {
                root.updateInstanceProperty({
                    x: Math.round(root.x),
                    y: Math.round(root.y),
                    z: Math.round(root.z),
                    size: root.widgetSize
                });
            }
        }
    }

    onPositionCommitted: {
        if (root.instanceIndex >= 0) {
            if (root.instanceConfig) {
                root.instanceConfig.x = Math.round(root.x);
                root.instanceConfig.y = Math.round(root.y);
                root.instanceConfig.z = Math.round(root.z);
            }
            savePositionTimer.restart();
        }
    }

    onDeleteRequested: {
        if (root.instanceIndex >= 0) {
            root.removeInstance(root.instanceIndex);
        }
    }

    function getShape(name) {
        switch (name) {
            case "Circle":        return MaterialShape.Shape.Circle
            case "Square":        return MaterialShape.Shape.Square
            case "Slanted":       return MaterialShape.Shape.Slanted
            case "Arch":          return MaterialShape.Shape.Arch
            case "Fan":           return MaterialShape.Shape.Fan
            case "Arrow":         return MaterialShape.Shape.Arrow
            case "SemiCircle":    return MaterialShape.Shape.SemiCircle
            case "Oval":          return MaterialShape.Shape.Oval
            case "Pill":          return MaterialShape.Shape.Pill
            case "Triangle":      return MaterialShape.Shape.Triangle
            case "Diamond":       return MaterialShape.Shape.Diamond
            case "ClamShell":     return MaterialShape.Shape.ClamShell
            case "Pentagon":      return MaterialShape.Shape.Pentagon
            case "Gem":           return MaterialShape.Shape.Gem
            case "Sunny":         return MaterialShape.Shape.Sunny
            case "VerySunny":     return MaterialShape.Shape.VerySunny
            case "Cookie4Sided":  return MaterialShape.Shape.Cookie4Sided
            case "Cookie6Sided":  return MaterialShape.Shape.Cookie6Sided
            case "Cookie7Sided":  return MaterialShape.Shape.Cookie7Sided
            case "Cookie9Sided":  return MaterialShape.Shape.Cookie9Sided
            case "Cookie12Sided": return MaterialShape.Shape.Cookie12Sided
            case "Ghostish":      return MaterialShape.Shape.Ghostish
            case "Clover4Leaf":   return MaterialShape.Shape.Clover4Leaf
            case "Clover8Leaf":   return MaterialShape.Shape.Clover8Leaf
            case "Burst":         return MaterialShape.Shape.Burst
            case "SoftBurst":     return MaterialShape.Shape.SoftBurst
            case "Boom":          return MaterialShape.Shape.Boom
            case "SoftBoom":      return MaterialShape.Shape.SoftBoom
            case "Flower":        return MaterialShape.Shape.Flower
            case "Puffy":         return MaterialShape.Shape.Puffy
            case "PuffyDiamond":  return MaterialShape.Shape.PuffyDiamond
            case "PixelCircle":   return MaterialShape.Shape.PixelCircle
            case "PixelTriangle": return MaterialShape.Shape.PixelTriangle
            case "Bun":           return MaterialShape.Shape.Bun
            case "Heart":         return MaterialShape.Shape.Heart
            default:              return MaterialShape.Shape.Cookie4Sided
        }
    }

    function getSlotLayouts(div, totalW, totalH, g) {
        if (totalW <= 0 || totalH <= 0) return [];
        let validGap = Math.max(0, g);
        switch (div) {
            case "1x2": {
                let w1 = Math.floor((totalW - validGap) / 2);
                let w2 = Math.max(1, totalW - validGap - w1);
                return [
                    { x: 0, y: 0, width: w1, height: totalH },
                    { x: w1 + validGap, y: 0, width: w2, height: totalH }
                ];
            }
            case "2x1": {
                let h1 = Math.floor((totalH - validGap) / 2);
                let h2 = Math.max(1, totalH - validGap - h1);
                return [
                    { x: 0, y: 0, width: totalW, height: h1 },
                    { x: 0, y: h1 + validGap, width: totalW, height: h2 }
                ];
            }
            case "2x2": {
                let w1 = Math.floor((totalW - validGap) / 2);
                let w2 = Math.max(1, totalW - validGap - w1);
                let h1 = Math.floor((totalH - validGap) / 2);
                let h2 = Math.max(1, totalH - validGap - h1);
                return [
                    { x: 0, y: 0, width: w1, height: h1 },
                    { x: w1 + validGap, y: 0, width: w2, height: h1 },
                    { x: 0, y: h1 + validGap, width: w1, height: h2 },
                    { x: w1 + validGap, y: h1 + validGap, width: w2, height: h2 }
                ];
            }
            case "1L-2R": {
                let w1 = Math.floor((totalW - validGap) / 2);
                let w2 = Math.max(1, totalW - validGap - w1);
                let h1 = Math.floor((totalH - validGap) / 2);
                let h2 = Math.max(1, totalH - validGap - h1);
                return [
                    { x: 0, y: 0, width: w1, height: totalH },
                    { x: w1 + validGap, y: 0, width: w2, height: h1 },
                    { x: w1 + validGap, y: h1 + validGap, width: w2, height: h2 }
                ];
            }
            case "1T-2B": {
                let w1 = Math.floor((totalW - validGap) / 2);
                let w2 = Math.max(1, totalW - validGap - w1);
                let h1 = Math.floor((totalH - validGap) / 2);
                let h2 = Math.max(1, totalH - validGap - h1);
                return [
                    { x: 0, y: 0, width: totalW, height: h1 },
                    { x: 0, y: h1 + validGap, width: w1, height: h2 },
                    { x: w1 + validGap, y: h1 + validGap, width: w2, height: h2 }
                ];
            }
            case "1x3": {
                let w1 = Math.floor((totalW - validGap * 2) / 3);
                let w2 = Math.floor((totalW - validGap * 2) / 3);
                let w3 = Math.max(1, totalW - validGap * 2 - w1 - w2);
                return [
                    { x: 0, y: 0, width: w1, height: totalH },
                    { x: w1 + validGap, y: 0, width: w2, height: totalH },
                    { x: (w1 + validGap) + w2 + validGap, y: 0, width: w3, height: totalH }
                ];
            }
            case "1x1":
            default: {
                return [
                    { x: 0, y: 0, width: totalW, height: totalH }
                ];
            }
        }
    }

    function getSlotPath(index) {
        if (root.imagesList && root.imagesList.length > index && root.imagesList[index]) {
            return root.imagesList[index];
        }
        if (index === 0 && root.imagePath !== "") {
            return root.imagePath;
        }
        return "";
    }

    function setSlotImage(index, path) {
        let currentImages = [];
        if (root.imagesList) {
            for (let i = 0; i < root.imagesList.length; i++) {
                currentImages.push(root.imagesList[i]);
            }
        }
        while (currentImages.length <= index) {
            currentImages.push("");
        }
        currentImages[index] = path;

        if (root.instanceIndex >= 0) {
            let updates = { images: currentImages };
            if (index === 0) updates.path = path;
            root.updateInstanceProperty(updates);
        } else {
            if (index === 0) {
                Config.options.background.widgets.customImage.path = path;
            }
            Config.options.background.widgets.customImage.images = currentImages;
        }
    }

    function updateInstanceProperty(props) {
        let list = Config.options.background.widgets.customImage.instances;
        if (!list || root.instanceIndex < 0 || root.instanceIndex >= list.length) return;
        let newList = [];
        for (let i = 0; i < list.length; i++) {
            if (i === root.instanceIndex) {
                let item = Object.assign({}, list[i]);
                for (let k in props) {
                    item[k] = props[k];
                }
                newList.push(item);
            } else {
                newList.push(list[i]);
            }
        }
        Config.options.background.widgets.customImage.instances = newList;
    }

    function removeInstance(idx) {
        let list = Config.options.background.widgets.customImage.instances;
        if (!list) return;
        let newList = [];
        for (let i = 0; i < list.length; i++) {
            if (i !== idx) {
                newList.push(list[i]);
            }
        }
        if (newList.length === 0) {
            Config.options.background.widgets.customImage.instances = [];
            Config.options.background.widgets.customImage.enable = false;
        } else {
            Config.options.background.widgets.customImage.instances = newList;
        }
    }

    function duplicateInstance() {
        let list = Config.options.background.widgets.customImage.instances;
        let current = root.instanceConfig ? Object.assign({}, root.instanceConfig) : {
            x: root.x,
            y: root.y,
            z: root.z,
            size: root.widgetSize,
            shape: root.shapeName,
            division: root.division,
            gap: root.gap,
            images: (root.imagesList || []).slice(),
            path: root.imagePath
        };
        let newItem = Object.assign({}, current);
        newItem.id = "ci_" + Date.now();
        newItem.x = Math.round((current.x || 100) + 30);
        newItem.y = Math.round((current.y || 100) + 30);

        let newList = [];
        if (list && list.length > 0) {
            for (let i = 0; i < list.length; i++) newList.push(list[i]);
        } else {
            newList.push({
                id: "ci_base",
                x: root.x,
                y: root.y,
                z: root.z,
                size: root.widgetSize,
                shape: root.shapeName,
                division: root.division,
                gap: root.gap,
                images: (root.imagesList || []).slice(),
                path: root.imagePath
            });
        }
        newList.push(newItem);
        Config.options.background.widgets.customImage.instances = newList;
    }

    property bool controlBarVisible: false
    property bool showSettingsPopup: false

    Timer {
        id: hideControlBarTimer
        interval: 350
        repeat: false
        onTriggered: {
            if (!root.containsMouse && !controlBarHoverArea.containsMouse && !root.showSettingsPopup) {
                root.controlBarVisible = false;
            }
        }
    }

    onContainsMouseChanged: {
        if (root.containsMouse) {
            hideControlBarTimer.stop();
            root.controlBarVisible = true;
        } else if (!controlBarHoverArea.containsMouse && !root.showSettingsPopup) {
            hideControlBarTimer.restart();
        }
    }

    Item {
        id: contentItem
        implicitWidth: root.widgetSize
        implicitHeight: root.widgetSize

        Behavior on implicitWidth {
            animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
        }
        Behavior on implicitHeight {
            animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
        }

        // On-widget mini controls
        Item {
            id: controlBarWrapper
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.top
                bottomMargin: 2
            }
            height: 36
            width: controlButtonsRow.implicitWidth + 16
            z: 100
            visible: (root.controlBarVisible || controlBarHoverArea.containsMouse || root.showSettingsPopup) && !Config.options.background.widgetsLocked

            MouseArea {
                id: controlBarHoverArea
                anchors.fill: parent
                hoverEnabled: true
                onEntered: {
                    hideControlBarTimer.stop();
                    root.controlBarVisible = true;
                }
                onExited: {
                    if (!root.containsMouse && !root.showSettingsPopup) {
                        hideControlBarTimer.restart();
                    }
                }
            }

            Row {
                id: controlButtonsRow
                anchors.centerIn: parent
                spacing: 6

                // 1. Duplicate
                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    color: Appearance.colors.colLayer0
                    opacity: 0.95

                    MaterialSymbol {
                        anchors.centerIn: parent
                        iconSize: 15
                        text: "content_copy"
                        color: Appearance.colors.colOnLayer0
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.duplicateInstance()
                    }
                }

                // 2. Setting (per instance)
                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    color: root.showSettingsPopup ? Appearance.colors.colPrimary : Appearance.colors.colLayer0
                    opacity: 0.95

                    MaterialSymbol {
                        anchors.centerIn: parent
                        iconSize: 15
                        text: "settings"
                        color: root.showSettingsPopup ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.showSettingsPopup = !root.showSettingsPopup;
                        }
                    }
                }

                // 3. Delete
                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    color: Appearance.colors.colErrorContainer
                    opacity: 0.95

                    MaterialSymbol {
                        anchors.centerIn: parent
                        iconSize: 15
                        text: "delete"
                        color: Appearance.colors.colOnErrorContainer
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.requestDelete()
                    }
                }
            }
        }

        MaterialShape {
            id: shadowShape
            anchors.fill: parent
            color: Appearance.colors.colPrimaryContainer
            shape: getShape(root.shapeName)
            visible: false
        }

        StyledDropShadow {
            target: shadowShape
            z: -1
            visible: Config.options.background.widgets.shadow
        }

        MaterialShape {
            id: imageShape
            anchors.fill: parent
            z: 0
            color: Appearance.colors.colPrimaryContainer
            shape: getShape(root.shapeName)

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: MaterialShape {
                    width: imageShape.width
                    height: imageShape.height
                    shape: getShape(root.shapeName)
                }
            }

            Repeater {
                id: slotsRepeater
                model: root.getSlotLayouts(root.division, imageShape.width, imageShape.height, root.gap)

                delegate: Item {
                    id: slotRoot
                    required property var modelData
                    required property int index

                    x: modelData.x
                    y: modelData.y
                    width: modelData.width
                    height: modelData.height
                    clip: true

                    property bool slotHover: false
                    property string slotPath: root.getSlotPath(index)

                    Rectangle {
                        anchors.fill: parent
                        color: Appearance.colors.colLayer1
                        opacity: slotRoot.slotPath === "" ? 0.35 : 0
                    }

                    SmartImage {
                        anchors.fill: parent
                        source: slotRoot.slotPath !== "" ? slotRoot.slotPath : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceWidth: parent.width
                        sourceHeight: parent.height
                        visible: slotRoot.slotPath !== ""
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        iconSize: Math.max(16, Math.min(parent.width, parent.height) / 3)
                        text: slotRoot.slotHover ? "download" : "image"
                        fill: slotRoot.slotHover ? 1 : 0
                        color: slotRoot.slotHover
                            ? Appearance.colors.colPrimary
                            : Appearance.colors.colOnPrimaryContainer
                        visible: slotRoot.slotPath === ""
                        Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Appearance.colors.colPrimary
                        opacity: slotRoot.slotHover ? 0.25 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    // Hover delete/clear button
                    Item {
                        anchors {
                            top: parent.top
                            right: parent.right
                            margins: 4
                        }
                        width: 22
                        height: 22
                        visible: slotRoot.slotPath !== "" && slotMouseArea.containsMouse

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: Appearance.colors.colLayer0
                            opacity: 0.85
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            iconSize: 14
                            text: "close"
                            color: Appearance.colors.colOnLayer0
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.setSlotImage(slotRoot.index, "")
                            }
                        }
                    }

                    MouseArea {
                        id: slotMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        onEntered: slotRoot.slotHover = true
                        onExited: slotRoot.slotHover = false
                    }

                    DropArea {
                        anchors.fill: parent
                        keys: ["text/uri-list"]
                        onEntered: (drag) => {
                            drag.accept(Qt.CopyAction)
                            slotRoot.slotHover = true
                        }
                        onExited: {
                            slotRoot.slotHover = false
                        }
                        onDropped: (drop) => {
                            if (drop.hasUrls && drop.urls.length > 0) {
                                var cleanPath = decodeURIComponent(drop.urls[0].toString().replace(/^file:\/\//, ""))
                                var ext = cleanPath.split(".").pop().toLowerCase()
                                var accepted = ["png","jpg","jpeg","webp","avif","bmp","gif","tiff","tif"]
                                if (accepted.indexOf(ext) !== -1) {
                                    root.setSlotImage(slotRoot.index, cleanPath)
                                }
                            }
                            slotRoot.slotHover = false
                        }
                    }
                }
            }
        }

        ResizeHandler {
            anchorItem: imageShape
            hoverActive: root.containsMouse
            locked: Config.options.background.widgetsLocked
            currentWidth: root.widgetSize
            resizeMode: "diagonal"
            z: 1
            onResized: (newValue) => {
                root.widgetSize = Math.max(80, newValue)
            }
            onResizeFinished: {
                if (root.instanceIndex >= 0) {
                    if (root.instanceConfig) {
                        root.instanceConfig.size = root.widgetSize;
                    }
                    savePositionTimer.restart();
                } else {
                    Config.options.background.widgets.customImage.size = root.widgetSize;
                }
            }
        }
    }
}
