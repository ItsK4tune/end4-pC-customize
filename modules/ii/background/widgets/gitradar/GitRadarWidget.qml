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

    readonly property real snapWidth1: 320
    readonly property real snapWidth2: 420
    readonly property real cardHeight1: 120
    readonly property real cardHeight2: 252

    property string sizeMode: root.configEntry?.sizeMode ?? "2x2"

    property real widgetWidth: root.sizeMode === "2x3" ? snapWidth2 : snapWidth1
    property real widgetHeight: root.sizeMode === "1x2" ? cardHeight1 : cardHeight2

    implicitWidth: widgetWidth
    implicitHeight: widgetHeight

    Behavior on widgetWidth {
        NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
    }
    Behavior on widgetHeight {
        NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
    }

    function modeForDrag(dx, dy, startWidth) {
        const mid = (snapWidth1 + snapWidth2) / 2;
        const newWidth = startWidth + dx;
        if (newWidth >= mid) return "2x3";
        if (dy < -40) return "1x2";
        if (dy > 40) return "2x2";
        return root.sizeMode;
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
            onDataChanged: {
                try {
                    const parsed = JSON.parse(value.trim());
                    if (parsed && typeof parsed === "object") {
                        root.radarData = parsed;
                    }
                } catch (e) {
                    // JSON parsing incomplete or corrupt
                }
            }
        }
        Component.onCompleted: root.refresh()
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

            // Compact 1x2 Mode Layout
            ColumnLayout {
                visible: root.sizeMode === "1x2"
                anchors { fill: parent; margins: 14 }
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.75)
                        border.width: 1
                        border.color: root.widgetBorderColor
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "terminal"
                            iconSize: 18
                            color: Appearance.colors.colPrimary
                        }
                    }

                    ColumnLayout {
                        spacing: 0
                        StyledText {
                            text: Translation.tr("Git Radar")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        StyledText {
                            text: `${root.radarData.total_commits ?? 0} commits · ${root.radarData.streak ?? 0}d streak`
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Streak Badge
                    Rectangle {
                        implicitWidth: streakCompactRow.implicitWidth + 12
                        implicitHeight: 22
                        radius: Appearance.rounding.full
                        color: Qt.rgba(1, 0.45, 0.1, 0.22)
                        border.width: 1
                        border.color: Qt.rgba(1, 0.5, 0.1, 0.4)

                        RowLayout {
                            id: streakCompactRow
                            anchors.centerIn: parent
                            spacing: 3
                            MaterialSymbol {
                                text: "local_fire_department"
                                iconSize: 14
                                color: "#ff7043"
                            }
                            StyledText {
                                text: `${root.radarData.streak ?? 0}d`
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.Bold
                                color: "#ff7043"
                            }
                        }
                    }
                }

                // Active Repo in 1x2 mode
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Appearance.rounding.small
                    color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                    border.width: 1
                    border.color: root.widgetBorderColor

                    readonly property var topRepo: (root.radarData.repos && root.radarData.repos.length > 0) ? root.radarData.repos[0] : null

                    RowLayout {
                        anchors { fill: parent; margins: 8 }
                        spacing: 8

                        MaterialSymbol {
                            text: "fork_right"
                            iconSize: 18
                            color: Appearance.colors.colPrimary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            RowLayout {
                                spacing: 6
                                StyledText {
                                    text: topRepo ? (topRepo.name ?? "repo") : "No repos detected"
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnPrimaryContainer
                                }
                                Rectangle {
                                    visible: topRepo !== null
                                    implicitWidth: branchCompactText.implicitWidth + 8
                                    implicitHeight: 18
                                    radius: 9
                                    color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.75)
                                    StyledText {
                                        id: branchCompactText
                                        anchors.centerIn: parent
                                        text: topRepo ? (topRepo.branch ?? "main") : ""
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colPrimary
                                    }
                                }
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: topRepo ? (topRepo.last_commit ?? "") : "Start hacking to populate git activity"
                                elide: Text.ElideRight
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (topRepo?.path) {
                                Quickshell.execDetached([
                                    "bash", "-c", 
                                    `cd "${topRepo.path}" && (foot || kitty || alacritty || xterm || xdg-open "${topRepo.path}")`
                                ]);
                            }
                        }
                    }
                }
            }

            // Standard 2x2 and 2x3 Modes Layout
            ColumnLayout {
                visible: root.sizeMode !== "1x2"
                anchors { fill: parent; margins: 14 }
                spacing: 8

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.75)
                        border.width: 1
                        border.color: root.widgetBorderColor
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "terminal"
                            iconSize: 18
                            color: Appearance.colors.colPrimary
                        }
                    }

                    ColumnLayout {
                        spacing: 0
                        StyledText {
                            text: Translation.tr("Git Radar")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        StyledText {
                            text: `${root.radarData.total_commits ?? 0} commits · ${root.radarData.repo_count ?? 0} repos`
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Streak Pill
                    Rectangle {
                        implicitWidth: streakRow.implicitWidth + 12
                        implicitHeight: 24
                        radius: Appearance.rounding.full
                        color: Qt.rgba(1, 0.45, 0.1, 0.22)
                        border.width: 1
                        border.color: Qt.rgba(1, 0.5, 0.1, 0.4)

                        RowLayout {
                            id: streakRow
                            anchors.centerIn: parent
                            spacing: 3
                            MaterialSymbol {
                                text: "local_fire_department"
                                iconSize: 14
                                color: "#ff7043"
                            }
                            StyledText {
                                text: `${root.radarData.streak ?? 0}d`
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
                        border.width: 1
                        border.color: refreshMouse.containsMouse ? root.widgetBorderColor : "transparent"

                        MaterialSymbol {
                            id: refreshIcon
                            anchors.centerIn: parent
                            text: "refresh"
                            iconSize: 17
                            color: Appearance.colors.colSubtext
                            rotation: root.isRefreshing ? 360 : 0
                            Behavior on rotation {
                                NumberAnimation { duration: 600; easing.type: Easing.InOutQuad }
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

                // Heatmap Matrix
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 88
                    radius: Appearance.rounding.normal
                    color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                    border.width: 1
                    border.color: root.widgetBorderColor

                    Item {
                        anchors.fill: parent
                        anchors.margins: 6

                        // Grid: 10 or 14 columns (weeks) x 7 rows (days)
                        Row {
                            id: heatmapRow
                            anchors.centerIn: parent
                            spacing: root.sizeMode === "2x3" ? 4 : 3

                            Repeater {
                                model: root.sizeMode === "2x3" ? 14 : 10
                                delegate: Column {
                                    id: weekCol
                                    required property int index
                                    spacing: 3

                                    Repeater {
                                        model: 7 // 7 days (Mon-Sun)
                                        delegate: Rectangle {
                                            id: cellRect
                                            required property int index
                                            width: root.sizeMode === "2x3" ? 12 : 11
                                            height: 8
                                            radius: 2

                                            readonly property int dayIdx: (weekCol.index * 7) + cellRect.index
                                            readonly property var dayData: (root.radarData.heatmap && dayIdx < root.radarData.heatmap.length)
                                                ? root.radarData.heatmap[dayIdx]
                                                : null

                                            readonly property int level: dayData?.level ?? 0

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
                                                        const pt = cellRect.mapToItem(contentRect, 0, -26);
                                                        root.hoveredTooltipText = `${dayData.date}: ${dayData.count} commits`;
                                                        root.hoveredTooltipX = Math.max(8, Math.min(pt.x - 30, contentRect.width - 150));
                                                        root.hoveredTooltipY = pt.y;
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

                // Active Repos List Title
                StyledText {
                    text: Translation.tr("Active Repositories")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colSubtext
                    Layout.topMargin: 1
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Repeater {
                        model: (root.radarData.repos ?? []).slice(0, root.sizeMode === "2x3" ? 3 : 2)
                        delegate: Rectangle {
                            id: repoCard
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 40
                            radius: Appearance.rounding.small
                            color: repoMouse.containsMouse 
                                ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.75)
                                : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                            border.width: 1
                            border.color: repoMouse.containsMouse ? Appearance.colors.colPrimary : root.widgetBorderColor

                            RowLayout {
                                anchors { fill: parent; margins: 6; leftMargin: 8; rightMargin: 8 }
                                spacing: 8

                                MaterialSymbol {
                                    text: "fork_right"
                                    iconSize: 18
                                    color: Appearance.colors.colPrimary
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    RowLayout {
                                        spacing: 6
                                        StyledText {
                                            text: repoCard.modelData.name ?? "repo"
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            font.weight: Font.DemiBold
                                            color: Appearance.colors.colOnPrimaryContainer
                                        }
                                        Rectangle {
                                            implicitWidth: branchText.implicitWidth + 8
                                            implicitHeight: 18
                                            radius: 9
                                            color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.75)
                                            StyledText {
                                                id: branchText
                                                anchors.centerIn: parent
                                                text: repoCard.modelData.branch ?? "main"
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                color: Appearance.colors.colPrimary
                                            }
                                        }
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: repoCard.modelData.last_commit ?? "No commits"
                                        elide: Text.ElideRight
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colSubtext
                                    }
                                }

                                // Sync & Modified Badges
                                RowLayout {
                                    spacing: 4
                                    // Ahead
                                    Rectangle {
                                        visible: (repoCard.modelData.ahead ?? 0) > 0
                                        implicitWidth: aheadText.implicitWidth + 8
                                        implicitHeight: 18; radius: 9
                                        color: Qt.rgba(0.2, 0.7, 0.9, 0.25)
                                        StyledText {
                                            id: aheadText
                                            anchors.centerIn: parent
                                            text: `↑${repoCard.modelData.ahead}`
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: "#4dd0e1"
                                        }
                                    }
                                    // Modified
                                    Rectangle {
                                        visible: (repoCard.modelData.modified ?? 0) > 0 || (repoCard.modelData.untracked ?? 0) > 0
                                        implicitWidth: modText.implicitWidth + 8
                                        implicitHeight: 18; radius: 9
                                        color: Qt.rgba(1.0, 0.7, 0.1, 0.25)
                                        StyledText {
                                            id: modText
                                            anchors.centerIn: parent
                                            text: `● ${(repoCard.modelData.modified ?? 0) + (repoCard.modelData.untracked ?? 0)}`
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: "#ffb74d"
                                        }
                                    }
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

            // Floating Tooltip
            Rectangle {
                visible: root.hoveredTooltipText !== ""
                x: root.hoveredTooltipX
                y: root.hoveredTooltipY
                implicitWidth: tipText.implicitWidth + 14
                implicitHeight: tipText.implicitHeight + 8
                radius: 6
                color: Appearance.colors.colLayer2
                border.width: 1
                border.color: root.widgetBorderColor
                z: 9999

                StyledText {
                    id: tipText
                    anchors.centerIn: parent
                    text: root.hoveredTooltipText
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnLayer2
                }
            }
        }

        ResizeHandler {
            anchorItem: contentRect
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
