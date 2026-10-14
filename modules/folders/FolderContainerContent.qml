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
    property real pointerX: width / 2
    property real pointerY: height / 2
    property bool blurAvailable: false
    property bool reducedMotion: false
    readonly property bool motionEnabled: !reducedMotion && Kirigami.Units.longDuration > 1
    readonly property real tailExtent: Kirigami.Units.largeSpacing
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
    readonly property real chromeHeight: header.implicitHeight + inset * 2 + Kirigami.Units.largeSpacing
        + (viewMode === "grid" ? 0 : locationAction.implicitHeight)
    implicitWidth: Math.min(maximumWidth, Math.max(Kirigami.Units.gridUnit * 16, viewMode === "grid"
        ? columns * cellWidth + inset * 2 : Kirigami.Units.gridUnit * 24))
    implicitHeight: Math.min(maximumHeight, chromeHeight + Math.max(cellHeight, rowsHeight))
    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    function focusFirst(): void {
        if (!root || !grid || !list || !back) return
        const view = viewMode === "grid" ? grid : list
        if (view.currentItem) view.currentItem.forceActiveFocus(Qt.PopupFocusReason)
        else back.forceActiveFocus(Qt.PopupFocusReason)
    }
    function restoreView(): void {
        if (!controller || !controller.contents || controller.contents.loading) return
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
    BalloonSurface {
        anchors.fill: parent
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
        anchors.margins: root.inset
        spacing: Kirigami.Units.largeSpacing
        Item {
            id: header
            Layout.fillWidth: true
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
            // The layout must reserve room for the grid, otherwise the popup
            // collapses to its header and no entry can be seen.
            Layout.preferredHeight: Math.max(root.cellHeight, Math.min(root.rowsHeight,
                root.maximumHeight - root.chromeHeight))
            Label {
                anchors.centerIn: parent
                visible: root.controller.contents.loading || root.controller.contents.error.length > 0
                    || (root.controller.contents.count === 0 && root.viewMode !== "grid")
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
                visible: root.viewMode !== "grid" && !root.controller.contents.loading && root.controller.contents.error.length === 0
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
        }
        Button {
            id: locationAction
            objectName: "folderOpenLocation"
            visible: root.viewMode !== "grid"
            text: qsTr("Open in File Manager"); icon.name: "folder-open"
            Layout.alignment: Qt.AlignRight
            onClicked: root.controller.openLocation()
        }
    }
}
