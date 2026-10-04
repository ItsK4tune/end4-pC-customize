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
    draggable: placementStrategy === "free" && !Config.options.background.widgetsLocked && !root.isAddingHabit

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

    property string filePath: FileUtils.trimFileProtocol(`${Directories.state}/user/habits.json`)
    property var habits: []
    property bool isAddingHabit: false
    property string newHabitTitle: ""

    onIsAddingHabitChanged: {
        GlobalStates.desktopWidgetKeyboardFocus = root.isAddingHabit;
        if (root.isAddingHabit) {
            Qt.callLater(() => {
                if (root.isWide && newHabitInputWide) {
                    newHabitInputWide.forceActiveFocus();
                } else if (root.isCompact && newHabitInput1x2) {
                    newHabitInput1x2.forceActiveFocus();
                } else if (newHabitInput2x2) {
                    newHabitInput2x2.forceActiveFocus();
                }
            });
        }
    }

    Component.onDestruction: {
        if (root.isAddingHabit) {
            GlobalStates.desktopWidgetKeyboardFocus = false;
        }
    }

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
        const dayNames = ["S", "M", "T", "W", "T", "F", "S"];
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
        let hist = Object.assign({}, h.history || {});

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
        let title = "";
        if (root.isWide && newHabitInputWide) {
            title = newHabitInputWide.text;
        } else if (root.isCompact && newHabitInput1x2) {
            title = newHabitInput1x2.text;
        } else if (newHabitInput2x2) {
            title = newHabitInput2x2.text;
        } else {
            title = root.newHabitTitle;
        }
        title = title.trim();
        if (title.length > 0) {
            root.addHabit(title);
        }
        if (newHabitInput1x2) newHabitInput1x2.text = "";
        if (newHabitInput2x2) newHabitInput2x2.text = "";
        if (newHabitInputWide) newHabitInputWide.text = "";
        root.newHabitTitle = "";
        root.isAddingHabit = false;
        Qt.callLater(() => {
            if (compactListView) compactListView.positionViewAtEnd();
            if (habitListView2x2) habitListView2x2.positionViewAtEnd();
            if (habitListViewWide) habitListViewWide.positionViewAtEnd();
        });
    }

    readonly property var defaultCategory: ({
        id: "general",
        icon: "checklist",
        color: Appearance.colors.colPrimary
    })

    readonly property var habitCategories: [
        {
            id: "water",
            icon: "water_drop",
            color: "#29b6f6",
            keywords: [
                "water", "drink", "hydrate", "hydration", "tea", "coffee",
                "nuoc", "uong", "tra", "cafe", "ca phe"
            ]
        },
        {
            id: "reading",
            icon: "menu_book",
            color: "#ab47bc",
            keywords: [
                "read", "reading", "book", "study", "learn", "exam", "paper", "research", "vocab",
                "doc", "sach", "hoc", "bai", "tieng anh", "tu vung", "on thi"
            ]
        },
        {
            id: "fitness",
            icon: "fitness_center",
            color: "#66bb6a",
            keywords: [
                "exercise", "workout", "gym", "stretch", "fitness", "cardio", "hiit", "yoga",
                "pushup", "squat", "plank", "pullup", "run", "running", "walk", "walking", "jog",
                "swim", "swimming", "cycling", "bike", "sport",
                "the duc", "tap", "the thao", "chay", "di bo", "hit dat", "boi", "dap xe"
            ]
        },
        {
            id: "coding",
            icon: "terminal",
            color: "#ffa726",
            keywords: [
                "code", "coding", "dev", "program", "terminal", "git", "commit", "debug", "build",
                "linux", "pr", "leetcode", "algorithm", "script",
                "lap trinh", "viet code", "thuat toan"
            ]
        },
        {
            id: "chores",
            icon: "cleaning_services",
            color: "#00bcd4",
            keywords: [
                "clean", "cleaning", "tidy", "wash", "washing", "dish", "dishes", "laundry", "shower", "teeth",
                "room", "house",
                "don", "don dep", "rua", "rua bat", "giat", "giat do", "tam", "danh rang", "phong", "nha cua"
            ]
        },
        {
            id: "mindfulness",
            icon: "self_improvement",
            color: "#26a69a",
            keywords: [
                "meditat", "mindful", "breathe", "breathing", "relax", "calm", "journal", "journaling",
                "gratitude", "peace", "prayer",
                "thien", "tho", "hit tho", "thu gian", "nhat ky", "biet on", "tinh tam"
            ]
        },
        {
            id: "sleep",
            icon: "bedtime",
            color: "#5c6bc0",
            keywords: [
                "sleep", "bed", "bedtime", "wake", "nap", "morning", "night", "early",
                "ngu", "day som", "ngu som", "thuc day", "buoi sang", "buoi toi"
            ]
        },
        {
            id: "nutrition",
            icon: "restaurant",
            color: "#8bc34a",
            keywords: [
                "eat", "eating", "food", "diet", "meal", "cook", "cooking", "breakfast", "lunch", "dinner",
                "vitamin", "pill", "medicine", "fruit", "veggie", "vegetable", "healthy",
                "an", "an uong", "an kieng", "nau", "nau an", "thuoc", "uong thuoc", "trai cay", "rau"
            ]
        },
        {
            id: "finance",
            icon: "account_balance_wallet",
            color: "#4caf50",
            keywords: [
                "money", "save", "saving", "finance", "budget", "spend", "invest", "investing",
                "tien", "tiet kiem", "tai chinh", "chi tieu", "ngan sach", "dau tu"
            ]
        },
        {
            id: "creative",
            icon: "brush",
            color: "#ec407a",
            keywords: [
                "write", "writing", "draw", "drawing", "paint", "painting", "art", "music", "guitar", "piano",
                "sing", "design", "sketch",
                "viet", "ve", "ve tranh", "nhac", "dan", "hat", "thiet ke"
            ]
        },
        {
            id: "social",
            icon: "favorite",
            color: "#e91e63",
            keywords: [
                "call", "family", "friend", "friends", "parent", "parents", "love", "meet", "chat",
                "goi dien", "gia dinh", "ban be", "bo me", "nguoi yeu", "gap go", "tro chuyen"
            ]
        },
        {
            id: "productivity",
            icon: "psychology",
            color: "#ff7043",
            keywords: [
                "focus", "work", "deep work", "pomodoro", "task", "todo", "project", "plan", "planning",
                "organize", "deadline", "goal",
                "tap trung", "lam viec", "ke hoach", "muc tieu"
            ]
        }
    ]

    function getCategoryForTitle(title) {
        if (!title || typeof title !== "string") return root.defaultCategory;
        const norm = title.toLowerCase()
            .normalize("NFD")
            .replace(/[\u0300-\u036f]/g, "")
            .replace(/đ/g, "d")
            .replace(/Đ/g, "d");

        const words = norm.split(/[\s,._\-+/&0-9]+/).filter(w => w.length > 0);

        for (let i = 0; i < root.habitCategories.length; i++) {
            const cat = root.habitCategories[i];
            for (let k = 0; k < cat.keywords.length; k++) {
                const kw = cat.keywords[k];
                if (kw.includes(" ")) {
                    if (norm.includes(kw)) return cat;
                } else {
                    for (let w = 0; w < words.length; w++) {
                        const word = words[w];
                        if (word === kw || (kw.length >= 4 && word.startsWith(kw))) {
                            return cat;
                        }
                    }
                }
            }
        }
        return root.defaultCategory;
    }

    function getHabitIcon(habit) {
        if (!habit) return root.defaultCategory.icon;
        if (habit.icon) return habit.icon;
        const cat = root.getCategoryForTitle(habit.title);
        return cat.icon;
    }

    function getHabitColor(habit) {
        if (!habit) return root.defaultCategory.color;
        if (habit.color) return habit.color;
        const cat = root.getCategoryForTitle(habit.title);
        return cat.color;
    }

    function addHabit(title) {
        if (!title || title.trim().length === 0) return;
        let list = habits.slice();
        const cat = root.getCategoryForTitle(title.trim());

        list.push({
            "id": "h_" + Date.now(),
            "title": title.trim(),
            "icon": cat.icon,
            "color": cat.color,
            "category": cat.id,
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
            if (habits[i] && habits[i].history && habits[i].history[todayDateStr]) {
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
                    root.habits = parsed.map(h => {
                        const cat = root.getCategoryForTitle(h.title);
                        return Object.assign({}, h, {
                            icon: cat.icon,
                            color: cat.color,
                            category: cat.id
                        });
                    });
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
        const defaultTitles = [
            Translation.tr("Drink 2L Water"),
            Translation.tr("Read 30 mins"),
            Translation.tr("Exercise & Stretch"),
            Translation.tr("Deep Work Focus")
        ];
        root.habits = defaultTitles.map((title, i) => {
            const cat = root.getCategoryForTitle(title);
            return {
                "id": "h_" + (i + 1),
                "title": title,
                "icon": cat.icon,
                "color": cat.color,
                "category": cat.id,
                "history": (i === 0 || i === 2) ? { [todayDateStr]: true } : {},
                "streak": (i === 0 || i === 2) ? 1 : 0
            };
        });
        saveHabits();
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

            // Compact Mode Layout (276 x 120 - Scrollable & Full Habit Support)
            ColumnLayout {
                visible: root.isCompact
                anchors { fill: parent; margins: 12 }
                spacing: 6

                // Top Header Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        spacing: 4
                        Layout.alignment: Qt.AlignVCenter
                        StyledText {
                            text: `${root.completedTodayCount}/${root.habits.length}`
                            font.pixelSize: 22
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        StyledText {
                            text: Translation.tr("done today")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.4)
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: 2
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Ratio Tag
                    Rectangle {
                        implicitWidth: ratioText.implicitWidth + 10
                        implicitHeight: 20
                        radius: 10
                        color: root.completionRatio >= 1.0 ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.75) : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.7)
                        border.width: 1
                        border.color: root.completionRatio >= 1.0 ? Appearance.colors.colPrimary : root.widgetBorderColor

                        StyledText {
                            id: ratioText
                            anchors.centerIn: parent
                            text: `${Math.round(root.completionRatio * 100)}%`
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Bold
                            color: root.completionRatio >= 1.0 ? Appearance.colors.colPrimary : Appearance.colors.colOnPrimaryContainer
                        }
                    }

                    // Navigation arrows (visible when > 4 habits)
                    RowLayout {
                        visible: root.habits.length > 4
                        spacing: 2

                        Rectangle {
                            width: 20; height: 20; radius: 10
                            color: leftMouse1x2.containsMouse ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.3) : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.75)
                            border.width: 1; border.color: root.widgetBorderColor
                            opacity: compactListView && compactListView.contentX > 2 ? 1.0 : 0.35

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "keyboard_arrow_left"
                                iconSize: 14
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                            MouseArea {
                                id: leftMouse1x2
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (compactListView) {
                                        compactScrollAnim.stop();
                                        compactScrollAnim.to = Math.max(0, compactListView.contentX - 78);
                                        compactScrollAnim.start();
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: 20; height: 20; radius: 10
                            color: rightMouse1x2.containsMouse ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.3) : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.75)
                            border.width: 1; border.color: root.widgetBorderColor
                            opacity: compactListView && (compactListView.contentX < compactListView.contentWidth - compactListView.width - 2) ? 1.0 : 0.35

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "keyboard_arrow_right"
                                iconSize: 14
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                            MouseArea {
                                id: rightMouse1x2
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (compactListView) {
                                        compactScrollAnim.stop();
                                        compactScrollAnim.to = Math.min(compactListView.contentWidth - compactListView.width, compactListView.contentX + 78);
                                        compactScrollAnim.start();
                                    }
                                }
                            }
                        }
                    }

                    // Add Habit Toggle Button
                    Rectangle {
                        width: 20; height: 20; radius: 10
                        color: addMouse1x2.containsMouse ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.3) : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.75)
                        border.width: 1
                        border.color: root.widgetBorderColor

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: root.isAddingHabit ? "close" : "add"
                            iconSize: 13
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        MouseArea {
                            id: addMouse1x2
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.isAddingHabit = !root.isAddingHabit;
                            }
                        }
                    }
                }

                // Progress Bar
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 5
                    radius: 2.5
                    color: Qt.rgba(1, 1, 1, 0.12)

                    Rectangle {
                        width: parent.width * root.completionRatio
                        height: parent.height
                        radius: 2.5
                        color: Appearance.colors.colPrimary
                    }
                }

                // Inline Add Habit Input Box in Compact Mode
                Rectangle {
                    visible: root.isAddingHabit
                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: Appearance.rounding.small
                    color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.6)
                    border.width: 1
                    border.color: Appearance.colors.colPrimary

                    RowLayout {
                        anchors { fill: parent; margins: 3; leftMargin: 8; rightMargin: 6 }
                        spacing: 4

                        TextField {
                            id: newHabitInput1x2
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: Appearance.colors.colOnPrimaryContainer
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            focus: root.isAddingHabit && root.isCompact
                            placeholderText: Translation.tr("New habit title...")
                            background: Item {}
                            padding: 0
                            onAccepted: root.submitNewHabit()
                            Keys.onEscapePressed: {
                                root.isAddingHabit = false;
                            }
                        }

                        Rectangle {
                            width: 20; height: 20; radius: 10
                            color: Appearance.colors.colPrimary
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "check"
                                iconSize: 13
                                color: Appearance.colors.colOnPrimary
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.submitNewHabit()
                            }
                        }
                    }
                }

                // Compact Habit Check Chips (Horizontal Scrollable ListView supporting unlimited habits)
                ListView {
                    id: compactListView
                    visible: !root.isAddingHabit
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    orientation: ListView.Horizontal
                    clip: true
                    spacing: 6
                    model: root.habits
                    boundsBehavior: Flickable.StopAtBounds

                    WheelHandler {
                        target: compactListView
                        orientation: Qt.Vertical | Qt.Horizontal
                        onWheel: (event) => {
                            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                            compactScrollAnim.stop();
                            compactListView.contentX = Math.max(0, Math.min(compactListView.contentWidth - compactListView.width, compactListView.contentX - delta));
                        }
                    }

                    NumberAnimation {
                        id: compactScrollAnim
                        target: compactListView
                        property: "contentX"
                        duration: 200
                        easing.type: Easing.OutCubic
                    }

                    delegate: Rectangle {
                        id: compactHabitBtn
                        required property var modelData
                        required property int index
                        width: root.habits.length <= 4 
                            ? Math.floor((compactListView.width - (root.habits.length - 1) * 6) / root.habits.length) 
                            : 72
                        height: compactListView.height
                        radius: Appearance.rounding.small
                        readonly property bool done: Boolean(modelData.history && modelData.history[root.todayDateStr])
                        color: done ? ColorUtils.transparentize(modelData.color || Appearance.colors.colPrimary, 0.25) : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                        border.width: 1
                        border.color: done ? (modelData.color || Appearance.colors.colPrimary) : root.widgetBorderColor

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 3

                            MaterialSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                text: compactHabitBtn.done ? "check" : (compactHabitBtn.modelData.icon || root.defaultCategory.icon)
                                iconSize: 15
                                color: compactHabitBtn.done ? Appearance.colors.colOnPrimary : (compactHabitBtn.modelData.color || root.defaultCategory.color)
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: compactHabitBtn.modelData.title || ""
                                elide: Text.ElideRight
                                Layout.maximumWidth: compactHabitBtn.width - 10
                                font.pixelSize: 10
                                font.weight: compactHabitBtn.done ? Font.Bold : Font.Normal
                                color: compactHabitBtn.done ? Appearance.colors.colOnPrimary : Appearance.colors.colOnPrimaryContainer
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleHabit(compactHabitBtn.index, root.todayDateStr)
                        }
                    }
                }
            }

            // Standard 2x2 Mode Layout (276 x 252 - Scrollable & Full Habit Support)
            ColumnLayout {
                visible: !root.isCompact && !root.isWide
                anchors { fill: parent; margins: 12 }
                spacing: 6

                // Top Header Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        spacing: 4
                        Layout.alignment: Qt.AlignVCenter
                        StyledText {
                            text: `${root.completedTodayCount}/${root.habits.length}`
                            font.pixelSize: 22
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        StyledText {
                            text: Translation.tr("done")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.DemiBold
                            color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.35)
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: 2
                        }
                        Rectangle {
                            implicitWidth: pctBadge2x2.implicitWidth + 8
                            implicitHeight: 18
                            radius: 9
                            color: root.completionRatio >= 1.0 
                                ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.75)
                                : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.7)
                            border.width: 1
                            border.color: root.completionRatio >= 1.0 
                                ? Appearance.colors.colPrimary 
                                : root.widgetBorderColor

                            StyledText {
                                id: pctBadge2x2
                                anchors.centerIn: parent
                                text: `${Math.round(root.completionRatio * 100)}%`
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: root.completionRatio >= 1.0 
                                    ? Appearance.colors.colPrimary 
                                    : Appearance.colors.colOnPrimaryContainer
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Page Navigation Buttons (visible when > 4 habits)
                    RowLayout {
                        visible: root.habits.length > 4
                        spacing: 2

                        Rectangle {
                            width: 20; height: 20; radius: 10
                            color: upMouse2x2.containsMouse ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.3) : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.75)
                            border.width: 1; border.color: root.widgetBorderColor
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "keyboard_arrow_up"
                                iconSize: 14
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                            MouseArea {
                                id: upMouse2x2
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (habitListView2x2) habitListView2x2.contentY = Math.max(0, habitListView2x2.contentY - (34 * 3));
                                }
                            }
                        }

                        Rectangle {
                            width: 20; height: 20; radius: 10
                            color: downMouse2x2.containsMouse ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.3) : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.75)
                            border.width: 1; border.color: root.widgetBorderColor
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "keyboard_arrow_down"
                                iconSize: 14
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                            MouseArea {
                                id: downMouse2x2
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (habitListView2x2) habitListView2x2.contentY = Math.min(habitListView2x2.contentHeight - habitListView2x2.height, habitListView2x2.contentY + (34 * 3));
                                }
                            }
                        }
                    }

                    // Add Habit Toggle Button
                    Rectangle {
                        width: 24; height: 24; radius: 12
                        color: addMouse2x2.containsMouse ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.3) : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.75)
                        border.width: 1
                        border.color: root.widgetBorderColor

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: root.isAddingHabit ? "close" : "add"
                            iconSize: 15
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        MouseArea {
                            id: addMouse2x2
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.isAddingHabit = !root.isAddingHabit;
                            }
                        }
                    }
                }

                // Inline Add Habit Input Box
                Rectangle {
                    visible: root.isAddingHabit
                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: Appearance.rounding.small
                    color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.6)
                    border.width: 1
                    border.color: Appearance.colors.colPrimary

                    RowLayout {
                        anchors { fill: parent; margins: 3; leftMargin: 8; rightMargin: 6 }
                        spacing: 4

                        TextField {
                            id: newHabitInput2x2
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: Appearance.colors.colOnPrimaryContainer
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            focus: root.isAddingHabit && !root.isWide
                            placeholderText: Translation.tr("New habit title...")
                            background: Item {}
                            padding: 0
                            onAccepted: root.submitNewHabit()
                            Keys.onEscapePressed: {
                                root.isAddingHabit = false;
                            }
                        }

                        Rectangle {
                            width: 20; height: 20; radius: 10
                            color: Appearance.colors.colPrimary
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "check"
                                iconSize: 13
                                color: Appearance.colors.colOnPrimary
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.submitNewHabit()
                            }
                        }
                    }
                }

                // Weekday Column Headers
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        text: Translation.tr("ROUTINES")
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.5)
                    }

                    Item { Layout.fillWidth: true }

                    // 7 Day Labels
                    Row {
                        spacing: 3
                        Repeater {
                            model: root.weekDays
                            delegate: Item {
                                required property var modelData
                                width: 16
                                height: 14

                                StyledText {
                                    anchors.centerIn: parent
                                    text: parent.modelData.label
                                    font.pixelSize: 9
                                    font.weight: parent.modelData.isToday ? Font.Bold : Font.Normal
                                    color: parent.modelData.isToday ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.45)
                                }
                            }
                        }
                    }
                }

                // Scrollable Habit Rows ListView (Supports unlimited habits)
                StyledListView {
                    id: habitListView2x2
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 4
                    model: root.habits

                    delegate: Rectangle {
                        id: habitRow2x2
                        required property var modelData
                        required property int index
                        width: habitListView2x2.width
                        height: 30
                        radius: Appearance.rounding.small
                        color: rowHover2x2.hovered ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.8) : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                        border.width: 1
                        border.color: rowHover2x2.hovered ? Appearance.colors.colPrimary : root.widgetBorderColor

                        HoverHandler { id: rowHover2x2 }

                        RowLayout {
                            anchors { fill: parent; margins: 3; leftMargin: 8; rightMargin: 6 }
                            spacing: 6

                            // Habit Category Icon & Title
                            MaterialSymbol {
                                text: habitRow2x2.modelData.icon || root.defaultCategory.icon
                                iconSize: 14
                                color: habitRow2x2.modelData.color || root.defaultCategory.color
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: habitRow2x2.modelData.title || ""
                                elide: Text.ElideRight
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnPrimaryContainer
                            }

                            // Delete button on Hover
                            Rectangle {
                                width: 18; height: 18; radius: 9
                                visible: rowHover2x2.hovered
                                color: delMouse2x2.containsMouse ? Qt.rgba(1, 0.2, 0.2, 0.25) : "transparent"
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "delete"
                                    iconSize: 12
                                    color: delMouse2x2.containsMouse ? "#ef5350" : Appearance.colors.colOnPrimaryContainer
                                }
                                MouseArea {
                                    id: delMouse2x2
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.deleteHabit(habitRow2x2.index)
                                }
                            }

                            // 7 Day Checkboxes
                            Row {
                                spacing: 3

                                Repeater {
                                    model: root.weekDays
                                    delegate: Rectangle {
                                        id: checkBtn2x2
                                        required property var modelData
                                        width: 16
                                        height: 16
                                        radius: 8

                                        readonly property bool isChecked: (habitRow2x2.modelData.history && habitRow2x2.modelData.history[checkBtn2x2.modelData.dateStr]) === true
                                        readonly property bool isToday: checkBtn2x2.modelData.isToday

                                        color: isChecked 
                                            ? (habitRow2x2.modelData.color || Appearance.colors.colPrimary)
                                            : (isToday ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.8) : Qt.rgba(1, 1, 1, 0.08))
                                        border.width: isToday ? 1.5 : 0
                                        border.color: Appearance.colors.colPrimary

                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            visible: checkBtn2x2.isChecked
                                            text: "check"
                                            iconSize: 11
                                            color: Appearance.colors.colOnPrimary
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.toggleHabit(habitRow2x2.index, checkBtn2x2.modelData.dateStr)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Wide Modes Layout: 4x2 & 2x3 (Scrollable & Full Habit Support)
            ColumnLayout {
                visible: root.isWide
                anchors { fill: parent; margins: 14 }
                spacing: 6

                // Top Header Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    RowLayout {
                        spacing: 6
                        Layout.alignment: Qt.AlignVCenter
                        StyledText {
                            text: `${root.completedTodayCount}/${root.habits.length}`
                            font.pixelSize: 24
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        StyledText {
                            text: Translation.tr("done today")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.DemiBold
                            color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.35)
                        }
                        Rectangle {
                            implicitWidth: pctBadgeWide.implicitWidth + 8
                            implicitHeight: 18
                            radius: 9
                            color: root.completionRatio >= 1.0 
                                ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.75)
                                : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.7)
                            border.width: 1
                            border.color: root.completionRatio >= 1.0 
                                ? Appearance.colors.colPrimary 
                                : root.widgetBorderColor

                            StyledText {
                                id: pctBadgeWide
                                anchors.centerIn: parent
                                text: `${Math.round(root.completionRatio * 100)}%`
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: root.completionRatio >= 1.0 
                                    ? Appearance.colors.colPrimary 
                                    : Appearance.colors.colOnPrimaryContainer
                            }
                        }
                    }

                    // Horizontal Progress Bar in Wide Mode
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 160
                        implicitHeight: 6
                        radius: 3
                        color: Qt.rgba(1, 1, 1, 0.12)

                        Rectangle {
                            width: parent.width * root.completionRatio
                            height: parent.height
                            radius: 3
                            color: Appearance.colors.colPrimary
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Page Navigation Buttons (visible when > 4 habits)
                    RowLayout {
                        visible: root.habits.length > 4
                        spacing: 2

                        Rectangle {
                            width: 22; height: 22; radius: 11
                            color: upMouseWide.containsMouse ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.3) : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.75)
                            border.width: 1; border.color: root.widgetBorderColor
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "keyboard_arrow_up"
                                iconSize: 15
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                            MouseArea {
                                id: upMouseWide
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (habitListViewWide) habitListViewWide.contentY = Math.max(0, habitListViewWide.contentY - (36 * 3));
                                }
                            }
                        }

                        Rectangle {
                            width: 22; height: 22; radius: 11
                            color: downMouseWide.containsMouse ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.3) : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.75)
                            border.width: 1; border.color: root.widgetBorderColor
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "keyboard_arrow_down"
                                iconSize: 15
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                            MouseArea {
                                id: downMouseWide
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (habitListViewWide) habitListViewWide.contentY = Math.min(habitListViewWide.contentHeight - habitListViewWide.height, habitListViewWide.contentY + (36 * 3));
                                }
                            }
                        }
                    }

                    // Add Habit Toggle Button
                    Rectangle {
                        width: 26; height: 26; radius: 13
                        color: addMouseWide.containsMouse ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.3) : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.75)
                        border.width: 1
                        border.color: root.widgetBorderColor

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: root.isAddingHabit ? "close" : "add"
                            iconSize: 16
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        MouseArea {
                            id: addMouseWide
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.isAddingHabit = !root.isAddingHabit;
                            }
                        }
                    }
                }

                // Inline Add Habit Input Box
                Rectangle {
                    visible: root.isAddingHabit
                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: Appearance.rounding.small
                    color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.6)
                    border.width: 1
                    border.color: Appearance.colors.colPrimary

                    RowLayout {
                        anchors { fill: parent; margins: 3; leftMargin: 8; rightMargin: 6 }
                        spacing: 4

                        TextField {
                            id: newHabitInputWide
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: Appearance.colors.colOnPrimaryContainer
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            focus: root.isAddingHabit && root.isWide
                            placeholderText: Translation.tr("New habit title...")
                            background: Item {}
                            padding: 0
                            onAccepted: root.submitNewHabit()
                            Keys.onEscapePressed: {
                                root.isAddingHabit = false;
                            }
                        }

                        Rectangle {
                            width: 22; height: 22; radius: 11
                            color: Appearance.colors.colPrimary
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "check"
                                iconSize: 14
                                color: Appearance.colors.colOnPrimary
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.submitNewHabit()
                            }
                        }
                    }
                }

                // Weekday Column Header Alignment
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        text: Translation.tr("ROUTINES")
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.45)
                    }

                    Item { Layout.fillWidth: true }

                    // 7 Day Labels
                    Row {
                        spacing: root.sizeMode === "4x2" ? 6 : 4
                        Repeater {
                            model: root.weekDays
                            delegate: Item {
                                required property var modelData
                                width: root.sizeMode === "4x2" ? 22 : 18
                                height: 14

                                StyledText {
                                    anchors.centerIn: parent
                                    text: parent.modelData.label
                                    font.pixelSize: 10
                                    font.weight: parent.modelData.isToday ? Font.Bold : Font.Normal
                                    color: parent.modelData.isToday ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.45)
                                }
                            }
                        }
                    }
                }

                // Scrollable Habit Rows ListView (Supports unlimited habits)
                StyledListView {
                    id: habitListViewWide
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 4
                    model: root.habits

                    delegate: Rectangle {
                        id: habitRowWide
                        required property var modelData
                        required property int index
                        width: habitListViewWide.width
                        height: 34
                        radius: Appearance.rounding.small
                        color: rowHoverWide.hovered ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.8) : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.78)
                        border.width: 1
                        border.color: rowHoverWide.hovered ? Appearance.colors.colPrimary : root.widgetBorderColor

                        HoverHandler { id: rowHoverWide }

                        RowLayout {
                            anchors { fill: parent; margins: 4; leftMargin: 10; rightMargin: 8 }
                            spacing: 8

                            // Habit Category Icon & Title
                            MaterialSymbol {
                                text: habitRowWide.modelData.icon || root.defaultCategory.icon
                                iconSize: 15
                                color: habitRowWide.modelData.color || root.defaultCategory.color
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: habitRowWide.modelData.title || ""
                                elide: Text.ElideRight
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnPrimaryContainer
                            }

                            // Streak Pill
                            RowLayout {
                                visible: (habitRowWide.modelData.streak || 0) > 0
                                spacing: 2
                                MaterialSymbol {
                                    text: "local_fire_department"
                                    iconSize: 13
                                    color: "#ff7043"
                                }
                                StyledText {
                                    text: `${habitRowWide.modelData.streak}d`
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: "#ff7043"
                                }
                            }

                            // Delete Button on Hover
                            Rectangle {
                                width: 20; height: 20; radius: 10
                                visible: rowHoverWide.hovered
                                color: delMouseWide.containsMouse ? Qt.rgba(1, 0.2, 0.2, 0.25) : "transparent"
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "delete"
                                    iconSize: 13
                                    color: delMouseWide.containsMouse ? "#ef5350" : Appearance.colors.colOnPrimaryContainer
                                }
                                MouseArea {
                                    id: delMouseWide
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.deleteHabit(habitRowWide.index)
                                }
                            }

                            // 7 Day Checkboxes
                            Row {
                                spacing: root.sizeMode === "4x2" ? 6 : 4

                                Repeater {
                                    model: root.weekDays
                                    delegate: Rectangle {
                                        id: checkBtnWide
                                        required property var modelData
                                        width: root.sizeMode === "4x2" ? 22 : 18
                                        height: width
                                        radius: width / 2

                                        readonly property bool isChecked: (habitRowWide.modelData.history && habitRowWide.modelData.history[checkBtnWide.modelData.dateStr]) === true
                                        readonly property bool isToday: checkBtnWide.modelData.isToday

                                        color: isChecked 
                                            ? (habitRowWide.modelData.color || Appearance.colors.colPrimary)
                                            : (isToday ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.8) : Qt.rgba(1, 1, 1, 0.08))
                                        border.width: isToday ? 1.5 : 0
                                        border.color: Appearance.colors.colPrimary

                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            visible: checkBtnWide.isChecked
                                            text: "check"
                                            iconSize: checkBtnWide.width - 5
                                            color: Appearance.colors.colOnPrimary
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.toggleHabit(habitRowWide.index, checkBtnWide.modelData.dateStr)
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
