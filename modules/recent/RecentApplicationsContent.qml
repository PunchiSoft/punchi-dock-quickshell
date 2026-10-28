// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../components"
import "../../config"
import "../../components/EntryLayout.js" as EntryLayout

// The recent-applications container. It draws the selection the dock already
// filters with the shared container presentations, owns the surface and the one
// emphasis band, and reports an activation instead of launching by itself.
Item {
    id: root
    // RecentApplicationsModel: it publishes entryName and entryIcon, the roles
    // the shared Grid, List, Detail and Fan presentations consume.
    required property var selection
    property string viewMode: "list"
    property string title: ""
    property real maximumWidth: Kirigami.Units.gridUnit * 36
    property real maximumHeight: Kirigami.Units.gridUnit * 30
    // Presentation scale and one glyph per presentation, chosen in Settings.
    property real popupScale: 1
    property int popupIconSize: 0
    property int popupListIconSize: 0
    property int popupFanIconSize: 0
    property string tailEdge: "bottom"
    property string dockEdge: "bottom"
    // Whether the popup that hosts this content is on screen, so the fan can
    // unfold only when it is going to be seen.
    property bool surfaceVisible: true
    property real pointerX: width / 2
    property real pointerY: height / 2
    property bool blurAvailable: false
    property bool reducedMotion: false
    // Which emphasis the pointer owns. The owner turns it off while the keyboard
    // moves, so a row never shows the pointer and the keyboard band at once.
    property bool pointerEmphasis: true
    property point lastPointerPosition: Qt.point(-1, -1)
    readonly property bool motionEnabled: !reducedMotion && Kirigami.Units.longDuration > 1
    readonly property PopupMetrics metrics: PopupMetrics {
        scale: root.popupScale
        iconSize: root.popupIconSize
        listBaseIconSize: root.popupListIconSize
        fanBaseIconSize: root.popupFanIconSize
    }
    readonly property bool fanMode: viewMode === "fan"
    readonly property real tailExtent: root.fanMode ? 0 : Kirigami.Units.largeSpacing
    readonly property real cornerRadius: Kirigami.Units.cornerRadius * 2
    readonly property int entryCount: root.selection
        ? Math.max(0, Math.floor(Number(root.selection.count) || 0)) : 0
    readonly property real inset: Kirigami.Units.largeSpacing * 2

    signal activateRequested(string appId)
    signal closeRequested()

    HoverHandler {
        id: contentPointer
        // Real pointer motion hands the emphasis back to the pointer; leaving the
        // popup does not, so the keyboard keeps marking its row.
        onPointChanged: {
            const position = point.position
            if (position.x === root.lastPointerPosition.x
                    && position.y === root.lastPointerPosition.y) return
            root.lastPointerPosition = position
            root.pointerEmphasis = true
        }
    }
    FontMetrics { id: nameMetrics; font: Kirigami.Theme.defaultFont }
    readonly property real cellWidth: root.metrics.gridCellWidth
    readonly property real cellHeight: root.metrics.gridCellHeight
    readonly property real listRowHeight: root.metrics.listRowHeight
    readonly property real detailRowHeight: root.metrics.detailRowHeight
    readonly property real rowHeight: root.viewMode === "detail" ? root.detailRowHeight : root.listRowHeight
    readonly property int maximumColumns: Math.max(1, Math.min(root.metrics.maximumGridColumns,
        Math.floor((root.maximumWidth - root.inset * 2 - root.metrics.indicatorGutter) / root.cellWidth)))
    readonly property real chromeHeight: root.fanMode ? 0
        : header.implicitHeight + root.inset * 2 + Kirigami.Units.largeSpacing
    // Height the arrangement may use. The ceiling keeps a usability floor, so a
    // surface shorter than the popup shows whole rows instead of a clipped one.
    readonly property real availableContentHeight: Math.max(0, root.maximumHeight - root.chromeHeight)
    // These rows all launch an application, so the arrangement adds no closing
    // location action cell.
    readonly property var gridLayout: EntryLayout.arrangement(root.entryCount, root.maximumColumns,
        EntryLayout.rowCeiling(root.availableContentHeight, root.cellHeight), false)
    readonly property var listLayout: EntryLayout.singleColumnArrangement(root.entryCount,
        EntryLayout.rowCeiling(root.availableContentHeight, root.rowHeight), false)
    readonly property int columns: root.gridLayout.columns
    readonly property bool scrollRequired: root.fanMode ? false
        : root.viewMode === "grid" ? root.gridLayout.scrollRequired : root.listLayout.scrollRequired
    // The strip the indicator paints in exists only while the content scrolls,
    // so the surface collapses back to its content and no row runs under the
    // thumb.
    readonly property real scrollGutter: root.scrollRequired ? root.metrics.indicatorGutter : 0
    readonly property real contentHeight: root.viewMode === "grid"
        ? root.gridLayout.visibleRows * root.cellHeight
        : root.listLayout.visibleRows * root.rowHeight
    // Names are measured with the row font and capped at the same resting width
    // a row paints, so the surface never grows past what its rows can use.
    readonly property real listNaturalWidth: {
        if (!root.selection) return 0
        let widest = 0
        for (let index = 0; index < root.entryCount; ++index) {
            const entry = root.selection.get(index)
            widest = Math.max(widest, nameMetrics.advanceWidth(String(entry.entryName || "")))
        }
        return Math.min(widest, root.metrics.maximumRestingNameWidth)
            + root.metrics.listIconSize + Kirigami.Units.largeSpacing * 4
    }
    readonly property real fanMaximumContentHeight: Math.max(0, root.maximumHeight - root.chromeHeight)
    readonly property real fanContentHeight: Math.max(0,
        Math.min(root.fanMaximumContentHeight, fan.implicitHeight))
    // Centre of the glyph on the row that faces the panel, in this item's
    // coordinates.
    readonly property real fanOriginIconCenterX: fan.baseIconX + fan.iconSize / 2
    implicitWidth: root.fanMode
        ? Math.min(root.maximumWidth, fan.implicitWidth)
        : Math.min(root.maximumWidth, Math.max(Kirigami.Units.gridUnit * 16,
            root.viewMode === "grid"
                ? root.columns * root.cellWidth + root.inset * 2 + root.scrollGutter
                : root.listNaturalWidth + root.inset * 2 + root.scrollGutter))
    implicitHeight: root.fanMode
        ? Math.max(1, root.fanContentHeight)
        : Math.min(root.maximumHeight, root.chromeHeight
            + Math.max(root.viewMode === "grid" ? root.cellHeight : root.rowHeight, root.contentHeight))
    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Window

    function focusFirst(reason: int): void {
        if (!root || !header) return
        if (root.fanMode) {
            fan.requestInitialFocus(reason)
            return
        }
        if (!grid || !list) return
        const view = root.viewMode === "grid" ? grid : list
        if (view.currentItem) view.currentItem.forceActiveFocus(reason)
        else header.focusFirst(reason)
    }
    function restoreView(focusReason: int): void {
        if (root.fanMode) {
            fan.requestInitialFocus(focusReason)
            return
        }
        const view = root.viewMode === "grid" ? grid : list
        // The first row is where the keyboard starts when nothing was chosen.
        if (view.currentIndex < 0 && root.entryCount > 0) view.currentIndex = 0
        view.contentY = 0
        Qt.callLater(function() {
            if (!root || !header) return
            if (!header.activeFocus) root.focusFirst(focusReason)
        })
    }
    // Opening does not paint a band: the pointer or the keyboard asks for it.
    function requestInitialFocus(reason): void {
        if (reason === undefined) reason = Qt.MouseFocusReason
        Qt.callLater(function() { if (root) root.restoreView(reason) })
    }
    function selectGrid(index: int): void {
        if (index < 0 || index >= root.entryCount) return
        root.pointerEmphasis = false
        grid.currentIndex = index
        grid.positionViewAtIndex(index, GridView.Contain)
        Qt.callLater(function() { if (root) root.focusFirst(Qt.TabFocusReason) })
    }
    function selectRow(index: int): void {
        if (index < 0 || index >= root.entryCount) return
        root.pointerEmphasis = false
        list.currentIndex = index
        list.positionViewAtIndex(index, ListView.Contain)
        Qt.callLater(function() { if (root) root.focusFirst(Qt.TabFocusReason) })
    }
    function activate(index: int): bool {
        if (!root.selection || index < 0 || index >= root.entryCount) return false
        const entry = root.selection.get(index)
        const appId = entry && entry.appId ? String(entry.appId) : ""
        if (appId.length === 0) return false
        root.activateRequested(appId)
        return true
    }
    onViewModeChanged: {
        root.pointerEmphasis = true
        Qt.callLater(function() { if (root) root.focusFirst(Qt.MouseFocusReason) })
    }
    onEntryCountChanged: {
        if (grid.currentIndex >= root.entryCount) grid.currentIndex = root.entryCount - 1
        if (list.currentIndex >= root.entryCount) list.currentIndex = root.entryCount - 1
    }

    // The fan has no surface of its own: the rows float over the desktop and
    // only their pills and glyphs paint, like the reference stacks. The balloon
    // stays for the flat presentations.
    BalloonSurface {
        anchors.fill: parent
        visible: !root.fanMode
        objectName: "recentApplicationsSurface"
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
        PopupHeader {
            id: header
            Layout.fillWidth: true
            // The arc has no card to carry a title or a close control: it is
            // dismissed by clicking outside, with Escape or by its own rows.
            visible: !root.fanMode
            title: root.title
            canGoBack: false
            onCloseRequested: root.closeRequested()
        }
        Item {
            id: rows
            objectName: "recentApplicationsViewport"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            // The layout must reserve room for the presentation, otherwise the
            // popup collapses to its header and no entry can be seen.
            Layout.preferredHeight: root.fanMode
                ? Math.max(1, root.fanContentHeight)
                : Math.max(root.viewMode === "grid" ? root.cellHeight : root.rowHeight, root.contentHeight)
            WheelHandler {
                objectName: "recentApplicationsWheel"
                enabled: !root.fanMode
                acceptedDevices: PointerDevice.Mouse
                onWheel: function(event) {
                    const view = root.viewMode === "grid" ? grid : list
                    if (view.contentHeight > view.height)
                        view.flick(0, event.angleDelta.y * 2)
                }
            }
            Label {
                objectName: "recentApplicationsEmpty"
                anchors.centerIn: parent
                visible: root.entryCount === 0 && !root.fanMode
                text: qsTr("Empty")
                textFormat: Text.PlainText
                width: parent.width
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                color: Kirigami.Theme.disabledTextColor
            }
            GridView {
                id: grid
                objectName: "recentApplicationsGrid"
                anchors.fill: parent
                visible: root.viewMode === "grid"
                clip: true; boundsBehavior: Flickable.StopAtBounds
                cellWidth: (width - root.scrollGutter) / root.columns
                cellHeight: root.cellHeight
                model: root.selection
                ScrollBar.vertical: PopupScrollBar {
                    motionEnabled: root.motionEnabled
                    thickness: root.metrics.indicatorThickness
                }
                delegate: EntryButton {
                    id: gridEntry
                    required property int index
                    required entryName
                    required entryIcon
                    objectName: "recentApplicationEntry-" + gridEntry.index
                    width: grid.cellWidth; height: grid.cellHeight
                    grid: true
                    metrics: root.metrics
                    motionEnabled: root.motionEnabled
                    highlighted: GridView.isCurrentItem
                    pointerEmphasis: root.pointerEmphasis
                    onHoveredChanged: if (gridEntry.hovered) root.pointerEmphasis = true
                    onClicked: root.activate(gridEntry.index)
                    Keys.onLeftPressed: root.selectGrid(gridEntry.index - 1)
                    Keys.onRightPressed: root.selectGrid(gridEntry.index + 1)
                    Keys.onUpPressed: root.selectGrid(gridEntry.index - root.columns)
                    Keys.onDownPressed: root.selectGrid(gridEntry.index + root.columns)
                }
            }
            ListView {
                id: list
                objectName: "recentApplicationsList"
                anchors.fill: parent
                visible: root.viewMode === "list" || root.viewMode === "detail"
                clip: true; boundsBehavior: Flickable.StopAtBounds
                model: root.selection
                ScrollBar.vertical: PopupScrollBar {
                    motionEnabled: root.motionEnabled
                    thickness: root.metrics.indicatorThickness
                }
                delegate: EntryButton {
                    id: listEntry
                    required property int index
                    required entryName
                    required entryIcon
                    objectName: "recentApplicationRow-" + listEntry.index
                    width: list.width - root.scrollGutter
                    height: root.rowHeight
                    grid: false
                    detailed: root.viewMode === "detail"
                    metrics: root.metrics
                    motionEnabled: root.motionEnabled
                    highlighted: ListView.isCurrentItem
                    pointerEmphasis: root.pointerEmphasis
                    onHoveredChanged: if (listEntry.hovered) root.pointerEmphasis = true
                    onClicked: root.activate(listEntry.index)
                    Keys.onUpPressed: root.selectRow(listEntry.index - 1)
                    Keys.onDownPressed: root.selectRow(listEntry.index + 1)
                }
            }
            FanView {
                id: fan
                objectName: "recentApplicationsFan"
                anchors.fill: parent
                visible: root.fanMode
                contents: root.selection
                dockEdge: root.dockEdge
                iconSize: Math.round(root.metrics.fanIconSize)
                rowLimit: 6
                maximumContentHeight: root.fanMaximumContentHeight
                showLabels: true
                fontFamily: Kirigami.Theme.defaultFont.family
                fontSize: Kirigami.Theme.defaultFont.pointSize
                motionEnabled: root.motionEnabled
                opened: root.surfaceVisible
                // Every row launches an application, so the arc ends in its last
                // entry instead of a way back to a folder.
                hasLocationAction: false
                pointerEmphasis: root.pointerEmphasis
                onActivateRequested: function(index) { root.activate(index) }
                onCloseRequested: root.closeRequested()
            }
        }
    }
}
