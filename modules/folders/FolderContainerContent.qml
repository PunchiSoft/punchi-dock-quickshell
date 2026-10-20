// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Punchi.Kde as Native
import "../../components"

Item {
    id: root
    required property FolderNavigationController controller
    property string viewMode: "grid"
    property real maximumWidth: Kirigami.Units.gridUnit * 36
    property real maximumHeight: Kirigami.Units.gridUnit * 30
    property string tailEdge: "bottom"
    property string dockEdge: "bottom"
    // Whether the popup that hosts this content is on screen, so the fan can
    // unfold only when it is going to be seen.
    property bool surfaceVisible: true
    // Whether the container enters the subfolders it lists. The owner binds the
    // controller to this value; the arc never enters them, because it is a leaf
    // and opens a directory where it lives.
    property bool browseSubfolders: true
    Binding {
        target: root.controller
        property: "browseSubfolders"
        value: root.browseSubfolders
    }
    property real pointerX: width / 2
    property real pointerY: height / 2
    property bool blurAvailable: false
    property bool reducedMotion: false
    readonly property bool motionEnabled: !reducedMotion && Kirigami.Units.longDuration > 1
    readonly property bool fanMode: viewMode === "fan"
    readonly property real tailExtent: root.fanMode ? 0 : Kirigami.Units.largeSpacing
    readonly property real cornerRadius: Kirigami.Units.cornerRadius * 2
    signal closeRequested()
    signal viewRequested(string mode)
    property bool gridActionSelected: false
    property bool navigationFocusPending: false
    Native.FolderEntriesModel { id: gridEntries; contents: root.controller.contents }
    readonly property real inset: Kirigami.Units.largeSpacing * 2
    readonly property real gridIconSize: Kirigami.Units.gridUnit * 3
    readonly property real cellWidth: Kirigami.Units.gridUnit * 6.5
    readonly property real cellHeight: gridIconSize + Kirigami.Units.gridUnit * 3.25
    readonly property int maximumColumns: Math.max(1, Math.min(5, Math.floor((maximumWidth - inset * 2) / cellWidth)))
    readonly property int columns: Math.max(1, Math.min(maximumColumns,
        Math.ceil(Math.sqrt((controller.contents.count + 1) * 1.5))))
    readonly property real rowsHeight: viewMode === "grid"
        ? Math.ceil((controller.contents.count + 1) / columns) * cellHeight
        : controller.contents.count * rowHeight
    readonly property real rowHeight: Kirigami.Units.iconSizes.medium
        + Kirigami.Units.smallSpacing * 2 + (viewMode === "detail" ? Kirigami.Units.gridUnit : 0)
    readonly property real chromeHeight: root.fanMode ? 0
        : header.implicitHeight + inset * 2 + Kirigami.Units.largeSpacing
            + (viewMode === "grid" ? 0 : locationAction.implicitHeight)
    // Height the fan may use. The ceiling keeps a usability floor, so the arc
    // shows the rows that fit instead of asking for a surface taller than the
    // screen and having its far row cut.
    readonly property real fanMaximumContentHeight: Math.max(0,
        root.maximumHeight - root.chromeHeight)
    // Centre of the glyph on the row that faces the panel, in this item's
    // coordinates. The popup places itself from it, so the arc grows out of the
    // dock icon instead of out of the middle of an empty surface.
    readonly property real fanOriginIconCenterX: fan.baseIconX + fan.iconSize / 2
    readonly property real fanContentHeight: Math.max(0,
        Math.min(root.fanMaximumContentHeight, fan.implicitHeight))
    implicitWidth: root.fanMode
        ? Math.min(maximumWidth, fan.implicitWidth)
        : Math.min(maximumWidth, Math.max(Kirigami.Units.gridUnit * 16, viewMode === "grid"
            ? columns * cellWidth + inset * 2 : Kirigami.Units.gridUnit * 24))
    implicitHeight: root.fanMode
        ? Math.max(1, root.fanContentHeight)
        : Math.min(maximumHeight, chromeHeight + Math.max(cellHeight, rowsHeight))
    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    function focusFirst(): void {
        if (!root || !back) return
        if (root.fanMode) {
            fan.requestInitialFocus()
            return
        }
        if (!grid || !list) return
        const view = viewMode === "grid" ? grid : list
        if (view.currentItem) view.currentItem.forceActiveFocus(Qt.PopupFocusReason)
        else back.forceActiveFocus(Qt.PopupFocusReason)
    }
    function restoreView(): void {
        if (!controller || !controller.contents || controller.contents.loading) return
        if (root.fanMode) {
            navigationFocusPending = false
            fan.requestInitialFocus()
            return
        }
        const view = viewMode === "grid" ? grid : list
        view.contentY = Math.max(0, Math.min(root.controller.scrollPosition, Math.max(0, view.contentHeight - view.height)))
        const restoreFocus = navigationFocusPending
        navigationFocusPending = false
        Qt.callLater(function() {
            if (!root || !back) return
            if (restoreFocus || !back.activeFocus) root.focusFirst()
        })
    }
    function requestInitialFocus(): void {
        gridActionSelected = false
        navigationFocusPending = true
        Qt.callLater(root.restoreView)
    }
    function selectGrid(index: int): void {
        gridActionSelected = index === controller.contents.count
        if (!gridActionSelected) controller.select(index)
        Qt.callLater(root.focusFirst)
    }
    function selectRow(index: int): void { controller.select(index); Qt.callLater(root.focusFirst) }
    onViewModeChanged: Qt.callLater(root.focusFirst)
    Connections { target: root.controller; function onRestoreRequested() { root.requestInitialFocus() } }
    Connections { target: root.controller.contents; function onStateChanged() { if (!root.controller.contents.loading) Qt.callLater(root.restoreView) } }
    // The fan has no surface of its own: the rows float over the desktop and
    // only their pills and glyphs paint, like the reference stacks. The balloon
    // stays for the flat presentations.
    BalloonSurface {
        anchors.fill: parent
        visible: !root.fanMode
        objectName: "folderContainerSurface"
        tailEdge: root.tailEdge
        tailHeight: root.tailExtent
        tailBaseScale: 0.9
        tailTipRadius: Math.min(root.tailExtent * 0.22, Kirigami.Units.smallSpacing * 0.65)
        cornerRadius: root.cornerRadius
        fillColor: Qt.alpha(Kirigami.Theme.backgroundColor, root.blurAvailable ? 0.80 : 0.96)
        pointerX: root.pointerX; pointerY: root.pointerY
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.fanMode ? 0 : root.inset
        spacing: Kirigami.Units.largeSpacing
        Item {
            id: header
            Layout.fillWidth: true
            // The arc has no card to carry a title or a close control: it is
            // dismissed by clicking outside, with Escape or by its own rows.
            visible: !root.fanMode
            implicitHeight: Math.max(back.implicitHeight, closeButton.implicitHeight)
            ToolButton {
                id: back
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                objectName: "folderBack"
                text: qsTr("Back"); icon.name: "go-previous"
                display: AbstractButton.IconOnly
                visible: root.controller.canGoBack
                enabled: visible
                Accessible.name: text
                onClicked: root.controller.back()
            }
            FolderPopupShadowLabel {
                anchors.centerIn: parent
                objectName: "folderPopupTitle"
                width: Math.max(0, header.width - (back.visible ? back.width : 0)
                    - closeButton.width - Kirigami.Units.largeSpacing * 2)
                text: root.controller.title
                textFormat: Text.PlainText
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle
                font.weight: Font.DemiBold
                font.pointSize: Kirigami.Theme.defaultFont.pointSize + 2
            }
            ToolButton {
                id: closeButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                objectName: "folderClose"
                width: Kirigami.Units.gridUnit * 1.5
                height: width
                padding: 0
                Accessible.name: qsTr("Close")
                background: Rectangle {
                    anchors.centerIn: parent
                    width: Kirigami.Units.gridUnit * 0.75
                    height: width
                    radius: width / 2
                    color: Kirigami.Theme.negativeTextColor
                }
                onClicked: root.closeRequested()
            }
        }
        Item {
            id: rows
            objectName: "folderEntriesViewport"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            // The layout must reserve room for the presentation, otherwise the
            // popup collapses to its header and no entry can be seen.
            Layout.preferredHeight: root.fanMode
                ? Math.max(1, root.fanContentHeight)
                : Math.max(root.cellHeight, Math.min(root.rowsHeight,
                    root.maximumHeight - root.chromeHeight))
            Label {
                anchors.centerIn: parent
                visible: root.controller.contents.loading || root.controller.contents.error.length > 0
                    || (root.controller.contents.count === 0 && root.viewMode !== "grid"
                        && !root.fanMode)
                text: root.controller.contents.error || (root.controller.contents.loading ? qsTr("Loading") : qsTr("Empty"))
                textFormat: Text.PlainText
                width: parent.width
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
            }
            GridView {
                id: grid
                objectName: "folderGrid"
                anchors.fill: parent
                visible: root.viewMode === "grid" && !root.controller.contents.loading && root.controller.contents.error.length === 0
                clip: true; boundsBehavior: Flickable.StopAtBounds
                cellWidth: width / root.columns
                cellHeight: root.cellHeight
                model: gridEntries
                currentIndex: root.gridActionSelected || root.controller.contents.count === 0
                    ? root.controller.contents.count : root.controller.selectedIndex
                onContentYChanged: if (moving) root.controller.scrollPosition = contentY
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: FolderEntryButton {
                    id: gridEntry
                    required property int index
                    required entryName
                    required entryIcon
                    required locationAction
                    objectName: "folderGridEntry-" + index
                    width: grid.cellWidth; height: grid.cellHeight
                    grid: true
                    gridIconSize: root.gridIconSize
                    motionEnabled: root.motionEnabled
                    highlighted: GridView.isCurrentItem
                    onClicked: {
                        if (gridEntry.locationAction) root.controller.openLocation()
                        else { root.controller.select(index); root.controller.activate(index) }
                    }
                    Keys.onLeftPressed: root.selectGrid(Math.max(0, index - 1))
                    Keys.onRightPressed: root.selectGrid(Math.min(grid.count - 1, index + 1))
                    Keys.onUpPressed: root.selectGrid(Math.max(0, index - root.columns))
                    Keys.onDownPressed: root.selectGrid(Math.min(grid.count - 1, index + root.columns))
                }
                onCurrentIndexChanged: { positionViewAtIndex(currentIndex, GridView.Contain); if (activeFocus) Qt.callLater(root.focusFirst) }
            }
            ListView {
                id: list
                objectName: "folderList"
                anchors.fill: parent
                visible: (root.viewMode === "list" || root.viewMode === "detail")
                    && !root.controller.contents.loading
                    && root.controller.contents.error.length === 0
                clip: true; boundsBehavior: Flickable.StopAtBounds
                model: root.controller.contents
                currentIndex: root.controller.selectedIndex
                onContentYChanged: if (moving) root.controller.scrollPosition = contentY
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: FolderEntryButton {
                    required property int index
                    required entryName
                    required entryIcon
                    required description
                    objectName: "folderListEntry-" + index
                    width: list.width; height: root.rowHeight
                    grid: false; detailed: root.viewMode === "detail"
                    gridIconSize: root.gridIconSize
                    motionEnabled: root.motionEnabled
                    highlighted: ListView.isCurrentItem
                    onClicked: { root.controller.select(index); root.controller.activate(index) }
                    Keys.onUpPressed: root.selectRow(Math.max(0, index - 1))
                    Keys.onDownPressed: root.selectRow(Math.min(list.count - 1, index + 1))
                }
                onCurrentIndexChanged: { positionViewAtIndex(currentIndex, ListView.Contain); if (activeFocus) Qt.callLater(root.focusFirst) }
            }
            FolderFanView {
                id: fan
                objectName: "folderFanView"
                anchors.fill: parent
                visible: root.fanMode && !root.controller.contents.loading
                    && root.controller.contents.error.length === 0
                contents: root.controller.contents
                dockEdge: root.dockEdge
                iconSize: Math.round(root.gridIconSize)
                rowLimit: 6
                maximumContentHeight: root.fanMaximumContentHeight
                showLabels: true
                fontFamily: Kirigami.Theme.defaultFont.family
                fontSize: Kirigami.Theme.defaultFont.pointSize
                motionEnabled: root.motionEnabled
                opened: root.surfaceVisible
                onActivateRequested: function(index) {
                    root.controller.select(index)
                    root.controller.openEntry(index)
                }
                onOpenLocationRequested: root.controller.openLocation()
                onCloseRequested: root.closeRequested()
            }
        }
        Button {
            id: locationAction
            objectName: "folderOpenLocation"
            visible: root.viewMode === "list" || root.viewMode === "detail"
            text: qsTr("Open in File Manager"); icon.name: "folder-open"
            Layout.alignment: Qt.AlignRight
            onClicked: root.controller.openLocation()
        }
    }
}
