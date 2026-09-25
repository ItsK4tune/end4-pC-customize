pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property color textColor: Appearance.colors.colOnLayer0
    property color activeColor: Appearance.colors.colPrimary
    property color dimColor: Appearance.colors.colSubtext
    property color indicatorColor: Appearance.colors.colPrimaryContainer
    property color indicatorShapeColor: Appearance.colors.colOnPrimaryContainer
    property int textAlignment: Text.AlignHCenter

    property bool isDetached: false
    property bool showControls: true
    property bool showManualSearch: false

    implicitWidth: 200
    implicitHeight: 200

    function openManualSearch() {
        const rawTitle = MprisController.activePlayer?.trackTitle ?? ""
        const cleanT = StringUtils.cleanMusicTitle(rawTitle) || rawTitle
        titleField.text = cleanT
        artistField.text = MprisController.activePlayer?.trackArtist ?? ""
        root.showManualSearch = true
        titleField.forceActiveFocus()
        titleField.selectAll()
    }

    function executeManualSearch() {
        if (!titleField.text.trim()) return
        LyricsService.searchManual(titleField.text.trim(), artistField.text.trim())
        root.showManualSearch = false
        root.reattachAndScroll()
    }

    function reattachAndScroll() {
        root.isDetached = false
        if (LyricsService.activeIndex >= 0) {
            root.scrollToIndex(LyricsService.activeIndex, true)
        }
    }

    function restartLyrics(force = false) {
        LyricsService.restartLyrics(force)
        root.reattachAndScroll()
    }

    function scrollToIndex(idx, smooth = true) {
        if (idx < 0 || idx >= LyricsService.lyricsLines.length) return
        listView.positionViewAtIndex(idx, ListView.Contain)
        const item = listView.itemAtIndex(idx)
        if (item) {
            const targetY = item.y - (listView.height - item.height) / 2
            const minY = -listView.topMargin
            const maxY = Math.max(minY, listView.contentHeight - listView.height + listView.bottomMargin)
            const boundedY = Math.max(minY, Math.min(targetY, maxY))
            if (smooth) {
                smoothScrollAnim.stop()
                smoothScrollAnim.to = boundedY
                smoothScrollAnim.restart()
            } else {
                listView.contentY = boundedY
            }
        } else {
            listView.positionViewAtIndex(idx, ListView.Center)
        }
    }

    // Reset detached state when lyrics are reloaded or track changes
    Connections {
        target: LyricsService
        function onLyricsLinesChanged() {
            root.isDetached = false
            listView.contentY = -listView.topMargin
        }
        function onActiveIndexChanged() {
            if (!root.isDetached && LyricsService.activeIndex >= 0) {
                root.scrollToIndex(LyricsService.activeIndex, true)
            }
        }
    }

    // ── Placeholder / Not OK state ──
    Item {
        anchors.fill: parent
        visible: LyricsService.status !== "ok" && !root.showManualSearch

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 8

            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 40
                implicitHeight: 40

                MaterialLoadingIndicator {
                    anchors.fill: parent
                    loading: LyricsService.status === "loading"
                    colBg: root.indicatorColor
                    colShape: root.indicatorShapeColor
                    implicitSize: 40
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: LyricsService.restartLyrics(true)
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                color: root.dimColor
                font.pixelSize: Appearance.font.pixelSize.small
                horizontalAlignment: Text.AlignHCenter
                text: {
                    if (LyricsService.status === "loading") return Translation.tr("Searching lyrics...");
                    if (LyricsService.status === "no_info") return Translation.tr("No track playing");
                    if (LyricsService.status === "not_found") return Translation.tr("No lyrics found");
                    return "";
                }
            }

            // Manual Search Button
            Rectangle {
                id: manualSearchBtn
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                visible: LyricsService.status !== "loading"
                implicitWidth: manualSearchBtnLayout.implicitWidth + 20
                implicitHeight: 28
                radius: Appearance.rounding.full
                color: manualBtnMouse.containsMouse
                    ? ColorUtils.transparentize(root.activeColor, 0.85)
                    : "transparent"
                border.color: ColorUtils.transparentize(root.dimColor, manualBtnMouse.containsMouse ? 0.3 : 0.6)
                border.width: 1

                RowLayout {
                    id: manualSearchBtnLayout
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialSymbol {
                        text: "manage_search"
                        iconSize: 15
                        color: root.dimColor
                    }

                    StyledText {
                        text: Translation.tr("Manual search")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: root.dimColor
                    }
                }

                MouseArea {
                    id: manualBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openManualSearch()
                }
            }
        }
    }

    // ── Manual Search Overlay ──
    Rectangle {
        id: manualSearchOverlay
        anchors.centerIn: parent
        width: Math.min(parent.width - 16, 320)
        implicitHeight: manualSearchLayout.implicitHeight + 24
        visible: root.showManualSearch
        radius: Appearance.rounding.large
        color: Appearance.colors.colLayer1
        border.color: ColorUtils.transparentize(root.activeColor, 0.4)
        border.width: 1
        z: 60
        clip: true

        ColumnLayout {
            id: manualSearchLayout
            anchors {
                fill: parent
                margins: 14
            }
            spacing: 10

            // Header
            RowLayout {
                Layout.fillWidth: true
                MaterialSymbol {
                    text: "manage_search"
                    iconSize: 20
                    color: root.activeColor
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Manual Lyrics Search")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Bold
                    color: root.textColor
                }
                RippleButton {
                    implicitWidth: 24
                    implicitHeight: 24
                    buttonRadius: Appearance.rounding.full
                    colBackground: "transparent"
                    colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colLayer2, 0.4)
                    colRipple: ColorUtils.transparentize(Appearance.colors.colLayer2, 0.2)
                    downAction: () => { root.showManualSearch = false }
                    contentItem: MaterialSymbol {
                        text: "close"
                        iconSize: 16
                        color: root.dimColor
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // Song Title Input
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                StyledText {
                    text: Translation.tr("Song Title")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.dimColor
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 32
                    radius: Appearance.rounding.small
                    color: titleField.activeFocus
                        ? ColorUtils.transparentize(root.activeColor, 0.88)
                        : ColorUtils.transparentize(Appearance.colors.colLayer2, 0.5)
                    border.color: titleField.activeFocus
                        ? root.activeColor
                        : ColorUtils.transparentize(root.dimColor, 0.6)
                    border.width: 1

                    TextInput {
                        id: titleField
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: TextInput.AlignVCenter
                        color: root.textColor
                        font.pixelSize: Appearance.font.pixelSize.small
                        selectByMouse: true
                        clip: true
                        onAccepted: root.executeManualSearch()
                        Keys.onEscapePressed: root.showManualSearch = false
                    }
                }
            }

            // Artist Input
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                StyledText {
                    text: Translation.tr("Artist (Optional)")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.dimColor
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 32
                    radius: Appearance.rounding.small
                    color: artistField.activeFocus
                        ? ColorUtils.transparentize(root.activeColor, 0.88)
                        : ColorUtils.transparentize(Appearance.colors.colLayer2, 0.5)
                    border.color: artistField.activeFocus
                        ? root.activeColor
                        : ColorUtils.transparentize(root.dimColor, 0.6)
                    border.width: 1

                    TextInput {
                        id: artistField
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: TextInput.AlignVCenter
                        color: root.textColor
                        font.pixelSize: Appearance.font.pixelSize.small
                        selectByMouse: true
                        clip: true
                        onAccepted: root.executeManualSearch()
                        Keys.onEscapePressed: root.showManualSearch = false
                    }
                }
            }

            // Actions: Search & Cancel
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8

                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 32
                    buttonRadius: Appearance.rounding.small
                    colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 0.5)
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    colRipple: Appearance.colors.colLayer2Active
                    downAction: () => { root.showManualSearch = false }
                    contentItem: StyledText {
                        text: Translation.tr("Cancel")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: root.dimColor
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 32
                    buttonRadius: Appearance.rounding.small
                    colBackground: root.activeColor
                    colBackgroundHover: ColorUtils.transparentize(root.activeColor, 0.15)
                    colRipple: ColorUtils.transparentize(root.activeColor, 0.3)
                    downAction: () => root.executeManualSearch()
                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            text: "search"
                            iconSize: 16
                            color: Appearance.colors.colOnPrimary
                        }
                        StyledText {
                            text: Translation.tr("Search")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnPrimary
                        }
                    }
                }
            }
        }
    }

    // ── Active Lyrics View ──
    Item {
        anchors.fill: parent
        visible: LyricsService.status === "ok"
        clip: true

        NumberAnimation {
            id: smoothScrollAnim
            target: listView
            property: "contentY"
            duration: 350
            easing.type: Easing.OutCubic
        }

        ListView {
            id: listView
            anchors.fill: parent
            model: LyricsService.lyricsLines
            spacing: 14
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 600
            interactive: true

            topMargin: Math.max(10, height * 0.4)
            bottomMargin: Math.max(10, height * 0.4)

            // Detect user scrolling to detach / re-attach
            onContentYChanged: {
                if (!listView.movingVertically && !listView.flicking && !listView.dragging) return
                if (LyricsService.activeIndex < 0) return

                const activeItem = listView.itemAtIndex(LyricsService.activeIndex)
                if (!activeItem) {
                    root.isDetached = true
                    return
                }

                const itemCenterY = activeItem.mapToItem(listView, 0, activeItem.height / 2).y
                const viewportCenter = listView.height / 2
                const distFromCenter = Math.abs(itemCenterY - viewportCenter)

                // If user scrolled away beyond threshold, mark detached
                if (distFromCenter > listView.height * 0.42) {
                    root.isDetached = true
                } else if (distFromCenter <= listView.height * 0.28) {
                    // Automatically re-attach when user scrolls back to the current playing line
                    root.isDetached = false
                }
            }

            delegate: Item {
                id: lyricDelegate
                required property int index
                required property var modelData

                readonly property bool isActive: index === LyricsService.activeIndex
                readonly property int dist: Math.abs(index - LyricsService.activeIndex)
                readonly property bool isHovered: lineMouse.containsMouse || syncLineMouse.containsMouse

                width: listView.width
                height: Math.max(34, lyricText.implicitHeight + 12)
                implicitHeight: height

                StyledText {
                    id: lyricText
                    anchors.centerIn: parent
                    width: parent.width - (syncLineButton.visible ? 56 : 20)
                    horizontalAlignment: root.textAlignment
                    wrapMode: Text.WordWrap
                    text: lyricDelegate.modelData?.text || "♪"

                    font.pixelSize: {
                        if (lyricDelegate.isActive) return Appearance.font.pixelSize.large
                        if (lyricDelegate.dist === 1) return Appearance.font.pixelSize.normal
                        return Appearance.font.pixelSize.small
                    }
                    font.weight: lyricDelegate.isActive ? Font.Bold : Font.Normal
                    color: lyricDelegate.isActive ? root.activeColor : (lyricDelegate.dist <= 2 ? root.textColor : root.dimColor)
                    opacity: {
                        if (lyricDelegate.isActive) return 1.0
                        if (lyricDelegate.dist === 1) return 0.65
                        if (lyricDelegate.dist === 2) return 0.38
                        return 0.18
                    }
                    scale: lyricDelegate.isActive ? 1.04 : 1.0

                    Behavior on font.pixelSize { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 250 } }
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                }

                // Quick 1-click sync button (appears on hover) to sync this line with current player position
                Rectangle {
                    id: syncLineButton
                    anchors {
                        right: parent.right
                        rightMargin: 6
                        verticalCenter: parent.verticalCenter
                    }
                    visible: lyricDelegate.isHovered && root.showControls && LyricsService.status === "ok"
                    implicitWidth: 26
                    implicitHeight: 26
                    radius: Appearance.rounding.small
                    color: syncLineMouse.containsMouse
                        ? ColorUtils.transparentize(root.activeColor, 0.70)
                        : ColorUtils.transparentize(Appearance.colors.colLayer2, 0.4)
                    border.color: ColorUtils.transparentize(root.activeColor, 0.3)
                    border.width: 1
                    z: 5

                    MaterialSymbol {
                        anchors.centerIn: parent
                        iconSize: 15
                        text: "more_time"
                        color: root.activeColor
                    }

                    MouseArea {
                        id: syncLineMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            LyricsService.syncLineToCurrentTime(lyricDelegate.index)
                            root.isDetached = false
                        }
                    }
                }

                MouseArea {
                    id: lineMouse
                    anchors.fill: parent
                    anchors.rightMargin: syncLineButton.visible ? 32 : 0
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            LyricsService.syncLineToCurrentTime(lyricDelegate.index)
                            root.isDetached = false
                        } else {
                            LyricsService.seekToLine(lyricDelegate.index)
                            root.isDetached = false
                            root.scrollToIndex(lyricDelegate.index, true)
                        }
                    }
                }
            }
        }

        // ── Floating Re-attach Button (appears when user is detached) ──
        Rectangle {
            id: reattachButton
            anchors {
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
                bottomMargin: 10
            }
            visible: root.isDetached && LyricsService.status === "ok" && LyricsService.activeIndex >= 0
            implicitWidth: reattachLayout.implicitWidth + 24
            implicitHeight: 32
            radius: Appearance.rounding.full
            color: reattachMouse.containsMouse ? ColorUtils.transparentize(root.activeColor, 0.70) : ColorUtils.transparentize(Appearance.colors.colLayer2, 0.2)
            border.color: ColorUtils.transparentize(root.activeColor, 0.35)
            border.width: 1

            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            Behavior on color { ColorAnimation { duration: 150 } }

            RowLayout {
                id: reattachLayout
                anchors.centerIn: parent
                spacing: 6

                MaterialSymbol {
                    iconSize: 16
                    text: "my_location"
                    color: root.activeColor
                }

                StyledText {
                    text: Translation.tr("Sync to current")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: root.activeColor
                }
            }

            MouseArea {
                id: reattachMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.reattachAndScroll()
            }
        }

        // ── Subtle Offset Adjustment Controls (±0.5s for long intro / desynced songs) ──
        Item {
            anchors {
                top: parent.top
                right: parent.right
                margins: 4
            }
            width: offsetRow.implicitWidth
            height: 24
            visible: root.showControls && LyricsService.status === "ok"

            RowLayout {
                id: offsetRow
                anchors.fill: parent
                spacing: 4

                // Manual search button (opens manual search dialog anytime)
                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: Appearance.rounding.small
                    color: searchIconMouse.containsMouse ? ColorUtils.transparentize(Appearance.colors.colLayer2, 0.4) : ColorUtils.transparentize(Appearance.colors.colLayer1, 0.6)
                    border.color: ColorUtils.transparentize(root.activeColor, searchIconMouse.containsMouse ? 0.4 : 0.15)
                    border.width: 1

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "search"
                        iconSize: 14
                        color: root.dimColor
                    }

                    MouseArea {
                        id: searchIconMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openManualSearch()
                    }
                }

                // Minus 0.5s button
                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: Appearance.rounding.small
                    color: minusMouse.containsMouse ? ColorUtils.transparentize(Appearance.colors.colLayer2, 0.4) : ColorUtils.transparentize(Appearance.colors.colLayer1, 0.6)
                    border.color: ColorUtils.transparentize(root.activeColor, minusMouse.containsMouse ? 0.4 : 0.15)
                    border.width: 1

                    StyledText {
                        anchors.centerIn: parent
                        text: "-"
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Bold
                        color: root.dimColor
                    }

                    MouseArea {
                        id: minusMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: LyricsService.adjustOffset(-0.5)
                    }
                }

                // Editable offset input box (always visible, click to type, wheel to scroll)
                Rectangle {
                    id: offsetBox
                    implicitWidth: Math.max(52, offsetInput.implicitWidth + 16)
                    implicitHeight: 22
                    radius: Appearance.rounding.small
                    color: offsetInput.activeFocus
                        ? ColorUtils.transparentize(root.activeColor, 0.80)
                        : (offsetBoxMouse.containsMouse
                            ? ColorUtils.transparentize(Appearance.colors.colLayer2, 0.4)
                            : ColorUtils.transparentize(Appearance.colors.colLayer1, 0.6))
                    border.color: offsetInput.activeFocus
                        ? root.activeColor
                        : ColorUtils.transparentize(root.activeColor, Math.abs(LyricsService.manualOffset) > 0.05 ? 0.4 : 0.15)
                    border.width: 1

                    TextInput {
                        id: offsetInput
                        anchors.centerIn: parent
                        width: parent.width - 8
                        horizontalAlignment: TextInput.AlignHCenter
                        verticalAlignment: TextInput.AlignVCenter
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                        color: Math.abs(LyricsService.manualOffset) > 0.05 ? root.activeColor : root.dimColor
                        selectByMouse: true
                        inputMethodHints: Qt.ImhFormattedNumbersOnly

                        text: {
                            if (activeFocus) return LyricsService.manualOffset.toString()
                            const off = LyricsService.manualOffset
                            return (off > 0 ? "+" : "") + off.toFixed(1) + "s"
                        }

                        onAccepted: {
                            LyricsService.setOffset(text.replace(/s$/i, ""))
                            focus = false
                        }

                        onEditingFinished: {
                            LyricsService.setOffset(text.replace(/s$/i, ""))
                        }
                    }

                    MouseArea {
                        id: offsetBoxMouse
                        anchors.fill: parent
                        enabled: !offsetInput.activeFocus
                        hoverEnabled: true
                        cursorShape: Qt.IBeamCursor
                        onClicked: {
                            offsetInput.forceActiveFocus()
                            offsetInput.selectAll()
                        }
                        onWheel: (event) => {
                            if (event.angleDelta.y > 0) {
                                LyricsService.adjustOffset(0.5)
                            } else if (event.angleDelta.y < 0) {
                                LyricsService.adjustOffset(-0.5)
                            }
                        }
                    }
                }

                // Plus 0.5s button
                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: Appearance.rounding.small
                    color: plusMouse.containsMouse ? ColorUtils.transparentize(Appearance.colors.colLayer2, 0.4) : ColorUtils.transparentize(Appearance.colors.colLayer1, 0.6)
                    border.color: ColorUtils.transparentize(root.activeColor, plusMouse.containsMouse ? 0.4 : 0.15)
                    border.width: 1

                    StyledText {
                        anchors.centerIn: parent
                        text: "+"
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Bold
                        color: root.dimColor
                    }

                    MouseArea {
                        id: plusMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: LyricsService.adjustOffset(0.5)
                    }
                }

                // Quick reset button (visible only when offset is not 0)
                Rectangle {
                    visible: Math.abs(LyricsService.manualOffset) > 0.05
                    implicitWidth: 18
                    implicitHeight: 22
                    radius: Appearance.rounding.small
                    color: resetMouse.containsMouse ? ColorUtils.transparentize(Appearance.colors.colLayer2, 0.4) : "transparent"

                    StyledText {
                        anchors.centerIn: parent
                        text: "×"
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: root.dimColor
                    }

                    MouseArea {
                        id: resetMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: LyricsService.resetOffset()
                    }
                }
            }
        }
    }
}