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

    readonly property real cardWidth: 300
    readonly property real cardHeight: 252
    implicitWidth: root.cardWidth
    implicitHeight: root.cardHeight

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

            ColumnLayout {
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
                            iconSize: 16
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
                        implicitHeight: 22
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
                                iconSize: 13
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
                        width: 24; height: 24; radius: 12
                        color: refreshMouse.containsMouse ? ColorUtils.transparentize(Appearance.colors.colLayer0, 0.7) : "transparent"
                        border.width: 1
                        border.color: refreshMouse.containsMouse ? root.widgetBorderColor : "transparent"

                        MaterialSymbol {
                            id: refreshIcon
                            anchors.centerIn: parent
                            text: "refresh"
                            iconSize: 16
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

                        // Grid: 10 columns (weeks) x 7 rows (days)
                        Row {
                            id: heatmapRow
                            anchors.centerIn: parent
                            spacing: 3

                            Repeater {
                                model: 10 // 10 weeks
                                delegate: Column {
                                    id: weekCol
                                    required property int index
                                    spacing: 3

                                    Repeater {
                                        model: 7 // 7 days (Mon-Sun)
                                        delegate: Rectangle {
                                            id: cellRect
                                            required property int index
                                            width: 10; height: 8; radius: 2

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
                                                        const pt = cellRect.mapToItem(contentRect, 0, -22);
                                                        root.hoveredTooltipText = `${dayData.date}: ${dayData.count} commits`;
                                                        root.hoveredTooltipX = Math.max(8, Math.min(pt.x - 30, contentRect.width - 140));
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

                // Active Repos List
                StyledText {
                    text: Translation.tr("Active Repositories")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colSubtext
                    Layout.topMargin: 2
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: (root.radarData.repos ?? []).slice(0, 2)
                        delegate: Rectangle {
                            id: repoCard
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 38
                            radius: Appearance.rounding.small
                            color: repoMouse.containsMouse 
                                ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.75)
                                : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                            border.width: 1
                            border.color: repoMouse.containsMouse ? Appearance.colors.colPrimary : root.widgetBorderColor

                            RowLayout {
                                anchors { fill: parent; margins: 6 }
                                spacing: 6

                                MaterialSymbol {
                                    text: "fork_right"
                                    iconSize: 16
                                    color: Appearance.colors.colPrimary
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    RowLayout {
                                        spacing: 6
                                        StyledText {
                                            text: repoCard.modelData.name ?? "repo"
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            font.weight: Font.DemiBold
                                            color: Appearance.colors.colOnPrimaryContainer
                                        }
                                        Rectangle {
                                            implicitWidth: branchText.implicitWidth + 8
                                            implicitHeight: 16
                                            radius: 8
                                            color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.75)
                                            StyledText {
                                                id: branchText
                                                anchors.centerIn: parent
                                                text: repoCard.modelData.branch ?? "main"
                                                font.pixelSize: Appearance.font.pixelSize.smallest
                                                color: Appearance.colors.colPrimary
                                            }
                                        }
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: repoCard.modelData.last_commit ?? "No commits"
                                        elide: Text.ElideRight
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        color: Appearance.colors.colSubtext
                                    }
                                }

                                // Sync & Modified Badges
                                RowLayout {
                                    spacing: 4
                                    // Ahead
                                    Rectangle {
                                        visible: (repoCard.modelData.ahead ?? 0) > 0
                                        implicitWidth: aheadText.implicitWidth + 6
                                        implicitHeight: 16; radius: 8
                                        color: Qt.rgba(0.2, 0.7, 0.9, 0.25)
                                        StyledText {
                                            id: aheadText
                                            anchors.centerIn: parent
                                            text: `↑${repoCard.modelData.ahead}`
                                            font.pixelSize: 10
                                            color: "#4dd0e1"
                                        }
                                    }
                                    // Modified
                                    Rectangle {
                                        visible: (repoCard.modelData.modified ?? 0) > 0 || (repoCard.modelData.untracked ?? 0) > 0
                                        implicitWidth: modText.implicitWidth + 6
                                        implicitHeight: 16; radius: 8
                                        color: Qt.rgba(1.0, 0.7, 0.1, 0.25)
                                        StyledText {
                                            id: modText
                                            anchors.centerIn: parent
                                            text: `● ${(repoCard.modelData.modified ?? 0) + (repoCard.modelData.untracked ?? 0)}`
                                            font.pixelSize: 10
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
                implicitWidth: tipText.implicitWidth + 12
                implicitHeight: tipText.implicitHeight + 6
                radius: 4
                color: Appearance.colors.colLayer2
                border.width: 1
                border.color: root.widgetBorderColor
                z: 9999

                StyledText {
                    id: tipText
                    anchors.centerIn: parent
                    text: root.hoveredTooltipText
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colOnLayer2
                }
            }
        }
    }
}
