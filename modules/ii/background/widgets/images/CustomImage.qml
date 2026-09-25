pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import qs.services
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
    property real margin: (instanceConfig?.margin ?? Config.options.background.widgets.customImage.margin) ?? 0
    property real padding: (instanceConfig?.padding ?? (instanceConfig?.gap ?? Config.options.background.widgets.customImage.padding ?? Config.options.background.widgets.customImage.gap)) ?? 4
    property real gap: padding
    property var imagesList: (instanceConfig?.images ?? Config.options.background.widgets.customImage.images) ?? []
    property string shapeName: (instanceConfig?.shape ?? Config.options.background.widgets.customImage.shape) ?? "Cookie4Sided"
    property string bgPath: (instanceConfig?.bgPath ?? Config.options.background.widgets.customImage.bgPath) ?? ""
    property real bgOpacity: (instanceConfig?.bgOpacity ?? Config.options.background.widgets.customImage.bgOpacity) ?? 1.0
    property real bgDim: (instanceConfig?.bgDim ?? Config.options.background.widgets.customImage.bgDim) ?? 0.0
    property real bgBlur: (instanceConfig?.bgBlur ?? Config.options.background.widgets.customImage.bgBlur) ?? 0.0
    property real widgetRotation: (instanceConfig?.rotation ?? Config.options.background.widgets.customImage.rotation) ?? 0

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

    function getSlotLayouts(div, totalW, totalH, p, m) {
        if (totalW <= 0 || totalH <= 0) return [];
        let validPadding = Math.max(0, p ?? 0);
        let validMargin = Math.max(0, m ?? 0);
        let innerW = Math.max(1, totalW - validMargin * 2);
        let innerH = Math.max(1, totalH - validMargin * 2);
        let mx = validMargin;
        let my = validMargin;

        switch (div) {
            case "1x2": {
                let w1 = Math.floor((innerW - validPadding) / 2);
                let w2 = Math.max(1, innerW - validPadding - w1);
                return [
                    { x: mx, y: my, width: w1, height: innerH },
                    { x: mx + w1 + validPadding, y: my, width: w2, height: innerH }
                ];
            }
            case "2x1": {
                let h1 = Math.floor((innerH - validPadding) / 2);
                let h2 = Math.max(1, innerH - validPadding - h1);
                return [
                    { x: mx, y: my, width: innerW, height: h1 },
                    { x: mx, y: my + h1 + validPadding, width: innerW, height: h2 }
                ];
            }
            case "2x2": {
                let w1 = Math.floor((innerW - validPadding) / 2);
                let w2 = Math.max(1, innerW - validPadding - w1);
                let h1 = Math.floor((innerH - validPadding) / 2);
                let h2 = Math.max(1, innerH - validPadding - h1);
                return [
                    { x: mx, y: my, width: w1, height: h1 },
                    { x: mx + w1 + validPadding, y: my, width: w2, height: h1 },
                    { x: mx, y: my + h1 + validPadding, width: w1, height: h2 },
                    { x: mx + w1 + validPadding, y: my + h1 + validPadding, width: w2, height: h2 }
                ];
            }
            case "1L-2R": {
                let w1 = Math.floor((innerW - validPadding) / 2);
                let w2 = Math.max(1, innerW - validPadding - w1);
                let h1 = Math.floor((innerH - validPadding) / 2);
                let h2 = Math.max(1, innerH - validPadding - h1);
                return [
                    { x: mx, y: my, width: w1, height: innerH },
                    { x: mx + w1 + validPadding, y: my, width: w2, height: h1 },
                    { x: mx + w1 + validPadding, y: my + h1 + validPadding, width: w2, height: h2 }
                ];
            }
            case "1T-2B": {
                let w1 = Math.floor((innerW - validPadding) / 2);
                let w2 = Math.max(1, innerW - validPadding - w1);
                let h1 = Math.floor((innerH - validPadding) / 2);
                let h2 = Math.max(1, innerH - validPadding - h1);
                return [
                    { x: mx, y: my, width: innerW, height: h1 },
                    { x: mx, y: my + h1 + validPadding, width: w1, height: h2 },
                    { x: mx + w1 + validPadding, y: my + h1 + validPadding, width: w2, height: h2 }
                ];
            }
            case "1x3": {
                let w1 = Math.floor((innerW - validPadding * 2) / 3);
                let w2 = Math.floor((innerW - validPadding * 2) / 3);
                let w3 = Math.max(1, innerW - validPadding * 2 - w1 - w2);
                return [
                    { x: mx, y: my, width: w1, height: innerH },
                    { x: mx + w1 + validPadding, y: my, width: w2, height: innerH },
                    { x: mx + (w1 + validPadding) + w2 + validPadding, y: my, width: w3, height: innerH }
                ];
            }
            case "1x1":
            default: {
                return [
                    { x: mx, y: my, width: innerW, height: innerH }
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

    property int pickingSlotIndex: -1
    property bool pickingFrameBg: false
    readonly property string dialogTitle: root.pickingFrameBg ? Translation.tr("Choose Frame Background") : Translation.tr("Choose Image")

    Process {
        id: imagePickerProc
        command: [
            "bash", "-c",
            "START_DIR=\"$HOME/Pictures\"; [ ! -d \"$START_DIR\" ] && START_DIR=\"$HOME\"; " +
            "if command -v kdialog >/dev/null 2>&1; then " +
            "kdialog --getopenfilename \"$START_DIR\" \"image/png image/jpeg image/webp image/gif image/avif image/bmp image/svg+xml image/tiff\" --title \"" + root.dialogTitle + "\"; " +
            "elif command -v zenity >/dev/null 2>&1; then " +
            "zenity --file-selection --file-filter=\"Images | *.png *.jpg *.jpeg *.webp *.gif *.avif *.bmp *.svg *.tiff\" --title=\"" + root.dialogTitle + "\"; fi"
        ]
        stdout: StdioCollector {
            id: pickerStdout
        }
        onExited: (code) => {
            if (code === 0) {
                let chosenPath = pickerStdout.text.trim();
                if (chosenPath.length > 0) {
                    chosenPath = decodeURIComponent(chosenPath.replace(/^file:\/\//, ""));
                    if (root.pickingFrameBg) {
                        root.updateInstanceSetting({ bgPath: chosenPath });
                    } else if (root.pickingSlotIndex >= 0) {
                        root.setSlotImage(root.pickingSlotIndex, chosenPath);
                    }
                }
            }
            root.pickingSlotIndex = -1;
            root.pickingFrameBg = false;
        }
    }

    function pickImageForSlot(idx) {
        if (imagePickerProc.running) return;
        root.pickingFrameBg = false;
        root.pickingSlotIndex = idx;
        imagePickerProc.running = true;
    }

    function pickImageForFrameBg() {
        if (imagePickerProc.running) return;
        root.pickingSlotIndex = -1;
        root.pickingFrameBg = true;
        imagePickerProc.running = true;
    }

    Connections {
        target: root
        function onClicked(mouse) {
            if (mouse.button !== Qt.LeftButton || (mouse.modifiers & Qt.ControlModifier)) return;
            if (root.dragging) return;

            let pt = root.mapToItem(imageShape, mouse.x, mouse.y);
            if (pt.x < 0 || pt.x > imageShape.width || pt.y < 0 || pt.y > imageShape.height) return;

            let slots = root.getSlotLayouts(root.division, imageShape.width, imageShape.height, root.padding, root.margin);
            for (let i = 0; i < slots.length; i++) {
                let s = slots[i];
                if (pt.x >= s.x && pt.x <= s.x + s.width && pt.y >= s.y && pt.y <= s.y + s.height) {
                    root.pickImageForSlot(i);
                    break;
                }
            }
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

    Timer {
        id: saveInstanceSettingsTimer
        interval: 250
        repeat: false
        onTriggered: {
            if (root.instanceIndex >= 0) {
                root.updateInstanceProperty({
                    division: root.division,
                    margin: root.margin,
                    padding: root.padding,
                    gap: root.padding,
                    rotation: root.widgetRotation,
                    bgPath: root.bgPath,
                    bgOpacity: root.bgOpacity,
                    bgDim: root.bgDim,
                    bgBlur: root.bgBlur,
                    showSettings: root.showSettingsPopup
                });
            } else {
                Config.options.background.widgets.customImage.division = root.division;
                Config.options.background.widgets.customImage.margin = root.margin;
                Config.options.background.widgets.customImage.padding = root.padding;
                Config.options.background.widgets.customImage.gap = root.padding;
                Config.options.background.widgets.customImage.rotation = root.widgetRotation;
                Config.options.background.widgets.customImage.bgPath = root.bgPath;
                Config.options.background.widgets.customImage.bgOpacity = root.bgOpacity;
                Config.options.background.widgets.customImage.bgDim = root.bgDim;
                Config.options.background.widgets.customImage.bgBlur = root.bgBlur;
            }
        }
    }

    function updateInstanceSetting(props) {
        if (root.instanceIndex >= 0) {
            if (root.instanceConfig) {
                for (let k in props) {
                    root.instanceConfig[k] = props[k];
                }
            }
        }
        if (props.division !== undefined) root.division = props.division;
        if (props.margin !== undefined) root.margin = props.margin;
        if (props.padding !== undefined) {
            root.padding = props.padding;
            root.gap = props.padding;
        }
        if (props.gap !== undefined) {
            root.gap = props.gap;
            root.padding = props.gap;
        }
        if (props.rotation !== undefined) root.widgetRotation = props.rotation;
        if (props.bgPath !== undefined) root.bgPath = props.bgPath;
        if (props.bgOpacity !== undefined) root.bgOpacity = props.bgOpacity;
        if (props.bgDim !== undefined) root.bgDim = props.bgDim;
        if (props.bgBlur !== undefined) root.bgBlur = props.bgBlur;
        saveInstanceSettingsTimer.restart();
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
            margin: root.margin,
            padding: root.padding,
            gap: root.padding,
            images: (root.imagesList || []).slice(),
            path: root.imagePath,
            bgPath: root.bgPath,
            bgOpacity: root.bgOpacity,
            bgDim: root.bgDim,
            bgBlur: root.bgBlur,
            rotation: root.widgetRotation
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
                margin: root.margin,
                padding: root.padding,
                gap: root.padding,
                images: (root.imagesList || []).slice(),
                path: root.imagePath,
                bgPath: root.bgPath,
                bgOpacity: root.bgOpacity,
                bgDim: root.bgDim,
                bgBlur: root.bgBlur,
                rotation: root.widgetRotation
            });
        }
        newList.push(newItem);
        Config.options.background.widgets.customImage.instances = newList;
    }

    property bool controlBarVisible: false
    property bool showSettingsPopup: instanceConfig?.showSettings ?? false

    onShowSettingsPopupChanged: {
        if (root.instanceConfig) {
            root.instanceConfig.showSettings = root.showSettingsPopup;
        }
    }

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
        rotation: root.widgetRotation

        Behavior on implicitWidth {
            animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
        }
        Behavior on implicitHeight {
            animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
        }

        // On-widget mini controls
        Item {

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

            // Background frame layer (visible when margin > 0 or inner padding > 0 in split view)
            Item {
                id: frameBgLayer
                anchors.fill: parent
                visible: (root.margin > 0) || (root.division !== "1x1" && root.padding > 0)

                SmartImage {
                    id: frameBgImage
                    anchors.fill: parent
                    source: root.bgPath
                    fillMode: Image.PreserveAspectCrop
                    opacity: root.bgOpacity
                    visible: root.bgPath !== ""

                    layer.enabled: root.bgBlur > 0
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: root.bgBlur
                        blurMax: 64
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: Appearance.colors.colLayer0
                    opacity: root.bgDim
                    visible: root.bgDim > 0
                }
            }

            Repeater {
                id: slotsRepeater
                model: root.getSlotLayouts(root.division, imageShape.width, imageShape.height, root.padding, root.margin)

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

    // On-widget mini controls (upright, not rotated)
    Item {
        id: controlBarWrapper
        anchors {
            horizontalCenter: contentItem.horizontalCenter
            bottom: contentItem.top
            bottomMargin: {
                let rad = Math.abs(root.widgetRotation * Math.PI / 180);
                let extraH = ((Math.abs(Math.sin(rad)) + Math.abs(Math.cos(rad)) - 1) * root.widgetSize) / 2;
                return Math.max(2, extraH + 2);
            }
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

    Item {
        id: quickSettingsPopup
        visible: root.showSettingsPopup
        z: 200
        anchors {
            top: contentItem.bottom
            topMargin: {
                let rad = Math.abs(root.widgetRotation * Math.PI / 180);
                let extraH = ((Math.abs(Math.sin(rad)) + Math.abs(Math.cos(rad)) - 1) * root.widgetSize) / 2;
                return Math.max(8, extraH + 8);
            }
            horizontalCenter: contentItem.horizontalCenter
        }
        width: 290
        height: settingsCardCol.implicitHeight + 20

        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.large
            color: Appearance.colors.colLayer0
            border.width: 1
            border.color: Appearance.colors.colLayer0Border

            StyledDropShadow {
                target: parent
                z: -1
            }
        }

        MouseArea {
            anchors.fill: parent
            preventStealing: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: (mouse) => mouse.accepted = true
        }

        ColumnLayout {
            id: settingsCardCol
            anchors {
                fill: parent
                margins: 10
            }
            spacing: 8

            // Header
            RowLayout {
                Layout.fillWidth: true
                MaterialSymbol {
                    text: "settings"
                    iconSize: 18
                    color: Appearance.colors.colPrimary
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.instanceIndex >= 0 ? `${Translation.tr("Widget")} ${root.instanceIndex + 1}` : Translation.tr("Custom Image")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                }
                // Full settings button
                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    color: "transparent"
                    MaterialSymbol {
                        anchors.centerIn: parent
                        iconSize: 15
                        text: "open_in_new"
                        color: Appearance.colors.colSubtext
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.showSettingsPopup = false;
                            let targetPage = root.instanceIndex >= 0
                                ? `Desktop:Custom Image:${root.instanceIndex}`
                                : "Desktop:Custom Image";
                            GlobalStates.settingsPage = targetPage;
                            GlobalStates.settingsOpen = true;
                        }
                    }
                }
                // Close button
                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    color: "transparent"
                    MaterialSymbol {
                        anchors.centerIn: parent
                        iconSize: 15
                        text: "close"
                        color: Appearance.colors.colSubtext
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showSettingsPopup = false
                    }
                }
            }

            // Division quick selector
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: [
                        { icon: "crop_square",   val: "1x1", tip: "1x1" },
                        { icon: "view_column_2", val: "1x2", tip: "1x2" },
                        { icon: "splitscreen",   val: "2x1", tip: "2x1" },
                        { icon: "grid_view",     val: "2x2", tip: "2x2" },
                        { icon: "dashboard",     val: "1L-2R", tip: "1L+2R" },
                        { icon: "view_agenda",   val: "1T-2B", tip: "1T+2B" },
                        { icon: "view_column",   val: "1x3", tip: "1x3" },
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 26
                        radius: Appearance.rounding.small
                        color: root.division === modelData.val ? Appearance.colors.colPrimary : Appearance.colors.colLayer1

                        MaterialSymbol {
                            anchors.centerIn: parent
                            iconSize: 15
                            text: modelData.icon
                            color: root.division === modelData.val ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.updateInstanceSetting({ division: modelData.val })
                        }
                    }
                }
            }

            // Margin slider
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                MaterialSymbol {
                    text: "border_outer"
                    iconSize: 16
                    color: Appearance.colors.colSubtext
                }
                StyledText {
                    text: `${Translation.tr("Margin")}: ${Math.round(root.margin)}px`
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
                StyledSlider {
                    Layout.fillWidth: true
                    configuration: StyledSlider.Configuration.XS
                    from: 0
                    to: 32
                    value: root.margin
                    onMoved: root.updateInstanceSetting({ margin: Math.round(value) })
                }
            }

            // Padding slider (visible when division is not 1x1)
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: root.division !== "1x1"
                MaterialSymbol {
                    text: "border_inner"
                    iconSize: 16
                    color: Appearance.colors.colSubtext
                }
                StyledText {
                    text: `${Translation.tr("Padding")}: ${Math.round(root.padding)}px`
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
                StyledSlider {
                    Layout.fillWidth: true
                    configuration: StyledSlider.Configuration.XS
                    from: 0
                    to: 32
                    value: root.padding
                    onMoved: root.updateInstanceSetting({ padding: Math.round(value), gap: Math.round(value) })
                }
            }

            // Frame Background drop area (when margin > 0 or (padding > 0 and not 1x1))
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: (root.margin > 0) || (root.division !== "1x1" && root.padding > 0)

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 32
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer1
                    border.width: 1
                    border.color: bgDropArea.containsDrag ? Appearance.colors.colPrimary : "transparent"

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pickImageForFrameBg()
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol {
                            text: root.bgPath !== "" ? "image" : "add_photo_alternate"
                            iconSize: 16
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: root.bgPath !== "" ? Translation.tr("Bg Image Set") : Translation.tr("Drop Frame Bg Image")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer0
                        }
                        // Clear bg button
                        Rectangle {
                            z: 2
                            width: 18
                            height: 18
                            radius: 9
                            color: Appearance.colors.colLayer0
                            visible: root.bgPath !== ""
                            MaterialSymbol {
                                anchors.centerIn: parent
                                iconSize: 12
                                text: "close"
                                color: Appearance.colors.colOnLayer0
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.updateInstanceSetting({ bgPath: "" })
                            }
                        }
                    }

                    DropArea {
                        id: bgDropArea
                        anchors.fill: parent
                        keys: ["text/uri-list"]
                        onDropped: (drop) => {
                            if (drop.hasUrls && drop.urls.length > 0) {
                                var cleanPath = decodeURIComponent(drop.urls[0].toString().replace(/^file:\/\//, ""));
                                var ext = cleanPath.split(".").pop().toLowerCase();
                                var accepted = ["png","jpg","jpeg","webp","avif","bmp","gif","tiff","tif"];
                                if (accepted.indexOf(ext) !== -1) {
                                    root.updateInstanceSetting({ bgPath: cleanPath });
                                }
                            }
                        }
                    }
                }
            }

            // Frame Background Dim slider (when bgPath is set)
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: ((root.margin > 0) || (root.division !== "1x1" && root.padding > 0)) && root.bgPath !== ""

                MaterialSymbol {
                    text: "brightness_medium"
                    iconSize: 16
                    color: Appearance.colors.colSubtext
                }
                StyledText {
                    text: `${Translation.tr("Dim")}: ${Math.round(root.bgDim * 100)}%`
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
                StyledSlider {
                    Layout.fillWidth: true
                    configuration: StyledSlider.Configuration.XS
                    from: 0
                    to: 1
                    value: root.bgDim
                    onMoved: root.updateInstanceSetting({ bgDim: value })
                }
            }

            // Frame Background Blur slider (when bgPath is set)
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: ((root.margin > 0) || (root.division !== "1x1" && root.padding > 0)) && root.bgPath !== ""

                MaterialSymbol {
                    text: "blur_on"
                    iconSize: 16
                    color: Appearance.colors.colSubtext
                }
                StyledText {
                    text: `${Translation.tr("Blur")}: ${Math.round(root.bgBlur * 100)}%`
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
                StyledSlider {
                    Layout.fillWidth: true
                    configuration: StyledSlider.Configuration.XS
                    from: 0
                    to: 1
                    value: root.bgBlur
                    onMoved: root.updateInstanceSetting({ bgBlur: value })
                }
            }

            // Rotation slider (-180 to +180 deg)
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                MaterialSymbol {
                    text: "rotate_right"
                    iconSize: 16
                    color: Appearance.colors.colSubtext
                }
                StyledText {
                    text: `${Translation.tr("Angle")}: ${Math.round(root.widgetRotation)}°`
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
                StyledSlider {
                    Layout.fillWidth: true
                    configuration: StyledSlider.Configuration.XS
                    from: -180
                    to: 180
                    value: root.widgetRotation
                    onMoved: root.updateInstanceSetting({ rotation: Math.round(value) })
                }
                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    color: Appearance.colors.colLayer1
                    visible: root.widgetRotation !== 0
                    MaterialSymbol {
                        anchors.centerIn: parent
                        iconSize: 12
                        text: "restart_alt"
                        color: Appearance.colors.colOnLayer0
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.updateInstanceSetting({ rotation: 0 })
                    }
                }
            }

            // Link to full settings
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 28
                radius: Appearance.rounding.small
                color: moreSettingsHover.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    MaterialSymbol {
                        text: "tune"
                        iconSize: 15
                        color: Appearance.colors.colPrimary
                    }
                    StyledText {
                        text: Translation.tr("Open Detailed Settings")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer0
                    }
                    MaterialSymbol {
                        text: "arrow_forward"
                        iconSize: 13
                        color: Appearance.colors.colSubtext
                    }
                }

                MouseArea {
                    id: moreSettingsHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.showSettingsPopup = false;
                        let targetPage = root.instanceIndex >= 0
                            ? `Desktop:Custom Image:${root.instanceIndex}`
                            : "Desktop:Custom Image";
                        GlobalStates.settingsPage = targetPage;
                        GlobalStates.settingsOpen = true;
                    }
                }
            }
        }
    }
}
}
