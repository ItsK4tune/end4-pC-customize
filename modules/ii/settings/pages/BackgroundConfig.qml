import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Quickshell.Hyprland
import Quickshell.Io


ContentPage {
    id: page
    forceWidth: true

    function goTo(term) {
        let parts = term.split(":");
        const t = parts[0].toLowerCase().trim();
        const subIndex = parts.length > 1 ? parseInt(parts[1]) : -1;

        function findTarget(rootItem) {
            let trTerm = Translation.tr(parts[0]).toLowerCase().trim();
            for (let i = 0; i < rootItem.children.length; i++) {
                let child = rootItem.children[i];
                if (child.title && (child.title.toLowerCase().includes(t) || child.title.toLowerCase().includes(trTerm))) {
                    return child;
                }
            }

            for (let i = 0; i < rootItem.children.length; i++) {
                let found = findTarget(rootItem.children[i]);
                if (found) return found;
            }
            return null;
        }

        let target = findTarget(mainLayout);
        if (target) {
            let pos = target.mapToItem(mainLayout, 0, 0);
            page.contentY = Math.max(0, pos.y - 0);
            if (target === customImageSection && subIndex >= 0) {
                customImageSection.instanceTab = subIndex;
            }
        }
    }

    function displayPathFor(path) {
        return /\.(mp4|webm|mkv|avi|mov)$/i.test(path)
            ? Config.options.background.thumbnailPath
            : path
    }

    ColumnLayout {
        id: mainLayout 
        Layout.fillWidth: true   
        Layout.fillHeight: true
        spacing: 20
            
        ContentSection {
            icon: "panorama"
            title: Translation.tr("Wallpaper")
            shape: MaterialShape.Shape.Clover4Leaf

            Loader {
                Layout.fillWidth: true
                sourceComponent: WM.compositor === "niri" ? niriHeaderComponent : hyprlandHeaderComponent
            }

            Component {
                id: hyprlandHeaderComponent
                Rectangle {
                    width: parent.width
                    implicitHeight: wrapperCol.implicitHeight + 16
                    topLeftRadius: Appearance.rounding.verylarge
                    topRightRadius: Appearance.rounding.verylarge
                    bottomLeftRadius: Appearance.rounding.normal
                    bottomRightRadius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer1

                    ColumnLayout {
                        id: wrapperCol
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Carousel {
                            Layout.fillWidth: true
                            implicitHeight: 280
                            largeItemWidthRatio: 0.5
                            mediumItemWidthRatio: 0.485
                            itemSpacing: 8
                            model: [
                                page.displayPathFor(Config.options.background.wallpaperPath),
                                page.displayPathFor(
                                    Config.options.background.lockWall !== ""
                                        ? Config.options.background.lockWall
                                        : Config.options.background.wallpaperPath
                                )
                            ]
                            wheelEnabled: false
                            dragEnabled: false
                            clickAction: (index, modelData) => {
                                GlobalStates.wallpaperSelectorTarget = index === 1 ? "lockWall" : "wallpaper"
                                GlobalStates.wallpaperSelectorOpen = true
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 24
                                radius: Appearance.rounding.normal
                                color: "transparent"

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    MaterialSymbol {
                                        text: "desktop_windows"
                                        iconSize: Appearance.font.pixelSize.larger
                                        color: Appearance.colors.colPrimary
                                    }
                                    StyledText {
                                        text: Translation.tr("Desktop")
                                        font.pixelSize: Appearance.font.pixelSize.normal
                                        font.weight: Font.Medium
                                        color: Appearance.colors.colOnLayer1
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 24
                                radius: Appearance.rounding.normal
                                color: "transparent"

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    MaterialSymbol {
                                        text: "lock"
                                        iconSize: Appearance.font.pixelSize.larger
                                        color: Appearance.colors.colPrimary
                                    }
                                    StyledText {
                                        text: Translation.tr("Lockscreen")
                                        font.pixelSize: Appearance.font.pixelSize.normal
                                        font.weight: Font.Medium
                                        color: Appearance.colors.colOnLayer1
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Component {
                id: niriHeaderComponent
                Rectangle {
                    width: parent.width
                    implicitHeight: niriWrapperCol.implicitHeight + 16
                    topLeftRadius: Appearance.rounding.verylarge
                    topRightRadius: Appearance.rounding.verylarge
                    bottomLeftRadius: Appearance.rounding.normal
                    bottomRightRadius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer1

                    ColumnLayout {
                        id: niriWrapperCol
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Carousel {
                            Layout.fillWidth: true
                            implicitHeight: 280
                            largeItemWidthRatio: 1
                            mediumItemWidthRatio: 0
                            itemSpacing: 8
                            model: [page.displayPathFor(Config.options.background.wallpaperPath)]
                            wheelEnabled: false
                            dragEnabled: false
                            clickAction: (index, modelData) => {
                                GlobalStates.wallpaperSelectorTarget = "wallpaper"
                                GlobalStates.wallpaperSelectorOpen = true
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 24
                            radius: Appearance.rounding.normal
                            color: "transparent"

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                MaterialSymbol {
                                    text: "image"
                                    iconSize: Appearance.font.pixelSize.larger
                                    color: Appearance.colors.colPrimary
                                }
                                StyledText {
                                    text: Config.options.background.wallpaperPath.split("/").pop()
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    font.weight: Font.Medium
                                    color: Appearance.colors.colOnLayer1
                                    elide: Text.ElideMiddle
                                }
                            }
                        }
                    }
                }
            }

            GroupedList {
                Layout.topMargin: -2

                ConfigSwitch {
                    id: syncWallpaperSwitch
                    buttonIcon: "sync"
                    text: Translation.tr("Use same wallpaper for both")
                    checked: Config.options.background.lockWall === ""
                    onCheckedChanged: {
                        if (checked) {
                            Config.options.background.lockWall = "";
                        }
                    }
                }

                ConfigSwitch {
                    buttonIcon: "preview"
                    text: Translation.tr("Preview wallpaper")
                    checked: Config.options.background.enableWallpaperPreview
                    onCheckedChanged: {
                        Config.options.background.enableWallpaperPreview = checked;
                    }
                }

                ConfigSwitch {
                    buttonIcon: "blur_on"
                    text: Translation.tr("Blur wall")
                    checked: Config.options.background.showBlur
                    onCheckedChanged: {
                        Config.options.background.showBlur = checked;
                    }
                }

                ConfigSlider {
                    Layout.fillWidth: true
                    text: Translation.tr("Blur Size")
                    value: Config.options.background.blurRadius ?? 32
                    usePercentTooltip: false
                    buttonIcon: "aspect_ratio"
                    from: 1
                    to: 64
                    stopIndicatorValues: [32]
                    onValueChanged: Config.options.background.blurRadius = value
                }

                ConfigSelectionArray {
                    text: Translation.tr("Split blur amount")
                    icon: "split_scene"
                    currentValue: Config.options.background.splitRatio
                    options: [
                        { "displayName": "25%",  "icon": "thumbnail_bar",              "value": "25" },
                        { "displayName": "50%",  "icon": "side_navigation",              "value": "50" },
                        { "displayName": "100%", "icon": "fullscreen",    "value": "100" },
                    ]
                    onSelected: newValue => {
                        Config.options.background.splitRatio = newValue
                    }
                }

                ConfigSelectionArray {
                    text: Translation.tr("Split blur side")
                    icon: "align_horizontal_left"
                    currentValue: Config.options.background.splitSide
                    options: [
                        { "displayName": Translation.tr("Left"),  "icon": "align_horizontal_left",  "value": "left" },
                        { "displayName": Translation.tr("Right"), "icon": "align_horizontal_right", "value": "right" },
                    ]
                    onSelected: newValue => {
                        Config.options.background.splitSide = newValue
                    }
                }

                ConfigSpinBox {
                    icon: "timer"
                    text: Translation.tr("Wallpaper change interval (min)")
                    value: Config.options.wallpaperSelector.changeInterval / 60000
                    from: 0
                    to: 1440
                    stepSize: 5
                    onValueChanged: {
                        Config.options.wallpaperSelector.changeInterval = value * 60000;
                    }
                }

                ConfigComboBox {
                    Layout.fillWidth: true
                    buttonIcon: "texture"
                    text: Translation.tr("Transitions")
                    fieldWidth: 50
                    model: [
                        { displayName: Translation.tr("None"), icon: "block", value: "" },
                        { displayName: Translation.tr("Circle"), icon: "circle", value: "circleSelect" },
                        { displayName: Translation.tr("Circle Pit"), icon: "blur_circular", value: "circlePit" },
                        { displayName: Translation.tr("Magic"), icon: "auto_awesome", value: "magic" },
                        { displayName: Translation.tr("Doom"), icon: "whatshot", value: "Doom" },
                        { displayName: Translation.tr("Peel"), icon: "layers", value: "Peel" },
                        { displayName: Translation.tr("Fade"), icon: "gradient", value: "transition" },
                        { displayName: Translation.tr("Pixelate"), icon: "grain", value: "pixelate" },
                        { displayName: Translation.tr("Stripes"), icon: "texture_minus", value: "stripes" },
                        { displayName: Translation.tr("CRT"), icon: "tv", value: "crt" },
                        { displayName: Translation.tr("Dissolve"), icon: "blur_on", value: "dissolve" },
                        { displayName: Translation.tr("Glitch"), icon: "bug_report", value: "glitch" },
                        { displayName: Translation.tr("Ripple"), icon: "water", value: "ripple" },
                        { displayName: Translation.tr("Shatter"), icon: "broken_image", value: "shatter" },
                        { displayName: Translation.tr("Random"), icon: "shuffle", value: "random" },
                    ]
                    currentValue: Config.options.background.wallpaperAnimation
                    onSelected: newValue => {
                        Config.options.background.wallpaperAnimation = newValue;
                    }
                }
            }

            Connections {
                target: Config.options.background
                function onLockWallChanged() {
                    syncWallpaperSwitch.checked = Qt.binding(() => Config.options.background.lockWall === "")
                }
            }
        
            ContentSubsection {
                title: Translation.tr("Centered wallpaper")
                Layout.fillWidth: true

                GroupedList {
                    ConfigSwitch {
                        Layout.fillWidth: true
                        buttonIcon: "check"
                        text: Translation.tr("Enable")
                        checked: Config.options.background.centeredWallpaper
                        onClicked: {
                            Config.options.background.centeredWallpaper = !Config.options.background.centeredWallpaper;
                        }
                    }
                    ConfigSwitch {
                        Layout.fillWidth: true
                        buttonIcon: "lock"
                        text: Translation.tr("Show only when locked")
                        checked: Config.options.background.centeredWallpaperOnlyWhenLocked
                        onCheckedChanged: {
                            Config.options.background.centeredWallpaperOnlyWhenLocked = checked;
                        }
                        enabled: Config.options.background.centeredWallpaper && WM.compositor !== "niri"
                    }
                }

                GroupedList {
                    Layout.topMargin: 0
                    visible: Config.options.background.centeredWallpaper
                    ConfigSelectionShapeArray {
                        currentValue: Config.options.background.centeredWallpaperShape
                        shapeColor: Appearance.colors.colPrimary
                        backgroundColor: Appearance.colors.colPrimaryContainer
                        options: [
                            "Circle", "Square", "Slanted", "Arch", "Arrow", "SemiCircle", "Oval", "Pill",
                            "Triangle", "Diamond", "ClamShell", "Pentagon", "Gem", "Sunny", "VerySunny",
                            "Cookie4Sided", "Cookie6Sided", "Cookie7Sided", "Cookie9Sided", "Cookie12Sided",
                            "Ghostish", "Clover4Leaf", "Clover8Leaf", "Burst", "SoftBurst", "Flower",
                            "Puffy", "PuffyDiamond", "PixelCircle", "Bun", "Heart"
                        ]
                        onSelected: newValue => {
                            Config.options.background.centeredWallpaperShape = newValue
                        }
                    }
                    ColorSelectionArray {
                        visible: Config.options.background.centeredWallpaper
                        icon: "palette"
                        text: Translation.tr("Background Color")
                        currentValue: Config.options.background.centeredWallpaperColor
                        onSelected: newValue => {
                            Config.options.background.centeredWallpaperColor = newValue
                        }
                    }
                    ConfigSlider {
                        visible: Config.options.background.centeredWallpaper
                        text: Translation.tr("Size")
                        value: Config.options.background.centeredWallpaperSize
                        usePercentTooltip: false
                        buttonIcon: "aspect_ratio"
                        from: 400
                        to: 800
                        stopIndicatorValues: [400]
                        onValueChanged: {
                            Config.options.background.centeredWallpaperSize = value;
                        }
                    }
                }
            }
        }

        ContentSection {
            id: settingsClock
            icon: "clock_loader_40"
            shape: MaterialShape.Shape.Bun
            title: Translation.tr("Clock")

            function stylePresent(styleName) {
                if (!Config.options.background.widgets.clock.showOnlyWhenLocked && Config.options.background.widgets.clock.style === styleName) {
                    return true;
                }
                if (Config.options.background.widgets.clock.styleLocked === styleName) {
                    return true;
                }
                return false;
            }

            readonly property bool digitalPresent: stylePresent("digital")
            readonly property bool cookiePresent: stylePresent("cookie")

            GroupedList {
                ConfigSwitch {
                    Layout.fillWidth: false
                    buttonIcon: "check"
                    text: Translation.tr("Enable")
                    checked: Config.options.background.widgets.clock.enable
                    onCheckedChanged: {
                        Config.options.background.widgets.clock.enable = checked;
                    }
                }

                ConfigSwitch {
                    buttonIcon: "lock_clock"
                    text: Translation.tr("Show only when locked")
                    enabled: WM.compositor !== "niri"
                    checked: Config.options.background.widgets.clock.showOnlyWhenLocked
                    onCheckedChanged: {
                        Config.options.background.widgets.clock.showOnlyWhenLocked = checked;
                    }
                }
                ConfigSelectionArray {
                    text: Translation.tr("Placement strategy")
                    icon: "move"
                    Layout.fillWidth: false
                    currentValue: Config.options.background.widgets.clock.placementStrategy
                    onSelected: newValue => {
                        Config.options.background.widgets.clock.placementStrategy = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Draggable"),
                            icon: "drag_pan",
                            value: "free"
                        },
                        {
                            displayName: Translation.tr("Least busy"),
                            icon: "category",
                            value: "leastBusy"
                        },
                        {
                            displayName: Translation.tr("Most busy"),
                            icon: "shapes",
                            value: "mostBusy"
                        },
                    ]
                }
                ConfigSelectionArray {
                    text: Translation.tr("Clock style")
                    icon: "nest_clock_farsight_analog"
                    currentValue: Config.options.background.widgets.clock.style
                    onSelected: newValue => {
                        Config.options.background.widgets.clock.style = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Digital"),
                            icon: "timer_10",
                            value: "digital"
                        },
                        {
                            displayName: Translation.tr("Cookie"),
                            icon: "cookie",
                            value: "cookie"
                        },
                        {
                            displayName: Translation.tr("Pixel"),
                            icon: "grid_view",
                            value: "pixel"
                        }
                    ]
                }
                ConfigSelectionArray {
                    text: Translation.tr("Clock style (locked)")
                    icon: "shield_watch"
                    currentValue: Config.options.background.widgets.clock.styleLocked
                    onSelected: newValue => {
                        Config.options.background.widgets.clock.styleLocked = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Digital"),
                            icon: "timer_10",
                            value: "digital"
                        },
                        {
                            displayName: Translation.tr("Cookie"),
                            icon: "cookie",
                            value: "cookie"
                        },
                        {
                            displayName: Translation.tr("Pixel"),
                            icon: "grid_view",
                            value: "pixel"
                        }
                    ]
                }
            }

            ContentSubsection {
                visible: settingsClock.digitalPresent
                title: Translation.tr("Digital clock settings")

                ConfigRow {
                    uniform: true

                    GroupedList {
                        ConfigSwitch {
                            buttonIcon: "vertical_distribute"
                            text: Translation.tr("Vertical")
                            checked: Config.options.background.widgets.clock.digital.vertical
                            onCheckedChanged: { Config.options.background.widgets.clock.digital.vertical = checked }
                        }
                        ConfigSwitch {
                            buttonIcon: "date_range"
                            text: Translation.tr("Show date")
                            checked: Config.options.background.widgets.clock.digital.showDate
                            onCheckedChanged: { Config.options.background.widgets.clock.digital.showDate = checked }
                        }
                    }

                    GroupedList {
                        ConfigSwitch {
                            buttonIcon: "animation"
                            text: Translation.tr("Animate time change")
                            checked: Config.options.background.widgets.clock.digital.animateChange
                            onCheckedChanged: { Config.options.background.widgets.clock.digital.animateChange = checked }
                        }
                        ConfigSwitch {
                            buttonIcon: "activity_zone"
                            text: Translation.tr("Use adaptive alignment")
                            checked: Config.options.background.widgets.clock.digital.adaptiveAlignment
                            onCheckedChanged: { Config.options.background.widgets.clock.digital.adaptiveAlignment = checked }
                        }
                    }
                }

                GroupedList {
                    ConfigSwitch {
                        id: autoColorSwitch
                        buttonIcon: "auto_awesome"
                        text: Translation.tr("Automatic colors")
                        checked: Config.options.background.widgets.clock.color === ""
                        onCheckedChanged: {
                            if (checked) {
                                Config.options.background.widgets.clock.color = ""
                            }
                        }
                    }

                    ColorSelectionArray {
                        icon: "palette"
                        text: Translation.tr("Color")
                        currentValue: Config.options.background.widgets.clock.color
                        onSelected: newValue => {
                            Config.options.background.widgets.clock.color = newValue
                            autoColorSwitch.checked = false
                        }
                    }
                }

                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Font family")
                    text: Config.options.background.widgets.clock.digital.font.family
                    wrapMode: TextEdit.Wrap

                    Timer {
                        id: debounceTimer
                        interval: 500
                        repeat: false
                        onTriggered: {
                            Config.options.background.widgets.clock.digital.font.family = parent.text
                        }
                    }

                    onTextChanged: {
                        debounceTimer.restart()
                    }
                }
                GroupedList {
                    Layout.topMargin: 10
                    ConfigSlider {
                        text: Translation.tr("Font weight")
                        value: Config.options.background.widgets.clock.digital.font.weight
                        usePercentTooltip: false
                        buttonIcon: "format_bold"
                        from: 1
                        to: 1000
                        stopIndicatorValues: [350]
                        onValueChanged: {
                            Config.options.background.widgets.clock.digital.font.weight = value;
                        }
                    }

                    ConfigSlider {
                        text: Translation.tr("Font size")
                        value: Config.options.background.widgets.clock.digital.font.size
                        usePercentTooltip: false
                        buttonIcon: "format_size"
                        from: 50
                        to: 700
                        stopIndicatorValues: [90]
                        onValueChanged: {
                            Config.options.background.widgets.clock.digital.font.size = value;
                        }
                    }

                    ConfigSlider {
                        text: Translation.tr("Font width")
                        value: Config.options.background.widgets.clock.digital.font.width
                        usePercentTooltip: false
                        buttonIcon: "fit_width"
                        from: 25
                        to: 125
                        stopIndicatorValues: [100]
                        onValueChanged: {
                            Config.options.background.widgets.clock.digital.font.width = value;
                        }
                    }
                    ConfigSlider {
                        text: Translation.tr("Font roundness")
                        value: Config.options.background.widgets.clock.digital.font.roundness
                        usePercentTooltip: false
                        buttonIcon: "line_curve"
                        from: 0
                        to: 100
                        onValueChanged: {
                            Config.options.background.widgets.clock.digital.font.roundness = value;
                        }
                    }
                }
            }

            ContentSubsection {
                visible: settingsClock.cookiePresent
                title: Translation.tr("Cookie clock settings")
                GroupedList {   
                    ConfigSwitch {  
                        buttonIcon: "wand_stars"
                        text: Translation.tr("Auto styling with Gemini")
                        checked: Config.options.background.widgets.clock.cookie.aiStyling
                        onCheckedChanged: {
                            Config.options.background.widgets.clock.cookie.aiStyling = checked;
                        }
                    }

                    ConfigSwitch {
                        buttonIcon: "airwave"
                        text: Translation.tr("Use old sine wave cookie implementation")
                        checked: Config.options.background.widgets.clock.cookie.useSineCookie
                        onCheckedChanged: {
                            Config.options.background.widgets.clock.cookie.useSineCookie = checked;
                        }
                    }

                    ConfigSpinBox {
                        icon: "add_triangle"
                        text: Translation.tr("Sides")
                        value: Config.options.background.widgets.clock.cookie.sides
                        from: 0
                        to: 40
                        stepSize: 1
                        onValueChanged: {
                            Config.options.background.widgets.clock.cookie.sides = value;
                        }
                    }

                    ConfigSwitch {
                        buttonIcon: "autoplay"
                        text: Translation.tr("Constantly rotate")
                        checked: Config.options.background.widgets.clock.cookie.constantlyRotate
                        onCheckedChanged: {
                            Config.options.background.widgets.clock.cookie.constantlyRotate = checked;
                        }
                    }

                    ConfigRow {

                        ConfigSwitch {
                            enabled: Config.options.background.widgets.clock.cookie.dialNumberStyle === "dots" || Config.options.background.widgets.clock.cookie.dialNumberStyle === "full"
                            buttonIcon: "brightness_7"
                            text: Translation.tr("Hour marks")
                            checked: Config.options.background.widgets.clock.cookie.hourMarks
                            onEnabledChanged: {
                                checked = Config.options.background.widgets.clock.cookie.hourMarks;
                            }
                            onCheckedChanged: {
                                Config.options.background.widgets.clock.cookie.hourMarks = checked;
                            }
                        }

                        ConfigSwitch {
                            enabled: Config.options.background.widgets.clock.cookie.dialNumberStyle !== "numbers"
                            buttonIcon: "timer_10"
                            text: Translation.tr("Digits in the middle")
                            checked: Config.options.background.widgets.clock.cookie.timeIndicators
                            onEnabledChanged: {
                                checked = Config.options.background.widgets.clock.cookie.timeIndicators;
                            }
                            onCheckedChanged: {
                                Config.options.background.widgets.clock.cookie.timeIndicators = checked;
                            }
                        }
                    }
                }
            }

            GroupedList {
                Layout.topMargin: 10
                visible: settingsClock.cookiePresent
                ConfigSelectionArray {
                    text: "Dial Style"
                    icon: "graph_6"
                    currentValue: Config.options.background.widgets.clock.cookie.dialNumberStyle
                    onSelected: newValue => {
                        Config.options.background.widgets.clock.cookie.dialNumberStyle = newValue;
                        if (newValue !== "dots" && newValue !== "full") {
                            Config.options.background.widgets.clock.cookie.hourMarks = false;
                        }
                        if (newValue === "numbers") {
                            Config.options.background.widgets.clock.cookie.timeIndicators = false;
                        }
                    }
                    options: [
                        {
                            displayName: "",
                            icon: "block",
                            value: "none"
                        },
                        {
                            displayName: Translation.tr("Dots"),
                            icon: "graph_6",
                            value: "dots"
                        },
                        {
                            displayName: Translation.tr("Full"),
                            icon: "history_toggle_off",
                            value: "full"
                        },
                        {
                            displayName: Translation.tr("Numbers"),
                            icon: "counter_1",
                            value: "numbers"
                        }
                    ]
                }
                ConfigSelectionArray {
                    icon: "highlighter_size_2"
                    text: Translation.tr("Hour hand")
                    currentValue: Config.options.background.widgets.clock.cookie.hourHandStyle
                    onSelected: newValue => {
                        Config.options.background.widgets.clock.cookie.hourHandStyle = newValue;
                    }
                    options: [
                        {
                            displayName: "",
                            icon: "block",
                            value: "hide"
                        },
                        {
                            displayName: Translation.tr("Classic"),
                            icon: "radio",
                            value: "classic"
                        },
                        {
                            displayName: Translation.tr("Hollow"),
                            icon: "circle",
                            value: "hollow"
                        },
                        {
                            displayName: Translation.tr("Fill"),
                            icon: "eraser_size_5",
                            value: "fill"
                        },
                    ]
                }
                ConfigSelectionArray {
                    text: Translation.tr("Minute hand")
                    icon: "eraser_size_1" 
                    currentValue: Config.options.background.widgets.clock.cookie.minuteHandStyle
                    onSelected: newValue => {
                        Config.options.background.widgets.clock.cookie.minuteHandStyle = newValue;
                    }
                    options: [
                        {
                            displayName: "",
                            icon: "block",
                            value: "hide"
                        },
                        {
                            displayName: Translation.tr("Classic"),
                            icon: "radio",
                            value: "classic"
                        },
                        {
                            displayName: Translation.tr("Thin"),
                            icon: "line_end",
                            value: "thin"
                        },
                        {
                            displayName: Translation.tr("Medium"),
                            icon: "eraser_size_2",
                            value: "medium"
                        },
                        {
                            displayName: Translation.tr("Bold"),
                            icon: "eraser_size_4",
                            value: "bold"
                        },
                    ]
                }
                ConfigSelectionArray {
                    text: Translation.tr("Second hand")
                    icon: "pen_size_1"
                    currentValue: Config.options.background.widgets.clock.cookie.secondHandStyle
                    onSelected: newValue => {
                        Config.options.background.widgets.clock.cookie.secondHandStyle = newValue;
                    }
                    options: [
                        {
                            displayName: "",
                            icon: "block",
                            value: "hide"
                        },
                        {
                            displayName: Translation.tr("Classic"),
                            icon: "radio",
                            value: "classic"
                        },
                        {
                            displayName: Translation.tr("Line"),
                            icon: "line_end",
                            value: "line"
                        },
                        {
                            displayName: Translation.tr("Dot"),
                            icon: "adjust",
                            value: "dot"
                        },
                    ]
                }
                ConfigSelectionArray {
                    text: Translation.tr("Date style")
                    icon: "date_range"
                    currentValue: Config.options.background.widgets.clock.cookie.dateStyle
                    onSelected: newValue => {
                        Config.options.background.widgets.clock.cookie.dateStyle = newValue;
                    }
                    options: [
                        {
                            displayName: "",
                            icon: "block",
                            value: "hide"
                        },
                        {
                            displayName: Translation.tr("Bubble"),
                            icon: "bubble_chart",
                            value: "bubble"
                        },
                        {
                            displayName: Translation.tr("Border"),
                            icon: "rotate_right",
                            value: "border"
                        },
                        {
                            displayName: Translation.tr("Rect"),
                            icon: "rectangle",
                            value: "rect"
                        }
                    ]
                }
            }
            
            ContentSubsection {
                visible: Config.options.background.widgets.clock.style === "pixel"
                title: Translation.tr("Pixel Clock Settings")
                GroupedList {
                    visible: Config.options.background.widgets.clock.style === "pixel"
                    ConfigSelectionArray {
                        text: Translation.tr("Pixel clock orientation")
                        visible: Config.options.background.widgets.clock.style === "pixel"
                        icon: "screen_rotation"
                        currentValue: Config.options.background.widgets.clock.pixel.orientation
                        onSelected: newValue => {
                            Config.options.background.widgets.clock.pixel.orientation = newValue;
                        }
                        options: [
                            {
                                displayName: Translation.tr("Horizontal"),
                                icon: "swap_horiz",
                                value: "horizontal"
                            },
                            {
                                displayName: Translation.tr("Vertical"),
                                icon: "swap_vert",
                                value: "vertical"
                            }
                        ]
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Quote")
                GroupedList {
                    ConfigSwitch {
                        buttonIcon: "check"
                        text: Translation.tr("Enable")
                        checked: Config.options.background.widgets.clock.quote.enable
                        onCheckedChanged: {
                            Config.options.background.widgets.clock.quote.enable = checked;
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "font_download"
                        text: Translation.tr("Follow Clock Font")
                        enabled: Config.options.background.widgets.clock.style !== "pixel"
                        checked: Config.options.background.widgets.clock.quote.followClock
                        onCheckedChanged: {
                            Config.options.background.widgets.clock.quote.followClock = checked;
                        }
                    }
                    ConfigTextArea {
                        id: quoteField
                        Layout.fillWidth: true
                        fieldWidth: 300
                        buttonIcon: "format_quote"
                        text: Translation.tr("Quote")
                        placeholderText: Translation.tr("Quote")
                        value: Config.options.background.widgets.clock.quote.text
                        onValueChanged: {
                            quoteDebounceTimer.restart();
                        }

                        Timer {
                            id: quoteDebounceTimer
                            interval: 600
                            repeat: false
                            onTriggered: {
                                Config.options.background.widgets.clock.quote.text = quoteField.value;
                            }
                        }
                    }
                }
            }
        }

        ContentSection {
            id: customImageSection
            icon: "panorama"
            shape: MaterialShape.Shape.SoftBoom 
            title: Translation.tr("Custom Image")

            property var instances: Config.options.background.widgets.customImage.instances ?? []
            property int instanceTab: 0
            property int selectedInstanceIndex: Math.min(Math.max(0, instanceTab), Math.max(0, (instances?.length ?? 1) - 1))

            readonly property var currentTarget: {
                if (instances && instances.length > 0) {
                    return instances[selectedInstanceIndex] || null;
                }
                return Config.options.background.widgets.customImage;
            }

            function updateCurrentTarget(props) {
                if (instances && instances.length > 0) {
                    let newList = [];
                    for (let i = 0; i < instances.length; i++) {
                        if (i === selectedInstanceIndex) {
                            let item = Object.assign({}, instances[i]);
                            for (let k in props) item[k] = props[k];
                            newList.push(item);
                        } else {
                            newList.push(instances[i]);
                        }
                    }
                    Config.options.background.widgets.customImage.instances = newList;
                } else {
                    for (let k in props) {
                        Config.options.background.widgets.customImage[k] = props[k];
                    }
                }
            }

            function addInstance() {
                let current = Config.options.background.widgets.customImage;
                let newList = [];
                if (instances && instances.length > 0) {
                    for (let i = 0; i < instances.length; i++) newList.push(instances[i]);
                    let lastItem = newList[newList.length - 1];
                    newList.push({
                        id: "ci_" + Date.now(),
                        x: Math.round((lastItem.x || 100) + 40),
                        y: Math.round((lastItem.y || 100) + 40),
                        z: (lastItem.z || 0) + 1,
                        size: lastItem.size ?? 200,
                        shape: lastItem.shape ?? "Circle",
                        division: "1x1",
                        margin: 0,
                        padding: 4,
                        gap: 4,
                        images: [],
                        path: "",
                        bgPath: "",
                        bgOpacity: 1.0,
                        bgDim: 0.0,
                        bgBlur: 0.0,
                        rotation: 0,
                        loopMode: "end to front"
                    });
                } else {
                    newList.push({
                        id: "ci_1",
                        x: current.x ?? 100,
                        y: current.y ?? 100,
                        z: current.z ?? 0,
                        size: current.size ?? 200,
                        shape: current.shape ?? "Cookie4Sided",
                        division: current.division ?? "1x1",
                        margin: current.margin ?? 0,
                        padding: current.padding ?? (current.gap ?? 4),
                        gap: current.padding ?? (current.gap ?? 4),
                        images: (current.images ?? []).slice(),
                        path: current.path ?? "",
                        bgPath: current.bgPath ?? "",
                        bgOpacity: current.bgOpacity ?? 1.0,
                        bgDim: current.bgDim ?? 0.0,
                        bgBlur: current.bgBlur ?? 0.0,
                        rotation: current.rotation ?? 0,
                        loopMode: current.loopMode ?? "end to front"
                    });
                }
                Config.options.background.widgets.customImage.instances = newList;
                Config.options.background.widgets.customImage.enable = true;
                customImageSection.instanceTab = newList.length - 1;
            }

            function deleteCurrentInstance() {
                if (!instances || instances.length === 0) return;
                let newList = [];
                for (let i = 0; i < instances.length; i++) {
                    if (i !== selectedInstanceIndex) newList.push(instances[i]);
                }
                if (newList.length === 0) {
                    Config.options.background.widgets.customImage.instances = [];
                    Config.options.background.widgets.customImage.enable = false;
                } else {
                    Config.options.background.widgets.customImage.instances = newList;
                    customImageSection.instanceTab = Math.max(0, selectedInstanceIndex - 1);
                }
            }

            GroupedList {
                ConfigSwitch {
                    Layout.fillWidth: true
                    buttonIcon: "check"
                    text: Translation.tr("Enable")
                    checked: Config.options.background.widgets.customImage.enable
                    onCheckedChanged: Config.options.background.widgets.customImage.enable = checked
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    spacing: 8

                    Flow {
                        Layout.fillWidth: true
                        spacing: 4
                        visible: (customImageSection.instances?.length ?? 0) > 0

                        Repeater {
                            model: customImageSection.instances ?? []
                            delegate: SelectionGroupButton {
                                required property var modelData
                                required property int index

                                buttonText: `${Translation.tr("Widget")} ${index + 1}`
                                toggled: customImageSection.selectedInstanceIndex === index
                                onClicked: customImageSection.instanceTab = index
                            }
                        }
                    }

                    RippleButtonWithIcon {
                        materialIcon: "add"
                        mainText: Translation.tr("Add Widget")
                        onClicked: customImageSection.addInstance()
                    }

                    RippleButtonWithIcon {
                        visible: (customImageSection.instances?.length ?? 0) > 0
                        materialIcon: "delete"
                        mainText: Translation.tr("Delete")
                        colBackground: Appearance.colors.colErrorContainer
                        onClicked: customImageSection.deleteCurrentInstance()
                    }
                }

                ConfigSelectionShapeArray {
                    currentValue: customImageSection.currentTarget?.shape ?? "Cookie4Sided"
                    shapeColor: Appearance.colors.colPrimary
                    backgroundColor: Appearance.colors.colPrimaryContainer
                    options: [
                        "Circle", "Square", "Slanted", "Arch", "Arrow", "SemiCircle", "Oval", "Pill",
                        "Triangle", "Diamond", "ClamShell", "Pentagon", "Gem", "Sunny", "VerySunny",
                        "Cookie4Sided", "Cookie6Sided", "Cookie7Sided", "Cookie9Sided", "Cookie12Sided",
                        "Ghostish", "Clover4Leaf", "Clover8Leaf", "Burst", "SoftBurst", "Flower",
                        "Puffy", "PuffyDiamond", "PixelCircle", "Bun", "Heart"
                    ]
                    onSelected: newValue => {
                        customImageSection.updateCurrentTarget({ shape: newValue })
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    spacing: 6

                    RowLayout {
                        spacing: 8
                        MaterialSymbol {
                            text: "dashboard"
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colOnSecondaryContainer
                        }
                        StyledText {
                            text: Translation.tr("Division")
                            color: Appearance.colors.colOnSecondaryContainer
                            font.pixelSize: Appearance.font.pixelSize.normal
                        }
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: [
                                { displayName: Translation.tr("1x1"),   icon: "crop_square",   value: "1x1" },
                                { displayName: Translation.tr("1x2"),   icon: "view_column_2", value: "1x2" },
                                { displayName: Translation.tr("2x1"),   icon: "splitscreen",   value: "2x1" },
                                { displayName: Translation.tr("2x2"),   icon: "grid_view",     value: "2x2" },
                                { displayName: Translation.tr("1L+2R"), icon: "dashboard",     value: "1L-2R" },
                                { displayName: Translation.tr("1T+2B"), icon: "view_agenda",    value: "1T-2B" },
                                { displayName: Translation.tr("1x3"),   icon: "view_column",   value: "1x3" },
                            ]
                            delegate: SelectionGroupButton {
                                required property var modelData
                                required property int index

                                buttonIcon: modelData.icon
                                buttonText: modelData.displayName
                                toggled: (customImageSection.currentTarget?.division ?? "1x1") === modelData.value
                                onClicked: {
                                    customImageSection.updateCurrentTarget({ division: modelData.value });
                                }
                            }
                        }
                    }
                }
                ConfigSlider {
                    Layout.fillWidth: true
                    text: Translation.tr("Margin")
                    value: customImageSection.currentTarget?.margin ?? 0
                    usePercentTooltip: false
                    buttonIcon: "border_outer"
                    from: 0
                    to: 32
                    stopIndicatorValues: [0, 8, 16, 24, 32]
                    onValueChanged: customImageSection.updateCurrentTarget({ margin: Math.round(value) })
                }

                ConfigSlider {
                    Layout.fillWidth: true
                    text: Translation.tr("Padding")
                    value: customImageSection.currentTarget?.padding ?? (customImageSection.currentTarget?.gap ?? 4)
                    usePercentTooltip: false
                    buttonIcon: "border_inner"
                    from: 0
                    to: 32
                    stopIndicatorValues: [0, 4, 8, 16, 24, 32]
                    onValueChanged: customImageSection.updateCurrentTarget({ padding: Math.round(value), gap: Math.round(value) })
                }

                ConfigSlider {
                    Layout.fillWidth: true
                    text: Translation.tr("Rotation Angle")
                    value: customImageSection.currentTarget?.rotation ?? 0
                    usePercentTooltip: false
                    buttonIcon: "rotate_right"
                    from: -180
                    to: 180
                    stopIndicatorValues: [-180, -90, 0, 90, 180]
                    onValueChanged: customImageSection.updateCurrentTarget({ rotation: Math.round(value) })
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        spacing: 8
                        MaterialSymbol {
                            text: "repeat"
                            iconSize: 18
                            color: Appearance.colors.colOnSecondaryContainer
                        }
                        StyledText {
                            text: Translation.tr("Loop Mode")
                            color: Appearance.colors.colOnSecondaryContainer
                            font.pixelSize: Appearance.font.pixelSize.normal
                        }
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: [
                                { displayName: Translation.tr("End to Front"), icon: "repeat",     value: "end to front" },
                                { displayName: Translation.tr("Boomerang"),   icon: "sync_alt",   value: "boomerang" },
                                { displayName: Translation.tr("None"),        icon: "play_arrow", value: "none" },
                            ]
                            delegate: SelectionGroupButton {
                                required property var modelData
                                required property int index

                                buttonIcon: modelData.icon
                                buttonText: modelData.displayName
                                toggled: (customImageSection.currentTarget?.loopMode ?? "end to front") === modelData.value
                                onClicked: {
                                    customImageSection.updateCurrentTarget({ loopMode: modelData.value });
                                }
                            }
                        }
                    }
                }
            }

            Process {
                id: bgPickerProc
                command: [
                    "bash", "-c",
                    "START_DIR=\"$HOME/Pictures\"; [ ! -d \"$START_DIR\" ] && START_DIR=\"$HOME\"; " +
                    "TITLE=\"" + Translation.tr("Choose Frame Background") + "\"; " +
                    "if command -v kdialog >/dev/null 2>&1; then " +
                    "kdialog --getopenfilename \"$START_DIR\" \"image/png image/jpeg image/webp image/gif image/avif image/bmp image/svg+xml image/tiff video/mp4 video/webm video/x-matroska video/quicktime video/x-msvideo\" --title \"$TITLE\"; " +
                    "elif command -v zenity >/dev/null 2>&1; then " +
                    "zenity --file-selection --file-filter=\"Media | *.png *.jpg *.jpeg *.webp *.gif *.avif *.bmp *.svg *.tiff *.mp4 *.webm *.mkv *.avi *.mov\" --title=\"$TITLE\"; fi"
                ]
                stdout: StdioCollector {
                    id: bgPickerStdout
                }
                onExited: (code) => {
                    if (code === 0) {
                        let chosenPath = bgPickerStdout.text.trim();
                        if (chosenPath.length > 0) {
                            chosenPath = decodeURIComponent(chosenPath.replace(/^file:\/\//, ""));
                            customImageSection.updateCurrentTarget({ bgPath: chosenPath });
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                visible: (customImageSection.currentTarget?.margin ?? 0) > 0 || ((customImageSection.currentTarget?.division ?? "1x1") !== "1x1" && ((customImageSection.currentTarget?.padding ?? customImageSection.currentTarget?.gap ?? 0) > 0))
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer1
                implicitHeight: bgCardCol.implicitHeight + 24

                ColumnLayout {
                    id: bgCardCol
                    anchors { fill: parent; margins: 12 }
                    spacing: 10

                    RowLayout {
                        spacing: 8
                        MaterialSymbol {
                            text: "wallpaper"
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colOnSecondaryContainer
                        }
                        StyledText {
                            text: Translation.tr("Frame Background")
                            color: Appearance.colors.colOnSecondaryContainer
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.DemiBold
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 40
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer2
                        border.width: 1
                        border.color: bgDropAreaConfig.containsDrag ? Appearance.colors.colPrimary : "transparent"

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!bgPickerProc.running) bgPickerProc.running = true;
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            MaterialSymbol {
                                text: (customImageSection.currentTarget?.bgPath ?? "") !== "" ? "image" : "add_photo_alternate"
                                iconSize: 20
                                color: Appearance.colors.colPrimary
                            }

                            StyledText {
                                Layout.fillWidth: true
                                elide: Text.ElideMiddle
                                text: (customImageSection.currentTarget?.bgPath ?? "") !== ""
                                    ? (customImageSection.currentTarget?.bgPath ?? "").split("/").pop()
                                    : Translation.tr("Drop Frame Background Image")
                                color: Appearance.colors.colOnLayer1
                                font.pixelSize: Appearance.font.pixelSize.normal
                            }

                            RippleButtonWithIcon {
                                z: 2
                                visible: (customImageSection.currentTarget?.bgPath ?? "") !== ""
                                materialIcon: "close"
                                mainText: Translation.tr("Clear")
                                onClicked: customImageSection.updateCurrentTarget({ bgPath: "" })
                            }
                        }

                        DropArea {
                            id: bgDropAreaConfig
                            anchors.fill: parent
                            keys: ["text/uri-list"]
                            onDropped: (drop) => {
                                if (drop.hasUrls && drop.urls.length > 0) {
                                    var cleanPath = decodeURIComponent(drop.urls[0].toString().replace(/^file:\/\//, ""));
                                    var ext = cleanPath.split(".").pop().toLowerCase();
                                    var accepted = ["png","jpg","jpeg","webp","avif","bmp","gif","tiff","tif"];
                                    if (accepted.indexOf(ext) !== -1) {
                                        customImageSection.updateCurrentTarget({ bgPath: cleanPath });
                                    }
                                }
                            }
                        }
                    }

                    ConfigSlider {
                        Layout.fillWidth: true
                        visible: (customImageSection.currentTarget?.bgPath ?? "") !== ""
                        text: Translation.tr("Background Dim")
                        value: Math.round((customImageSection.currentTarget?.bgDim ?? 0) * 100)
                        usePercentTooltip: true
                        buttonIcon: "brightness_medium"
                        from: 0
                        to: 100
                        stopIndicatorValues: [0, 50, 100]
                        onValueChanged: customImageSection.updateCurrentTarget({ bgDim: value / 100 })
                    }

                    ConfigSlider {
                        Layout.fillWidth: true
                        visible: (customImageSection.currentTarget?.bgPath ?? "") !== ""
                        text: Translation.tr("Background Blur")
                        value: Math.round((customImageSection.currentTarget?.bgBlur ?? 0) * 100)
                        usePercentTooltip: true
                        buttonIcon: "blur_on"
                        from: 0
                        to: 100
                        stopIndicatorValues: [0, 50, 100]
                        onValueChanged: customImageSection.updateCurrentTarget({ bgBlur: value / 100 })
                    }
                }
            }
        }

                ContentSection {
            id: settingsVisualizer
            icon: "graphic_eq"
            shape: MaterialShape.Shape.Burst
            title: Translation.tr("Visualizer")

            readonly property var entry: Config.options.background.widgets.visualizer
            readonly property bool bandStyle: ["mirror", "aurora", "dots"].includes(entry.style)

            GroupedList {
                ConfigSwitch {
                    Layout.fillWidth: true
                    buttonIcon: "check"
                    text: Translation.tr("Enable")
                    checked: settingsVisualizer.entry.enable
                    onCheckedChanged: {
                        settingsVisualizer.entry.enable = checked;
                    }
                }
                ConfigSelectionArray {
                    text: Translation.tr("Style")
                    icon: "style"
                    currentValue: settingsVisualizer.entry.style
                    onSelected: newValue => {
                        settingsVisualizer.entry.style = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Classic"),
                            icon: "bar_chart",
                            value: "bars"
                        },
                        {
                            displayName: Translation.tr("Mirror"),
                            icon: "equalizer",
                            value: "mirror"
                        },
                        {
                            displayName: Translation.tr("Aurora"),
                            icon: "waves",
                            value: "aurora"
                        },
                        {
                            displayName: Translation.tr("Ring"),
                            icon: "album",
                            value: "ring"
                        },
                        {
                            displayName: Translation.tr("Dots"),
                            icon: "grid_on",
                            value: "dots"
                        }
                    ]
                }

                ConfigSelectionArray {
                    text: Translation.tr("Colors")
                    icon: "palette"
                    enabled: settingsVisualizer.entry.style !== "bars"
                    currentValue: settingsVisualizer.entry.colorSource
                    onSelected: newValue => {
                        settingsVisualizer.entry.colorSource = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Theme"),
                            icon: "palette",
                            value: "theme"
                        },
                        {
                            displayName: Translation.tr("Album cover"),
                            icon: "album",
                            value: "cover"
                        }
                    ]
                }
        
                ConfigSlider {
                    text: Translation.tr("Sensitivity (%)")
                    buttonIcon: "tune"
                    usePercentTooltip: false
                    enabled: settingsVisualizer.entry.style !== "bars"
                    value: settingsVisualizer.entry.sensitivity * 100
                    from: 50
                    to: 300
                    stopIndicatorValues: [100]
                    onValueChanged: {
                        settingsVisualizer.entry.sensitivity = Math.round(value) / 100;
                    }
                }
                ConfigSlider {
                    text: Translation.tr("Height")
                    buttonIcon: "height"
                    usePercentTooltip: false
                    enabled: settingsVisualizer.entry.style !== "bars" && settingsVisualizer.bandStyle
                    value: settingsVisualizer.entry.height
                    from: 120
                    to: 600
                    stopIndicatorValues: [260]
                    onValueChanged: {
                        settingsVisualizer.entry.height = Math.round(value);
                    }
                }
                ConfigSlider {
                    text: Translation.tr("Size")
                    buttonIcon: "aspect_ratio"
                    usePercentTooltip: false
                    enabled: settingsVisualizer.entry.style === "ring"
                    value: settingsVisualizer.entry.ringSize
                    from: 200
                    to: 900
                    stopIndicatorValues: [380]
                    onValueChanged: {
                        settingsVisualizer.entry.ringSize = Math.round(value);
                    }
                }
            }
        }

        ContentSection {
            id: settingsParticles
            icon: "grain"
            shape: MaterialShape.Shape.Burst
            title: Translation.tr("Ambient Particles")

            readonly property var entry: Config.options.background.widgets.particles

            GroupedList {
                ConfigSwitch {
                    Layout.fillWidth: true
                    buttonIcon: "check"
                    text: Translation.tr("Enable")
                    checked: settingsParticles.entry.enable
                    onCheckedChanged: {
                        settingsParticles.entry.enable = checked;
                    }
                }

                ConfigSelectionArray {
                    text: Translation.tr("Preset")
                    icon: "style"
                    currentValue: settingsParticles.entry.preset
                    onSelected: newValue => {
                        settingsParticles.entry.preset = newValue;
                    }
                    options: [
                        {
                            displayName: "",
                            tooltip: Translation.tr("Sakura"),
                            icon: "local_florist",
                            value: "sakura"
                        },
                        {
                            displayName: "",
                            tooltip: Translation.tr("Snow"),
                            icon: "ac_unit",
                            value: "snow"
                        },
                        {
                            displayName: "",
                            tooltip: Translation.tr("Fireflies"),
                            icon: "wb_incandescent",
                            value: "fireflies"
                        },
                        {
                            displayName: "",
                            tooltip: Translation.tr("Starfield"),
                            icon: "auto_awesome",
                            value: "starfield"
                        },
                        {
                            displayName: "",
                            tooltip: Translation.tr("Bubbles"),
                            icon: "bubble_chart",
                            value: "bubbles"
                        },
                        {
                            displayName: "",
                            tooltip: Translation.tr("Rain"),
                            icon: "rainy",
                            value: "rain"
                        },
                        {
                            displayName: "",
                            tooltip: Translation.tr("Leaves"),
                            icon: "eco",
                            value: "leaves"
                        }
                    ]
                }

                ConfigSwitch {
                    Layout.fillWidth: true
                    buttonIcon: "sync"
                    text: Translation.tr("Auto sync with wallpaper")
                    checked: settingsParticles.entry.autoSyncWallpaper
                    onCheckedChanged: {
                        settingsParticles.entry.autoSyncWallpaper = checked;
                    }
                }

                ConfigSelectionArray {
                    text: Translation.tr("Layer placement")
                    icon: "layers"
                    currentValue: settingsParticles.entry.layerMode
                    onSelected: newValue => {
                        settingsParticles.entry.layerMode = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Below widgets"),
                            icon: "vertical_align_bottom",
                            value: "below"
                        },
                        {
                            displayName: Translation.tr("Above widgets"),
                            icon: "vertical_align_top",
                            value: "above"
                        },
                        {
                            displayName: Translation.tr("Above all"),
                            icon: "fullscreen",
                            value: "window"
                        }
                    ]
                }

                ConfigSelectionArray {
                    text: Translation.tr("Color mode")
                    icon: "palette"
                    currentValue: settingsParticles.entry.colorMode
                    onSelected: newValue => {
                        settingsParticles.entry.colorMode = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Preset colors"),
                            icon: "palette",
                            value: "preset"
                        },
                        {
                            displayName: Translation.tr("Wallpaper theme"),
                            icon: "wallpaper",
                            value: "theme"
                        }
                    ]
                }

                ConfigSwitch {
                    Layout.fillWidth: true
                    buttonIcon: "music_note"
                    text: Translation.tr("Audio reactive")
                    checked: settingsParticles.entry.audioReactive
                    onCheckedChanged: {
                        settingsParticles.entry.audioReactive = checked;
                    }
                }

            }

            GroupedList {
                visible: settingsParticles.entry.audioReactive
                Layout.topMargin: 0

                ConfigSlider {
                    text: Translation.tr("Bass sensitivity (%)")
                    buttonIcon: "graphic_eq"
                    usePercentTooltip: false
                    value: Math.round((settingsParticles.entry.bassGain ?? 1.0) * 100)
                    from: 0
                    to: 300
                    stopIndicatorValues: [100]
                    onValueChanged: {
                        settingsParticles.entry.bassGain = Math.round(value) / 100;
                    }
                }

                ConfigSlider {
                    text: Translation.tr("Mid sensitivity (%)")
                    buttonIcon: "equalizer"
                    usePercentTooltip: false
                    value: Math.round((settingsParticles.entry.midGain ?? 1.0) * 100)
                    from: 0
                    to: 300
                    stopIndicatorValues: [100]
                    onValueChanged: {
                        settingsParticles.entry.midGain = Math.round(value) / 100;
                    }
                }

                ConfigSlider {
                    text: Translation.tr("Treble sensitivity (%)")
                    buttonIcon: "volume_up"
                    usePercentTooltip: false
                    value: Math.round((settingsParticles.entry.trebleGain ?? 1.0) * 100)
                    from: 0
                    to: 300
                    stopIndicatorValues: [100]
                    onValueChanged: {
                        settingsParticles.entry.trebleGain = Math.round(value) / 100;
                    }
                }
            }

            GroupedList {

                ConfigSlider {
                    text: Translation.tr("Particle alpha (%)")
                    buttonIcon: "opacity"
                    usePercentTooltip: false
                    value: Math.round(settingsParticles.entry.particleAlpha * 100)
                    from: 10
                    to: 100
                    stopIndicatorValues: [80]
                    onValueChanged: {
                        settingsParticles.entry.particleAlpha = Math.round(value) / 100;
                    }
                }

                ConfigSlider {
                    text: Translation.tr("Particle blur (%)")
                    buttonIcon: "blur_on"
                    usePercentTooltip: false
                    value: Math.round(settingsParticles.entry.particleBlur * 100)
                    from: 0
                    to: 100
                    stopIndicatorValues: [0]
                    onValueChanged: {
                        settingsParticles.entry.particleBlur = Math.round(value) / 100;
                    }
                }

                ConfigSlider {
                    text: Translation.tr("Background dim (%)")
                    buttonIcon: "contrast"
                    usePercentTooltip: false
                    value: Math.round(settingsParticles.entry.backgroundDimAlpha * 100)
                    from: 0
                    to: 90
                    stopIndicatorValues: [0, 30]
                    onValueChanged: {
                        settingsParticles.entry.backgroundDimAlpha = Math.round(value) / 100;
                    }
                }

                ConfigSlider {
                    text: Translation.tr("Background blur")
                    buttonIcon: "blur_circular"
                    usePercentTooltip: false
                    value: settingsParticles.entry.backgroundBlur
                    from: 0
                    to: 64
                    stopIndicatorValues: [0, 32]
                    onValueChanged: {
                        settingsParticles.entry.backgroundBlur = Math.round(value);
                    }
                }

                ConfigSlider {
                    text: Translation.tr("Speed (%)")
                    buttonIcon: "speed"
                    usePercentTooltip: false
                    value: Math.round(settingsParticles.entry.speed * 100)
                    from: 20
                    to: 250
                    stopIndicatorValues: [100]
                    onValueChanged: {
                        settingsParticles.entry.speed = Math.round(value) / 100;
                    }
                }

                ConfigSlider {
                    text: Translation.tr("Wind angle (°)")
                    buttonIcon: "air"
                    usePercentTooltip: false
                    value: settingsParticles.entry.windAngle
                    from: -45
                    to: 45
                    stopIndicatorValues: [0]
                    onValueChanged: {
                        settingsParticles.entry.windAngle = Math.round(value);
                    }
                }

                ConfigSlider {
                    text: Translation.tr("Density (%)")
                    buttonIcon: "grain"
                    usePercentTooltip: false
                    value: Math.round(settingsParticles.entry.density * 100)
                    from: 40
                    to: 200
                    stopIndicatorValues: [100]
                    onValueChanged: {
                        settingsParticles.entry.density = Math.round(value) / 100;
                    }
                }

                ConfigSlider {
                    text: Translation.tr("Particle size (%)")
                    buttonIcon: "photo_size_select_small"
                    usePercentTooltip: false
                    value: Math.round(settingsParticles.entry.particleSize * 100)
                    from: 50
                    to: 200
                    stopIndicatorValues: [100]
                    onValueChanged: {
                        settingsParticles.entry.particleSize = Math.round(value) / 100;
                    }
                }

                ConfigSelectionArray {
                    text: Translation.tr("Mouse interaction")
                    icon: "mouse"
                    currentValue: settingsParticles.entry.mouseInteraction
                    onSelected: newValue => {
                        settingsParticles.entry.mouseInteraction = newValue;
                    }
                    options: [
                        {
                            displayName: "",
                            tooltip: Translation.tr("Repel"),
                            icon: "call_missed_outgoing",
                            value: "repel"
                        },
                        {
                            displayName: "",
                            tooltip: Translation.tr("Attract"),
                            icon: "call_received",
                            value: "attract"
                        },
                        {
                            displayName: "",
                            tooltip: Translation.tr("Glow"),
                            icon: "flare",
                            value: "glow"
                        },
                        {
                            displayName: "",
                            tooltip: Translation.tr("Swirl"),
                            icon: "rotate_right",
                            value: "swirl"
                        },
                        {
                            displayName: "",
                            tooltip: Translation.tr("None"),
                            icon: "block",
                            value: "none"
                        }
                    ]
                }

                ConfigSlider {
                    text: Translation.tr("Mouse radius (px)")
                    buttonIcon: "radio_button_unchecked"
                    usePercentTooltip: false
                    enabled: settingsParticles.entry.mouseInteraction !== "none"
                    value: settingsParticles.entry.mouseRadius
                    from: 60
                    to: 400
                    stopIndicatorValues: [180]
                    onValueChanged: {
                        settingsParticles.entry.mouseRadius = Math.round(value);
                    }
                }

                ConfigSwitch {
                    Layout.fillWidth: true
                    buttonIcon: "ads_click"
                    text: Translation.tr("Desktop click burst")
                    checked: settingsParticles.entry.clickBurst
                    onCheckedChanged: {
                        settingsParticles.entry.clickBurst = checked;
                    }
                }

                ConfigSelectionArray {
                    text: Translation.tr("FPS limit")
                    icon: "speed"
                    currentValue: settingsParticles.entry.fpsCap ?? "auto"
                    onSelected: newValue => {
                        settingsParticles.entry.fpsCap = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Auto"),
                            icon: "sync",
                            value: "auto"
                        },
                        {
                            displayName: "60 FPS",
                            icon: "filter_6",
                            value: "60"
                        },
                        {
                            displayName: "30 FPS",
                            icon: "filter_3",
                            value: "30"
                        }
                    ]
                }

                ConfigSelectionArray {
                    text: Translation.tr("Pause animation")
                    icon: "pause_circle"
                    currentValue: settingsParticles.entry.pauseMode ?? (settingsParticles.entry.pauseFullscreen ? "fullscreen" : "none")
                    onSelected: newValue => {
                        settingsParticles.entry.pauseMode = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Never"),
                            icon: "play_arrow",
                            value: "none"
                        },
                        {
                            displayName: Translation.tr("Fullscreen"),
                            icon: "fullscreen",
                            value: "fullscreen"
                        },
                        {
                            displayName: Translation.tr("Has windows"),
                            icon: "window",
                            value: "hasWindows"
                        }
                    ]
                }
            }
        }

        ContentSection {
            id: settingsCustomText
            icon: "text_fields"
            shape: MaterialShape.Shape.Cookie4Sided
            title: Translation.tr("Text")

            readonly property var entry: Config.options.background.widgets.customText

            GroupedList {
                ConfigSwitch {
                    Layout.fillWidth: true
                    buttonIcon: "check"
                    text: Translation.tr("Enable")
                    checked: settingsCustomText.entry.enable
                    onCheckedChanged: {
                        settingsCustomText.entry.enable = checked;
                    }
                }
                ConfigSwitch {
                    Layout.fillWidth: true
                    buttonIcon: "shadow"
                    text: Translation.tr("Shadow")
                    checked: settingsCustomText.entry.shadow
                    onCheckedChanged: {
                        settingsCustomText.entry.shadow = checked;
                    }
                }
            }

            NoticeBox {
                Layout.fillWidth: true
                materialIcon: "touch_app"
                text: Translation.tr("Double-click the text on your desktop to edit it, drag its corner to resize it")
            }

            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Text to display")
                text: settingsCustomText.entry.content
                wrapMode: TextEdit.Wrap

                Timer {
                    id: customTextContentDebounce
                    interval: 500
                    repeat: false
                    onTriggered: {
                        settingsCustomText.entry.content = parent.text
                    }
                }

                onTextChanged: {
                    if (activeFocus) customTextContentDebounce.restart()
                }
            }

            ContentSubsection {
                Layout.topMargin: 10
                title: Translation.tr("Font")

                GroupedList {
                    ConfigComboBox {
                        Layout.fillWidth: true
                        buttonIcon: "font_download"
                        fieldWidth: 50
                        text: Translation.tr("Font family")
                        textRole: "displayName"
                        model: Fonts.handwritingFamilies.map(family => ({
                            displayName: family,
                            value: family
                        }))
                        currentValue: settingsCustomText.entry.fontFamily
                        onSelected: newValue => { settingsCustomText.entry.fontFamily = newValue; }
                    }
                    ConfigTextArea {
                        id: settingsCustomFontField
                        buttonIcon: "custom_typography"
                        text: Translation.tr("Custom Font")
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        placeholderText: Translation.tr("Any installed font family")
                        value: Fonts.handwritingFamilies.includes(settingsCustomText.entry.fontFamily) ? "" : settingsCustomText.entry.fontFamily

                        onValueChanged: {
                            customTextFontDebounce.restart();
                        }

                        Timer {
                            id: customTextFontDebounce
                            interval: 500
                            repeat: false
                            onTriggered: {
                                if (settingsCustomFontField.value.trim() !== "")
                                    settingsCustomText.entry.fontFamily = settingsCustomFontField.value.trim()
                            }
                        }
                    }

                    ConfigSlider {
                        text: Translation.tr("Font size")
                        value: settingsCustomText.entry.fontSize
                        usePercentTooltip: false
                        buttonIcon: "format_size"
                        from: 12
                        to: 400
                        stopIndicatorValues: [72]
                        onValueChanged: {
                            settingsCustomText.entry.fontSize = Math.round(value);
                        }
                    }

                    ConfigSelectionArray {
                        text: Translation.tr("Alignment")
                        icon: "format_align_center"
                        currentValue: settingsCustomText.entry.alignment
                        onSelected: newValue => {
                            settingsCustomText.entry.alignment = newValue;
                        }
                        options: [
                            {
                                displayName: Translation.tr("Left"),
                                icon: "format_align_left",
                                value: "left"
                            },
                            {
                                displayName: Translation.tr("Center"),
                                icon: "format_align_center",
                                value: "center"
                            },
                            {
                                displayName: Translation.tr("Right"),
                                icon: "format_align_right",
                                value: "right"
                            }
                        ]
                    }
                }
            }

            ContentSubsection {
                Layout.topMargin: 10
                title: Translation.tr("Colors")
                
                GroupedList {
                    ConfigSwitch {
                        id: customTextAutoColorSwitch
                        buttonIcon: "auto_awesome"
                        text: Translation.tr("Automatic colors")
                        checked: settingsCustomText.entry.color === ""
                        onCheckedChanged: {
                            if (checked) {
                                settingsCustomText.entry.color = ""
                            }
                        }
                    }

                    ColorSelectionArray {
                        icon: "palette"
                        text: Translation.tr("Color")
                        currentValue: settingsCustomText.entry.color
                        onSelected: newValue => {
                            settingsCustomText.entry.color = newValue
                            customTextAutoColorSwitch.checked = false
                        }
                    }
                }
            }
        }

        ContentSection {
            icon: "widgets"
            shape: MaterialShape.Shape.Pill
            title: Translation.tr("Widgets")

            ContentSubsection {
                title: Translation.tr("Show widgets on")
                visible: Hyprland.monitors.values.length > 1
                Layout.bottomMargin: 10

                WidgetsMonitorSelector {
                    configEntry: Config.options.background
                }
            }
            
            GridLayout {
                Layout.fillWidth: true
                columns: 3
                rowSpacing: 8
                columnSpacing: 8
                Repeater {
                    model: [
                        {
                            icon: "weather_mix",
                            name: Translation.tr("Weather"),
                            enabled: Config.options.background.widgets.weather.enable
                        },
                        {
                            icon: "image",
                            name: Translation.tr("Image converter"),
                            enabled: Config.options.background.widgets.images.enable
                        },
                        {
                            icon: "music_note",
                            name: Translation.tr("Media Player"),
                            enabled: Config.options.background.widgets.media.enable
                        },
                        {
                            icon: "memory",
                            name: Translation.tr("Resources"),
                            enabled: Config.options.background.widgets.resources.enable
                        },
                        {
                            icon: "calendar_month",
                            name: Translation.tr("Calendar"),
                            enabled: Config.options.background.widgets.calendar.enable
                        },
                        {
                            icon: "public",
                            name: Translation.tr("World Clock"),
                            enabled: Config.options.background.widgets.worldClock.enable
                        },
                        {
                            icon: "person",
                            name: Translation.tr("User Card"),
                            enabled: Config.options.background.widgets.userCard.enable
                        },
                        {
                            icon: "note_stack_add",
                            name: Translation.tr("Notes"),
                            enabled: Config.options.background.widgets.notes.enable
                        },
                        {
                            icon: "add_task",
                            name: Translation.tr("To-Do"),
                            enabled: Config.options.background.widgets.todo.enable
                        },
                        {
                            icon: "timer",
                            name: Translation.tr("Timers"),
                            enabled: Config.options.background.widgets.timers.enable
                        },
                        {
                            icon: "sticker",
                            name: Translation.tr("Sticker"),
                            enabled: Config.options.background.widgets.sticker.enable
                        },
                        
                    ]
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 105
                        radius: Appearance.rounding.normal
                        color: Appearance.colors.colLayer1
                        border.width: 1
                        border.color: Appearance.colors.colLayer0Border
                        ColumnLayout {
                            anchors {
                                top: parent.top
                                left: parent.left
                                right: parent.right
                                margins: 12
                            }
                            spacing: 0
                            RowLayout {
                                Layout.fillWidth: true
                                MaterialSymbol {
                                    text: modelData.icon
                                    iconSize: Appearance.font.pixelSize.normal + 5
                                    color: Appearance.colors.colPrimary
                                }
                                Item { Layout.fillWidth: true }
                                ConfigSwitch {
                                    Layout.fillWidth: false
                                    checked: modelData.enabled
                                    onCheckedChanged: {
                                        if (modelData.icon === "weather_mix")
                                            Config.options.background.widgets.weather.enable = checked
                                        else if (modelData.icon === "image")
                                            Config.options.background.widgets.images.enable = checked
                                        else if (modelData.icon === "music_note")
                                            Config.options.background.widgets.media.enable = checked
                                        else if (modelData.icon === "memory")
                                            Config.options.background.widgets.resources.enable = checked
                                        else if (modelData.icon === "calendar_month")
                                            Config.options.background.widgets.calendar.enable = checked
                                        else if (modelData.icon === "public")
                                            Config.options.background.widgets.worldClock.enable = checked
                                        else if (modelData.icon === "person")
                                            Config.options.background.widgets.userCard.enable = checked
                                        else if (modelData.icon === "note_stack_add")
                                            Config.options.background.widgets.notes.enable = checked
                                        else if (modelData.icon === "add_task")
                                            Config.options.background.widgets.todo.enable = checked
                                        else if (modelData.icon === "timer")
                                            Config.options.background.widgets.timers.enable = checked
                                        else if (modelData.icon === "sticker")
                                            Config.options.background.widgets.sticker.enable = checked
                                    }
                                }
                            }
                            StyledText {
                                text: modelData.name
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colOnLayer1
                            }
                            StyledText {
                                text: modelData.enabled ? Translation.tr("Enabled") : Translation.tr("Disabled")
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                }
            }
            ContentSubsection {
                title: Translation.tr("Canvas")
                Layout.bottomMargin: 10

                GroupedList {
                    ConfigSwitch {
                        Layout.fillWidth: true
                        buttonIcon: "grid_4x4"
                        text: Translation.tr("Show alignment grid while dragging")
                        checked: Config.options.background.showGrid
                        onCheckedChanged: {
                            Config.options.background.showGrid = checked;
                        }
                    }
                    ConfigSwitch {
                        Layout.fillWidth: true
                        buttonIcon: "align_horizontal_center"
                        text: Translation.tr("Show snap lines when dropping")
                        checked: Config.options.background.showSnapLines
                        onCheckedChanged: {
                            Config.options.background.showSnapLines = checked;
                        }
                    }
                }
            }
        }
    }
}
