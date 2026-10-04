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
    configEntryName: "gitRadar"
    hoverEnabled: true

    readonly property real singleWidth: 132
    readonly property real cardSpacing: 12
    readonly property real cardHeight: 120
    readonly property real doubleHeight: root.cardHeight * 2 + root.cardSpacing // 252

    readonly property real snapWidth1: root.singleWidth // 132
    readonly property real snapWidth2: root.singleWidth * 2 + root.cardSpacing // 276
    readonly property real snapWidth3: root.singleWidth * 3 + root.cardSpacing * 2 // 420
    readonly property real snapWidth4: root.singleWidth * 4 + root.cardSpacing * 3 // 564

    property string sizeMode: (root.configEntry && root.configEntry.sizeMode) ? root.configEntry.sizeMode : "2x2"

    property real widgetWidth: {
        switch (root.sizeMode) {
            case "1x1": return root.snapWidth1
            case "1x2": return root.snapWidth2
            case "2x1": return root.snapWidth2
            case "2x2": return root.snapWidth2
            case "2x3": return root.snapWidth3
            case "4x2": return root.snapWidth4
            default:    return root.snapWidth3
        }
    }
    property real widgetHeight: root.isCompact ? root.cardHeight : root.doubleHeight

    readonly property bool isCompact: root.sizeMode === "1x2" || root.sizeMode === "2x1"
    readonly property bool isWide: root.sizeMode === "4x2" || root.sizeMode === "2x3"

    implicitWidth: widgetWidth
    implicitHeight: widgetHeight

    Behavior on widgetWidth {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }
    Behavior on widgetHeight {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    function modeForDrag(dx, dy, startWidth) {
        if (dy < -40) return "1x2";
        const w = startWidth + dx;
        if (w > (snapWidth3 + snapWidth4) / 2) return "4x2";
        if (w > (snapWidth2 + snapWidth3) / 2) return "2x3";
        return "2x2";
    }

    readonly property color widgetBorderColor: Appearance.m3colors.darkmode 
        ? Qt.rgba(1, 1, 1, 0.22) 
        : Qt.rgba(0, 0, 0, 0.12)

    property var radarData: ({
        "streak": 0,
        "total_commits": 0,
        "repo_count": 0,
        "heatmap": [],
        "repos": []
    })

    property bool isRefreshing: radarProcess.running
    property string hoveredTooltipText: ""
    property real hoveredTooltipX: 0
    property real hoveredTooltipY: 0

    function refresh() {
        if (!radarProcess.running) {
            radarProcess.running = true;
        }
    }

    Timer {
        id: autoRefreshTimer
        interval: 60000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Process {
        id: radarProcess
        command: ["python3", `${Directories.scriptPath}/git/git-radar.py`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text.trim());
                    if (parsed && typeof parsed === "object") {
                        root.radarData = parsed;
                    }
                } catch (e) {
                    // JSON parsing incomplete
                }
            }
        }
        Component.onCompleted: root.refresh()
    }

    Item {
        id: cardWrapper
        anchors.fill: parent

        StyledRectangularShadow { 
            target: contentRect 
            z: -2
            visible: Config.options.background.widgets.shadow
        }

        Rectangle {
            id: contentRect
            anchors.fill: parent
            color: Appearance.colors.colPrimaryContainer
            radius: Appearance.rounding.verylarge
            border.width: 1
            border.color: root.widgetBorderColor
            clip: true

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

            // Compact 1x2 / 2x1 Mode Layout (276 x 120)
            ColumnLayout {
                visible: root.isCompact
                anchors { fill: parent; margins: 12 }
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        spacing: 4
                        Layout.alignment: Qt.AlignVCenter
                        StyledText {
                            text: `${root.radarData.total_commits || 0}`
                            font.pixelSize: 22
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        StyledText {
                            text: Translation.tr("commits")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.4)
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: 2
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Streak Badge
                    Rectangle {
                        implicitWidth: streakCompactRow.implicitWidth + 10
                        implicitHeight: 22
                        radius: 11
                        color: Qt.rgba(1, 0.45, 0.1, 0.18)
                        border.width: 1
                        border.color: Qt.rgba(1, 0.5, 0.1, 0.35)

                        RowLayout {
                            id: streakCompactRow
                            anchors.centerIn: parent
                            spacing: 3
                            MaterialSymbol {
                                text: "local_fire_department"
                                iconSize: 13
                                color: "#ff7043"
                            }
                            StyledText {
                                text: `${root.radarData.streak || 0}d`
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.Bold
                                color: "#ff7043"
                            }
                        }
                    }

                    // Refresh Button
                    Rectangle {
                        width: 24; height: 24; radius: 12
                        color: refresh1x2Mouse.containsMouse ? ColorUtils.transparentize(Appearance.colors.colLayer0, 0.7) : "transparent"
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "refresh"
                            iconSize: 15
                            color: Appearance.colors.colOnPrimaryContainer
                            rotation: 0
                            RotationAnimation on rotation {
                                running: root.isRefreshing
                                loops: Animation.Infinite
                                from: 0; to: 360; duration: 800
                            }
                        }
                        MouseArea {
                            id: refresh1x2Mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.refresh()
                        }
                    }
                }

                // Active Repo in 1x2 mode
                Rectangle {
                    id: topRepoBox
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Appearance.rounding.small
                    color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                    border.width: 1
                    border.color: root.widgetBorderColor

                    readonly property var topRepo: (root.radarData.repos && root.radarData.repos.length > 0) ? root.radarData.repos[0] : null

                    RowLayout {
                        anchors { fill: parent; margins: 6; leftMargin: 8; rightMargin: 8 }
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            RowLayout {
                                spacing: 6
                                StyledText {
                                    text: topRepoBox.topRepo ? (topRepoBox.topRepo.name || "repo") : Translation.tr("No git repos detected")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnPrimaryContainer
                                }
                                Rectangle {
                                    visible: topRepoBox.topRepo !== null
                                    implicitWidth: branchCompactText.implicitWidth + 6
                                    implicitHeight: 16
                                    radius: 8
                                    color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.75)
                                    StyledText {
                                        id: branchCompactText
                                        anchors.centerIn: parent
                                        text: topRepoBox.topRepo ? (topRepoBox.topRepo.branch || "main") : ""
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colPrimary
                                    }
                                }
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: topRepoBox.topRepo ? (topRepoBox.topRepo.last_commit || "") : Translation.tr("Scanning git repositories...")
                                elide: Text.ElideRight
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.35)
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (topRepoBox.topRepo && topRepoBox.topRepo.path) {
                                Quickshell.execDetached([
                                    "bash", "-c", 
                                    `cd "${topRepoBox.topRepo.path}" && (foot || kitty || alacritty || xterm || xdg-open "${topRepoBox.topRepo.path}")`
                                ]);
                            }
                        }
                    }
                }
            }

            // Standard 2x2, 2x3 and 4x2 Modes Layout (Abstract & Zero Overflow)
            ColumnLayout {
                visible: !root.isCompact
                anchors { fill: parent; margins: 14 }
                spacing: 8

                // Abstract Header Row (Metrics only - no icon, no title)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        spacing: 6
                        Layout.alignment: Qt.AlignVCenter

                        StyledText {
                            text: `${root.radarData.total_commits || 0}`
                            font.pixelSize: 26
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnPrimaryContainer
                        }

                        ColumnLayout {
                            spacing: -2
                            Layout.alignment: Qt.AlignVCenter

                            StyledText {
                                text: Translation.tr("commits")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.DemiBold
                                color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.3)
                            }

                            StyledText {
                                text: `${root.radarData.repo_count || 0} ${root.radarData.repo_count === 1 ? Translation.tr("repo") : Translation.tr("repos")}`
                                font.pixelSize: 10
                                color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.5)
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Streak Pill
                    Rectangle {
                        implicitWidth: streakRow.implicitWidth + 10
                        implicitHeight: 22
                        radius: 11
                        color: Qt.rgba(1, 0.45, 0.1, 0.18)
                        border.width: 1
                        border.color: Qt.rgba(1, 0.5, 0.1, 0.35)

                        RowLayout {
                            id: streakRow
                            anchors.centerIn: parent
                            spacing: 3
                            MaterialSymbol {
                                text: "local_fire_department"
                                iconSize: 13
                                color: "#ff7043"
                            }
                            StyledText {
                                text: `${root.radarData.streak || 0}d streak`
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.Bold
                                color: "#ff7043"
                            }
                        }
                    }

                    // Refresh Button
                    Rectangle {
                        width: 26; height: 26; radius: 13
                        color: refreshMouse.containsMouse ? ColorUtils.transparentize(Appearance.colors.colLayer0, 0.7) : "transparent"
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "refresh"
                            iconSize: 16
                            color: Appearance.colors.colOnPrimaryContainer
                            rotation: 0
                            RotationAnimation on rotation {
                                running: root.isRefreshing
                                loops: Animation.Infinite
                                from: 0; to: 360; duration: 800
                            }
                        }
                        MouseArea {
                            id: refreshMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.refresh()
                        }
                    }
                }

                // Heatmap Matrix Container (Clean, Abstract Git Contribution Matrix)
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 74
                    radius: Appearance.rounding.small
                    color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                    border.width: 1
                    border.color: root.widgetBorderColor

                    Item {
                        anchors.fill: parent
                        anchors.margins: 6

                        Row {
                            id: heatmapRow
                            anchors.centerIn: parent
                            spacing: root.isWide ? 4 : 3

                            Repeater {
                                model: root.sizeMode === "4x2" ? 20 : (root.sizeMode === "2x3" ? 15 : 10)
                                delegate: Column {
                                    id: weekCol
                                    required property int index
                                    spacing: 3

                                    Repeater {
                                        model: 7 // 7 days (Mon-Sun)
                                        delegate: Rectangle {
                                            id: cellRect
                                            required property int index
                                            width: root.sizeMode === "4x2" ? 13 : (root.sizeMode === "2x3" ? 12 : 10)
                                            height: 7
                                            radius: 2

                                            readonly property int dayIdx: (weekCol.index * 7) + cellRect.index
                                            readonly property var dayData: (root.radarData.heatmap && dayIdx < root.radarData.heatmap.length)
                                                ? root.radarData.heatmap[dayIdx]
                                                : null

                                            readonly property int level: dayData ? (dayData.level || 0) : 0

                                            color: {
                                                switch(level) {
                                                    case 1: return Qt.rgba(0.2, 0.8, 0.45, 0.45)
                                                    case 2: return Qt.rgba(0.2, 0.88, 0.45, 0.72)
                                                    case 3: return Qt.rgba(0.15, 0.95, 0.45, 0.88)
                                                    case 4: return Qt.rgba(0.1, 1.0, 0.5, 1.0)
                                                    default: return Qt.rgba(1, 1, 1, 0.08)
                                                }
                                            }

                                            border.width: cellMouse.containsMouse ? 1 : 0
                                            border.color: Appearance.colors.colPrimary

                                            MouseArea {
                                                id: cellMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onEntered: {
                                                    if (dayData) {
                                                        const pt = cellRect.mapToItem(contentRect, 0, -24);
                                                        root.hoveredTooltipText = `${dayData.date}: ${dayData.count} commits`;
                                                        root.hoveredTooltipX = Math.max(8, Math.min(pt.x - 30, contentRect.width - 150));
                                                        root.hoveredTooltipY = Math.max(8, pt.y);
                                                    }
                                                }
                                                onExited: root.hoveredTooltipText = ""
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Active Repositories Section:
                // In wide modes (4x2 / 2x3): Repos are displayed SIDE-BY-SIDE (RowLayout) to prevent vertical overflow!
                // In 2x2 mode: 1 prominent repo card is displayed cleanly.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Empty state fallback when no repos found
                    Rectangle {
                        visible: !root.radarData.repos || root.radarData.repos.length === 0
                        Layout.fillWidth: true
                        implicitHeight: 52
                        radius: Appearance.rounding.small
                        color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                        border.width: 1
                        border.color: root.widgetBorderColor

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialSymbol {
                                text: root.isRefreshing ? "sync" : "info"
                                iconSize: 15
                                color: Appearance.colors.colPrimary
                            }
                            StyledText {
                                text: root.isRefreshing 
                                    ? Translation.tr("Scanning git repositories...")
                                    : Translation.tr("No git repos detected")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                        }
                    }

                    Repeater {
                        model: (root.radarData.repos ? root.radarData.repos : []).slice(0, root.isWide ? 2 : 1)
                        delegate: Rectangle {
                            id: repoCard
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 54
                            radius: Appearance.rounding.small
                            color: repoMouse.containsMouse 
                                ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.75)
                                : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                            border.width: 1
                            border.color: repoMouse.containsMouse ? Appearance.colors.colPrimary : root.widgetBorderColor

                            ColumnLayout {
                                anchors { fill: parent; margins: 6; leftMargin: 8; rightMargin: 8 }
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    StyledText {
                                        text: repoCard.modelData.name || "repo"
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        font.weight: Font.DemiBold
                                        color: Appearance.colors.colOnPrimaryContainer
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Rectangle {
                                        implicitWidth: branchText.implicitWidth + 6
                                        implicitHeight: 15
                                        radius: 7.5
                                        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.75)
                                        StyledText {
                                            id: branchText
                                            anchors.centerIn: parent
                                            text: repoCard.modelData.branch || "main"
                                            font.pixelSize: 10
                                            color: Appearance.colors.colPrimary
                                        }
                                    }

                                    // Ahead / Modified Indicators
                                    Rectangle {
                                        visible: (repoCard.modelData.ahead || 0) > 0
                                        implicitWidth: aheadText.implicitWidth + 6
                                        implicitHeight: 15
                                        radius: 7.5
                                        color: Qt.rgba(0.2, 0.7, 0.9, 0.25)
                                        StyledText {
                                            id: aheadText
                                            anchors.centerIn: parent
                                            text: `↑${repoCard.modelData.ahead}`
                                            font.pixelSize: 9
                                            color: "#4dd0e1"
                                        }
                                    }
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: repoCard.modelData.last_commit || ""
                                    elide: Text.ElideRight
                                    font.pixelSize: 10
                                    color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.35)
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    visible: (repoCard.modelData.last_time || "").length > 0
                                    text: repoCard.modelData.last_time || ""
                                    elide: Text.ElideRight
                                    font.pixelSize: 9
                                    color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.55)
                                }
                            }

                            MouseArea {
                                id: repoMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (repoCard.modelData.path) {
                                        Quickshell.execDetached([
                                            "bash", "-c", 
                                            `cd "${repoCard.modelData.path}" && (foot || kitty || alacritty || xterm || xdg-open "${repoCard.modelData.path}")`
                                        ]);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Hover tooltip
            Rectangle {
                visible: root.hoveredTooltipText.length > 0
                x: root.hoveredTooltipX
                y: root.hoveredTooltipY
                z: 10
                implicitWidth: tipText.implicitWidth + 12
                implicitHeight: 22
                radius: 11
                color: Appearance.colors.colSurfaceContainerHigh
                border.width: 1
                border.color: Appearance.colors.colPrimary

                StyledText {
                    id: tipText
                    anchors.centerIn: parent
                    text: root.hoveredTooltipText
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnSurface
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
