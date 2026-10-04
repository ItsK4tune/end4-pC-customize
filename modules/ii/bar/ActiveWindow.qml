import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import QtQuick.Controls
import Quickshell.Wayland
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects

Item {
    id: root
    property color contentColor: Appearance.colors.colOnLayer0
    property bool contentColorOverridden: false
    property bool vertical: false
    readonly property var monitor: WM.monitorFor(root.QsWindow.window?.screen)
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
    property string activeWindowAddress: activeWindow?.HyprlandToplevel?.address ? `0x${activeWindow.HyprlandToplevel.address}` : ""
    property bool focusingThisMonitor: WM.focusedMonitor?.name === monitor?.name
    property var biggestWindow: WM.biggestWindowForWorkspace(WM.activeWorkspaceForMonitor(monitor?.name)?.id ?? 1)

    property string activeAppClass: {
        if (!root.focusingThisMonitor || !root.activeWindow?.activated)
            return root.biggestWindow?.class ?? ""
        return root.activeWindow?.appId ?? root.biggestWindow?.class ?? ""
    }

    property var mainAppIconSource: {
        if (!root.activeAppClass || root.activeAppClass === "")
            return SystemAppearance.iconPath("user-desktop", "image-missing")
        return SystemAppearance.iconPath(AppSearch.guessIcon(root.activeAppClass), 
            SystemAppearance.iconPath("user-desktop", "image-missing"))     // ← fallback Desktop
    }



    readonly property bool isMaterial: Config.options.bar.cornerStyle === 3
    property real maxBottomHeight: root.isMaterial ? 16 : 18
    property int maxTitleFontSize: 13
    property int minTitleFontSize: 7
    property int titleFontSize: root.maxTitleFontSize

    readonly property string displayTitleText: {
        if (root.focusingThisMonitor && root.activeWindow?.activated && root.biggestWindow) {
            return root.activeWindow?.title ?? "";
        }
        return root.biggestWindow?.title ?? `${Translation.tr("Workspace")} ${WM.activeWorkspaceForMonitor(monitor?.name)?.id ?? 1}`;
    }

    readonly property string displayAppText: {
        if (root.focusingThisMonitor && root.activeWindow?.activated && root.biggestWindow) {
            return root.activeWindow?.appId ?? "";
        }
        return root.biggestWindow?.class ?? Translation.tr("Desktop");
    }

    Text {
        id: measurer
        visible: false
        font.family: Appearance.font.family.main
        font.hintingPreference: Font.PreferDefaultHinting
        renderType: Text.NativeRendering
    }

    function updateTitleFontSize() {
        const textToMeasure = root.displayTitleText;
        if (!textToMeasure || textToMeasure.length === 0) {
            root.titleFontSize = root.maxTitleFontSize;
            return;
        }

        measurer.text = textToMeasure;
        for (let sz = root.maxTitleFontSize; sz >= root.minTitleFontSize; sz--) {
            measurer.font.pixelSize = sz;
            if (measurer.contentHeight <= root.maxBottomHeight) {
                root.titleFontSize = sz;
                return;
            }
        }
        root.titleFontSize = root.minTitleFontSize;
    }

    onDisplayTitleTextChanged: updateTitleFontSize()
    onMaxBottomHeightChanged: updateTitleFontSize()
    Component.onCompleted: updateTitleFontSize()

    implicitWidth:  vertical ? Appearance.sizes.verticalBarWidth : Math.min(colLayout.implicitWidth + 12, 280)
    implicitHeight: vertical ? iconItem.implicitHeight : (root.isMaterial ? 32 : Appearance.sizes.barHeight)

    // Vertical
    Item {
        id: iconItem
        visible: root.vertical
        anchors.centerIn: parent
        implicitWidth: 22
        implicitHeight: 22

        IconImage {
            anchors.centerIn: parent
            source: root.mainAppIconSource
            implicitSize: 18
            visible: root.mainAppIconSource !== ""
        }
    }

    // Horizontal
    ColumnLayout {
        id: colLayout
        visible: !root.vertical
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        spacing: 0
        clip: true

        StyledText {
            Layout.fillWidth: true
            Layout.maximumHeight: 12
            verticalAlignment: Text.AlignVCenter
            clip: true
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: root.contentColorOverridden ? Qt.alpha(root.contentColor, 0.7) : Appearance.colors.colSubtext
            elide: Text.ElideRight
            text: root.displayAppText
        }
        StyledText {
            Layout.fillWidth: true
            Layout.maximumHeight: root.maxBottomHeight
            Layout.preferredHeight: Math.min(contentHeight, root.maxBottomHeight)
            verticalAlignment: Text.AlignVCenter
            clip: true
            font.pixelSize: root.titleFontSize
            color: root.contentColor
            elide: Text.ElideRight
            text: root.displayTitleText
        }
    }
}
