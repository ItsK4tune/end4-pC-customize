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
    configEntryName: "habitGrid"
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
    draggable: placementStrategy === "free" && !Config.options.background.widgetsLocked && !root.isAddingHabit

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

    property string filePath: FileUtils.trimFileProtocol(`${Directories.state}/user/habits.json`)
    property var habits: []
    property bool isAddingHabit: false
    property string newHabitTitle: ""

    onIsAddingHabitChanged: {
        GlobalStates.desktopWidgetKeyboardFocus = root.isAddingHabit;
        if (root.isAddingHabit) {
            Qt.callLater(() => {
                newHabitInput.forceActiveFocus();
            });
        }
    }

    Component.onDestruction: {
        if (root.isAddingHabit) {
            GlobalStates.desktopWidgetKeyboardFocus = false;
        }
    }

    readonly property real fixedRightBlockWidth: 56
    readonly property real colWidth: root.sizeMode === "2x3" ? 20 : 16
    readonly property real colSpacing: root.sizeMode === "2x3" ? 5 : 3

    readonly property string todayDateStr: {
        const now = new Date();
        const y = now.getFullYear();
        const m = String(now.getMonth() + 1).padStart(2, '0');
        const d = String(now.getDate()).padStart(2, '0');
        return `${y}-${m}-${d}`;
    }

    // Past 6 days + today (7 days total)
    readonly property var weekDays: {
        let arr = [];
        const dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        for (let i = 6; i >= 0; i--) {
            const d = new Date();
            d.setDate(d.getDate() - i);
            const y = d.getFullYear();
            const m = String(d.getMonth() + 1).padStart(2, '0');
            const dayNum = String(d.getDate()).padStart(2, '0');
            const dateStr = `${y}-${m}-${dayNum}`;
            arr.push({
                "dateStr": dateStr,
                "label": dayNames[d.getDay()],
                "isToday": (i === 0)
            });
        }
        return arr;
    }

    function calculateStreak(history) {
        if (!history) return 0;
        let streak = 0;
        let cur = new Date();
        const y = cur.getFullYear();
        const m = String(cur.getMonth() + 1).padStart(2, '0');
        const d = String(cur.getDate()).padStart(2, '0');
        const todayStr = `${y}-${m}-${d}`;

        // If today not checked yet, start checking from yesterday
        if (!history[todayStr]) {
            cur.setDate(cur.getDate() - 1);
        }

        while (true) {
            const cy = cur.getFullYear();
            const cm = String(cur.getMonth() + 1).padStart(2, '0');
            const cd = String(cur.getDate()).padStart(2, '0');
            const str = `${cy}-${cm}-${cd}`;
            if (history[str]) {
                streak++;
                cur.setDate(cur.getDate() - 1);
            } else {
                break;
            }
        }
        return streak;
    }

    function toggleHabit(habitIndex, dateStr) {
        if (habitIndex < 0 || habitIndex >= habits.length) return;
        let list = habits.slice();
        let h = Object.assign({}, list[habitIndex]);
        let hist = Object.assign({}, h.history ?? {});

        if (hist[dateStr]) {
            delete hist[dateStr];
        } else {
            hist[dateStr] = true;
        }

        h.history = hist;
        h.streak = calculateStreak(hist);
        list[habitIndex] = h;
        root.habits = list;
        saveHabits();
    }

    function submitNewHabit() {
        const inputField = (typeof newHabitInput !== "undefined" && newHabitInput) ? newHabitInput : null;
        const title = (inputField ? inputField.text : root.newHabitTitle).trim();
        if (title.length > 0) {
            root.addHabit(title);
        }
        root.newHabitTitle = "";
        root.isAddingHabit = false;
    }

    function addHabit(title) {
        if (!title || title.trim().length === 0) return;
        let list = habits.slice();
        const icons = ["water_drop", "menu_book", "fitness_center", "terminal", "self_improvement", "bedtime", "psychology", "directions_run", "laptop_chromebook", "brush"];
        const colors = ["#29b6f6", "#ab47bc", "#66bb6a", "#ffa726", "#ec407a", "#5c6bc0", "#26a69a", "#e91e63", "#00bcd4", "#ff5722"];
        const idx = list.length % icons.length;

        list.push({
            "id": "h_" + Date.now(),
            "title": title.trim(),
            "icon": icons[idx],
            "color": colors[idx],
            "history": {},
            "streak": 0
        });
        root.habits = list;
        root.newHabitTitle = "";
        root.isAddingHabit = false;
        saveHabits();
    }

    function deleteHabit(habitIndex) {
        if (habitIndex < 0 || habitIndex >= habits.length) return;
        let list = habits.slice();
        list.splice(habitIndex, 1);
        root.habits = list;
        saveHabits();
    }

    function saveHabits() {
        habitsFileView.setText(JSON.stringify(root.habits, null, 2));
    }

    readonly property int completedTodayCount: {
        let c = 0;
        for (let i = 0; i < habits.length; i++) {
            if (habits[i]?.history && habits[i].history[todayDateStr]) {
                c++;
            }
        }
        return c;
    }

    readonly property real completionRatio: habits.length > 0 ? (completedTodayCount / habits.length) : 0

    FileView {
        id: habitsFileView
        path: Qt.resolvedUrl(root.filePath)
        onLoaded: {
            try {
                const parsed = JSON.parse(habitsFileView.text());
                if (Array.isArray(parsed) && parsed.length > 0) {
                    root.habits = parsed;
                } else {
                    root.createDefaultHabits();
                }
            } catch (e) {
                root.createDefaultHabits();
            }
        }
        onLoadFailed: error => {
            root.createDefaultHabits();
        }
    }

    function createDefaultHabits() {
        root.habits = [
            {
                "id": "h_1",
                "title": Translation.tr("Drink 2L Water"),
                "icon": "water_drop",
                "color": "#29b6f6",
                "history": { [todayDateStr]: true },
                "streak": 1
            },
            {
                "id": "h_2",
                "title": Translation.tr("Read 30 mins"),
                "icon": "menu_book",
                "color": "#ab47bc",
                "history": {},
                "streak": 0
            },
            {
                "id": "h_3",
                "title": Translation.tr("Exercise & Stretch"),
                "icon": "fitness_center",
                "color": "#66bb6a",
                "history": { [todayDateStr]: true },
                "streak": 1
            },
            {
                "id": "h_4",
                "title": Translation.tr("Code / Deep Work"),
                "icon": "terminal",
                "color": "#ffa726",
                "history": {},
                "streak": 0
            }
        ];
        saveHabits();
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
                spacing: 6

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
                            text: "checklist"
                            iconSize: 18
                            color: Appearance.colors.colPrimary
                        }
                    }

                    ColumnLayout {
                        spacing: 0
                        StyledText {
                            text: Translation.tr("Habit Grid")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        StyledText {
                            text: `${root.completedTodayCount}/${root.habits.length} done (${Math.round(root.completionRatio * 100)}%)`
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Add Habit Toggle Button (shown in 2x2 and 2x3 modes)
                    Rectangle {
                        visible: root.sizeMode !== "1x2"
                        width: 26; height: 26; radius: 13
                        color: addMouse.containsMouse ? ColorUtils.transparentize(Appearance.colors.colLayer0, 0.7) : "transparent"
                        border.width: 1
                        border.color: addMouse.containsMouse ? root.widgetBorderColor : "transparent"
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: root.isAddingHabit ? "close" : "add"
                            iconSize: 18
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        MouseArea {
                            id: addMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.isAddingHabit = !root.isAddingHabit
                        }
                    }
                }

                // Quick Add Habit Bar (when toggled)
                Rectangle {
                    visible: root.isAddingHabit && root.sizeMode !== "1x2"
                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: Appearance.rounding.small
                    color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                    border.width: 1
                    border.color: Appearance.colors.colPrimary

                    RowLayout {
                        anchors { fill: parent; margins: 4; leftMargin: 8; rightMargin: 6 }
                        spacing: 6

                        MaterialSymbol {
                            text: "add_task"
                            iconSize: 16
                            color: Appearance.colors.colPrimary
                        }

                        TextField {
                            id: newHabitInput
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            verticalAlignment: TextInput.AlignVCenter
                            color: Appearance.colors.colOnPrimaryContainer
                            font.pixelSize: Appearance.font.pixelSize.small
                            selectByMouse: true
                            clip: true
                            focus: true
                            placeholderText: Translation.tr("Habit name (press Enter)...")
                            placeholderTextColor: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.45)
                            background: null
                            text: root.newHabitTitle
                            onTextChanged: root.newHabitTitle = text
                            onAccepted: root.submitNewHabit()
                            Keys.onReturnPressed: root.submitNewHabit()
                            Keys.onEnterPressed: root.submitNewHabit()
                            Keys.onEscapePressed: {
                                root.newHabitTitle = "";
                                root.isAddingHabit = false;
                            }
                        }

                        // Add / Submit button
                        Rectangle {
                            implicitWidth: 26; implicitHeight: 26; radius: 13
                            color: addBtnMouse.containsMouse ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.2) : Appearance.colors.colPrimary
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.2)

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "check"
                                iconSize: 15
                                color: Appearance.colors.colOnPrimary
                            }
                            MouseArea {
                                id: addBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.submitNewHabit()
                            }
                        }
                    }
                }

                // Compact 1x2 Mode: Horizontal Today List
                ListView {
                    visible: root.sizeMode === "1x2"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    orientation: ListView.Horizontal
                    spacing: 8
                    clip: true
                    model: root.habits

                    delegate: Rectangle {
                        id: compactCard
                        required property var modelData
                        required property int index
                        width: 130
                        height: ListView.view.height
                        radius: Appearance.rounding.small
                        color: compactHover.hovered 
                            ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.75)
                            : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                        border.width: 1
                        border.color: root.widgetBorderColor

                        HoverHandler { id: compactHover }

                        readonly property bool isTodayDone: (compactCard.modelData?.history && compactCard.modelData.history[root.todayDateStr]) === true

                        RowLayout {
                            anchors { fill: parent; margins: 8 }
                            spacing: 8

                            Rectangle {
                                width: 26; height: 26; radius: 13
                                color: compactCard.isTodayDone 
                                    ? (compactCard.modelData?.color ?? Appearance.colors.colPrimary)
                                    : Qt.rgba(1, 1, 1, 0.1)
                                border.width: 1.5
                                border.color: compactCard.modelData?.color ?? Appearance.colors.colPrimary

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: compactCard.isTodayDone ? "check" : (compactCard.modelData?.icon ?? "check_circle")
                                    iconSize: 14
                                    color: compactCard.isTodayDone ? "#ffffff" : (compactCard.modelData?.color ?? Appearance.colors.colPrimary)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleHabit(compactCard.index, root.todayDateStr)
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                StyledText {
                                    Layout.fillWidth: true
                                    text: compactCard.modelData?.title ?? ""
                                    elide: Text.ElideRight
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnPrimaryContainer
                                }
                                StyledText {
                                    text: `${compactCard.modelData?.streak ?? 0}d streak`
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: "#ff7043"
                                }
                            }
                        }
                    }
                }

                // Standard 2x2 and 2x3 Modes: 7-Day Matrix Header
                RowLayout {
                    visible: root.sizeMode !== "1x2"
                    Layout.fillWidth: true
                    Layout.rightMargin: 16
                    spacing: 0

                    Item { Layout.fillWidth: true }

                    Row {
                        spacing: root.colSpacing
                        Repeater {
                            model: root.weekDays
                            delegate: Item {
                                required property var modelData
                                width: root.colWidth
                                implicitHeight: 16
                                StyledText {
                                    anchors.centerIn: parent
                                    text: parent.modelData.label
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    font.weight: parent.modelData.isToday ? Font.Bold : Font.Normal
                                    color: parent.modelData.isToday ? Appearance.colors.colPrimary : Appearance.colors.colOnPrimaryContainer
                                }
                            }
                        }
                    }

                    // Space reservation matching row delegate's right block
                    Item { width: root.fixedRightBlockWidth; height: 16 }
                }

                // Habit List Rows (2x2 and 2x3 Modes)
                ListView {
                    visible: root.sizeMode !== "1x2"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.rightMargin: 16
                    Layout.bottomMargin: 8
                    clip: true
                    spacing: 5
                    model: root.habits

                    delegate: Rectangle {
                        id: habitRow
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        implicitHeight: 34
                        radius: Appearance.rounding.small
                        color: rowHover.hovered 
                            ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.75)
                            : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                        border.width: 1
                        border.color: root.widgetBorderColor

                        HoverHandler {
                            id: rowHover
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 0
                            anchors.topMargin: 3
                            anchors.bottomMargin: 3
                            spacing: 0

                            // Icon & Title
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                MaterialSymbol {
                                    text: habitRow.modelData?.icon ?? "check_circle"
                                    iconSize: 17
                                    color: habitRow.modelData?.color ?? Appearance.colors.colPrimary
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: habitRow.modelData?.title ?? ""
                                    elide: Text.ElideRight
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnPrimaryContainer
                                }
                            }

                            // 7 Check-in Dots for the 7 days (Fixed Row with generous hitboxes)
                            Row {
                                spacing: root.colSpacing
                                Repeater {
                                    model: root.weekDays
                                    delegate: Item {
                                        id: dotItem
                                        required property var modelData
                                        width: root.colWidth
                                        height: 28

                                        readonly property bool isDone: (habitRow.modelData?.history && habitRow.modelData.history[dotItem.modelData.dateStr]) === true

                                        Rectangle {
                                            id: checkCircle
                                            anchors.centerIn: parent
                                            width: dotItem.modelData.isToday ? 15 : 12
                                            height: width
                                            radius: width / 2
                                            color: dotItem.isDone
                                                ? (habitRow.modelData?.color ?? Appearance.colors.colPrimary)
                                                : (dotItem.modelData.isToday ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.7) : Qt.rgba(1, 1, 1, 0.1))
                                            border.width: dotItem.modelData.isToday ? 1.5 : 1
                                            border.color: dotItem.modelData.isToday ? Appearance.colors.colPrimary : root.widgetBorderColor

                                            scale: 1.0
                                            Behavior on scale {
                                                NumberAnimation { duration: 150; easing.type: Easing.OutBack }
                                            }

                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: "check"
                                                iconSize: dotItem.modelData.isToday ? 10 : 8
                                                color: "#ffffff"
                                                visible: dotItem.isDone
                                            }
                                        }

                                        // Clickable hitbox filling the entire column
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                checkCircle.scale = 1.35;
                                                resetScaleTimer.start();
                                                root.toggleHabit(habitRow.index, dotItem.modelData.dateStr);
                                            }
                                        }

                                        Timer {
                                            id: resetScaleTimer
                                            interval: 120
                                            onTriggered: checkCircle.scale = 1.0
                                        }
                                    }
                                }
                            }

                            // Streak Counter & Independent Delete Target in exact fixed-width container
                            Item {
                                width: root.fixedRightBlockWidth
                                height: parent.height

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 2

                                    // Streak Badge
                                    RowLayout {
                                        spacing: 1
                                        MaterialSymbol {
                                            text: "local_fire_department"
                                            iconSize: 12
                                            color: "#ff7043"
                                        }
                                        StyledText {
                                            text: `${habitRow.modelData?.streak ?? 0}`
                                            font.pixelSize: Appearance.font.pixelSize.smallest
                                            font.weight: Font.Bold
                                            color: "#ff7043"
                                        }
                                    }

                                    // Delete Button: Generous Hitbox with Smooth Fade
                                    Rectangle {
                                        width: 22; height: 22; radius: 11
                                        color: delMouse.containsMouse ? Qt.rgba(1, 0.2, 0.2, 0.25) : "transparent"
                                        opacity: rowHover.hovered ? 1.0 : 0.35
                                        Behavior on opacity {
                                            NumberAnimation { duration: 150 }
                                        }

                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "delete"
                                            iconSize: 13
                                            color: delMouse.containsMouse ? "#ef5350" : Appearance.colors.colOnPrimaryContainer
                                        }

                                        MouseArea {
                                            id: delMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.deleteHabit(habitRow.index)
                                        }
                                    }
                                }
                            }
                        }
                    }
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
