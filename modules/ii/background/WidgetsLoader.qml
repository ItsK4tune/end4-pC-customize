pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas

import qs.modules.ii.background.widgets
import qs.modules.ii.background.widgets.clock
import qs.modules.ii.background.widgets.weather
import qs.modules.ii.background.widgets.media
import qs.modules.ii.background.widgets.images
import qs.modules.ii.background.widgets.resources
import qs.modules.ii.background.widgets.visualizer
import qs.modules.ii.background.widgets.calendar
import qs.modules.ii.background.widgets.worldclock
import qs.modules.ii.background.widgets.usercard
import qs.modules.ii.background.widgets.notes
import qs.modules.ii.background.widgets.todo
import qs.modules.ii.background.widgets.timers
import qs.modules.ii.background.widgets.customtext
import qs.modules.ii.background.widgets.particles

Item {
    id: root

    required property var screen
    required property var wallpaperItem
    required property bool wallpaperSafetyTriggered

    readonly property bool onThisScreen: Config.options.background.screenList.length === 0
        || Config.options.background.screenList.includes(root.screen.name)

    Repeater {
        model: [
            { key: "particles" },
            { key: "visualizer" },
            { key: "customImage" },
            { key: "sticker" },
            { key: "calendar" },
            { key: "weather" },
            { key: "clock", alwaysOnLock: true },
            { key: "notes" },
            { key: "media" },
            { key: "images" },
            { key: "resources" },
            { key: "worldClock" },
            { key: "userCard" },
            { key: "todo" },
            { key: "timers" },
            { key: "customText" },
        ]

        delegate: FadeLoader {
            id: loaderDelegate
            required property var modelData

            property bool enableLoading: true

            shown: Config.options.background.widgets[loaderDelegate.modelData.key].enable
                && loaderDelegate.enableLoading
                && (loaderDelegate.modelData.alwaysOnLock
                    ? (GlobalStates.screenLocked || root.onThisScreen)
                    : root.onThisScreen)

            sourceComponent: {
                switch (loaderDelegate.modelData.key) {
                    case "particles":   return particlesComp
                    case "visualizer":  return visualizerComp
                    case "customImage": return customImageComp
                    case "sticker":     return stickerComp
                    case "calendar":    return calendarComp
                    case "weather":     return weatherComp
                    case "clock":       return clockComp
                    case "notes":       return notesComp
                    case "media":       return mediaComp
                    case "images":      return imagesComp
                    case "resources":   return resourcesComp
                    case "worldClock":  return worldClockComp
                    case "userCard":    return userCardComp
                    case "todo":        return todoComp
                    case "timers":      return timersComp
                    case "customText":  return customTextComp
                }
                return null
            }

            onLoaded: {
                if (loaderDelegate.modelData.key === "media" && loaderDelegate.item && loaderDelegate.item.requestReset) {
                    loaderDelegate.item.requestReset.connect(() => {
                        loaderDelegate.enableLoading = false
                        mediaResetTimer.restart()
                    })
                }
            }

            Timer {
                id: mediaResetTimer
                interval: 500
                onTriggered: loaderDelegate.enableLoading = true
            }
        }
    }

    Loader {
        anchors.fill: parent
        z: -1000
        active: (Config.options.background.widgets.particles?.enable ?? false)
            && ((Config.options.background.widgets.particles?.backgroundBlur ?? 0) > 0
                || (Config.options.background.widgets.particles?.backgroundDimAlpha ?? 0) > 0)
            && root.wallpaperItem !== null
        sourceComponent: Item {
            anchors.fill: parent

            FastBlur {
                anchors.fill: parent
                source: root.wallpaperItem
                radius: Config.options.background.widgets.particles?.backgroundBlur ?? 0
                visible: radius > 0
            }

            Rectangle {
                anchors.fill: parent
                color: Config.options.background.widgets.particles?.backgroundDimColor ?? "#000000"
                opacity: Config.options.background.widgets.particles?.backgroundDimAlpha ?? 0.0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    Component {
        id: particlesComp
        ParticlesWidget {
            screen: root.screen
            screenWidth: root.screen.width
            screenHeight: root.screen.height
            scaledScreenWidth: root.screen.width
            scaledScreenHeight: root.screen.height
            wallpaperScale: 1
            wallpaperItem: root.wallpaperItem
        }
    }

    Component {
        id: visualizerComp
        VisualizerWidget {
            showSelectionBorder: false
            screenWidth: root.screen.width
            screenHeight: root.screen.height
            scaledScreenWidth: root.screen.width
            scaledScreenHeight: root.screen.height
            wallpaperScale: 1
            pinnedBottom: true
        }
    }
    Component {
        id: customImageComp
        Item {
            id: customImagesWrapper
            width: root.screen.width
            height: root.screen.height
            z: Config.options.background.widgets.customImage.z ?? 0
            visible: Config.options.background.widgets.customImage.enable

            readonly property var currentInstances: Config.options.background.widgets.customImage.instances
            readonly property int activeCount: Config.options.background.widgets.customImage.enable
                ? (currentInstances?.length ?? 0)
                : 0

            Connections {
                target: Config.options.background.widgets.customImage
                function onEnableChanged() {
                    let enable = Config.options.background.widgets.customImage.enable;
                    let insts = Config.options.background.widgets.customImage.instances;
                    if (enable && (!insts || insts.length === 0)) {
                        let current = Config.options.background.widgets.customImage;
                        Config.options.background.widgets.customImage.instances = [{
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
                        }];
                    }
                }
                function onInstancesChanged() {
                    let insts = Config.options.background.widgets.customImage.instances;
                    if (!insts || insts.length === 0) {
                        if (Config.options.background.widgets.customImage.enable) {
                            Config.options.background.widgets.customImage.enable = false;
                        }
                    }
                }
            }

            Component.onCompleted: {
                let enable = Config.options.background.widgets.customImage.enable;
                let insts = Config.options.background.widgets.customImage.instances;
                if (enable && (!insts || insts.length === 0)) {
                    let current = Config.options.background.widgets.customImage;
                    Config.options.background.widgets.customImage.instances = [{
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
                    }];
                }
            }

            Repeater {
                model: customImagesWrapper.activeCount
                delegate: CustomImage {
                    required property int index

                    instanceIndex: index
                    instanceConfig: (customImagesWrapper.currentInstances && index < customImagesWrapper.currentInstances.length)
                        ? customImagesWrapper.currentInstances[index]
                        : null

                    screenWidth: root.screen.width
                    screenHeight: root.screen.height
                    scaledScreenWidth: root.screen.width
                    scaledScreenHeight: root.screen.height
                    wallpaperScale: 1
                    wallpaperItem: root.wallpaperItem
                }
            }
        }
    }
    Component {
        id: stickerComp
        StickerWidget {
            screenWidth: root.screen.width
            screenHeight: root.screen.height
            scaledScreenWidth: root.screen.width
            scaledScreenHeight: root.screen.height
            wallpaperScale: 1
            wallpaperItem: root.wallpaperItem
        }
    }
    Component {
        id: calendarComp
        CalendarWidget {
            screenWidth: root.screen.width
            screenHeight: root.screen.height
            scaledScreenWidth: root.screen.width
            scaledScreenHeight: root.screen.height
            wallpaperScale: 1
            wallpaperItem: root.wallpaperItem
        }
    }
    Component {
        id: weatherComp
        WeatherWidget {
            screenWidth: root.screen.width
            screenHeight: root.screen.height
            scaledScreenWidth: root.screen.width
            scaledScreenHeight: root.screen.height
            wallpaperScale: 1
            wallpaperItem: root.wallpaperItem
        }
    }
    Component {
        id: clockComp
        ClockWidget {
            screenWidth: root.screen.width
            screenHeight: root.screen.height
            scaledScreenWidth: root.screen.width
            scaledScreenHeight: root.screen.height
            wallpaperScale: 1
            wallpaperSafetyTriggered: root.wallpaperSafetyTriggered
            wallpaperItem: root.wallpaperItem
        }
    }
    Component {
        id: notesComp
        NotesWidget {
            screenWidth: root.screen.width
            screenHeight: root.screen.height
            scaledScreenWidth: root.screen.width
            scaledScreenHeight: root.screen.height
            wallpaperScale: 1
            wallpaperItem: root.wallpaperItem
        }
    }
    Component {
        id: mediaComp
        MediaWidget {
            screenWidth: root.screen.width
            screenHeight: root.screen.height
            scaledScreenWidth: root.screen.width
            scaledScreenHeight: root.screen.height
            wallpaperScale: 1
            wallpaperItem: root.wallpaperItem
        }
    }
    Component {
        id: imagesComp
        ImageConverterWidget {
            screenWidth: root.screen.width
            screenHeight: root.screen.height
            scaledScreenWidth: root.screen.width
            scaledScreenHeight: root.screen.height
            wallpaperScale: 1
            wallpaperItem: root.wallpaperItem
        }
    }
    Component {
        id: resourcesComp
        ResourcesWidget {
            screenWidth: root.screen.width
            screenHeight: root.screen.height
            scaledScreenWidth: root.screen.width
            scaledScreenHeight: root.screen.height
            wallpaperScale: 1
            wallpaperItem: root.wallpaperItem
        }
    }
    Component {
        id: worldClockComp
        WorldClockWidget {
            screenWidth: root.screen.width
            screenHeight: root.screen.height
            scaledScreenWidth: root.screen.width
            scaledScreenHeight: root.screen.height
            wallpaperScale: 1
            wallpaperItem: root.wallpaperItem
        }
    }
    Component {
        id: userCardComp
        UserCardWidget {
            screenWidth: root.screen.width
            screenHeight: root.screen.height
            scaledScreenWidth: root.screen.width
            scaledScreenHeight: root.screen.height
            wallpaperScale: 1
            wallpaperItem: root.wallpaperItem
        }
    }
    Component {
        id: todoComp
        TodoWidget {
            screenWidth: root.screen.width
            screenHeight: root.screen.height
            scaledScreenWidth: root.screen.width
            scaledScreenHeight: root.screen.height
            wallpaperScale: 1
            wallpaperItem: root.wallpaperItem
        }
    }
    Component {
        id: timersComp
        TimerWidget {
            screenWidth: root.screen.width
            screenHeight: root.screen.height
            scaledScreenWidth: root.screen.width
            scaledScreenHeight: root.screen.height
            wallpaperScale: 1
            wallpaperItem: root.wallpaperItem
        }
    }
    Component {
        id: customTextComp
        CustomTextWidget {
            screenWidth: root.screen.width
            screenHeight: root.screen.height
            scaledScreenWidth: root.screen.width
            scaledScreenHeight: root.screen.height
            wallpaperScale: 1
            wallpaperItem: root.wallpaperItem
        }
    }
}