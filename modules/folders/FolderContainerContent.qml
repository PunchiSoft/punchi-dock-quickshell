// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Punchi.Kde as Native
import "../../components"
import "../../config"
import "FolderLayout.js" as FolderLayout

Item {
    id: root
    required property FolderNavigationController controller
    property string viewMode: "grid"
    property real maximumWidth: Kirigami.Units.gridUnit * 36
    property real maximumHeight: Kirigami.Units.gridUnit * 30
    // Presentation scale and one glyph per presentation, chosen in Settings.
    // The metrics object turns them into the row and cell sizes.
    property real popupScale: 1
    property int popupIconSize: 0
    property int popupListIconSize: 0
    property int popupFanIconSize: 0
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
    // Optional clipboard used by the entry menu. The popup owner may inject one
    // in tests; the default writes through the Quickshell clipboard.
    property var clipboardService: null
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
    signal closeRequested()
    signal viewRequested(string mode)
    property bool gridActionSelected: false
    property bool listActionSelected: false
    // Which emphasis owns the listing. The pointer owns it while it is over the
    // popup, so exactly one row ever paints a band; the keyboard takes it back on
    // the next key press.
    property bool pointerEmphasis: true
    property bool navigationFocusPending: false
    property point lastPointerPosition: Qt.point(-1, -1)
    HoverHandler {
        id: contentPointer
        // Real pointer motion hands the emphasis back to the pointer, so a move
        // inside the row the keyboard left does not keep the solid band; leaving
        // the popup does not, so the keyboard keeps marking its row.
        onPointChanged: {
            const position = point.position
            if (position.x === root.lastPointerPosition.x
                    && position.y === root.lastPointerPosition.y) return
            root.lastPointerPosition = position
            root.pointerEmphasis = true
        }
    }
    // The model appends the location action to the listing, so every
    // presentation ends with the same way out of the popup.
    Native.FolderEntriesModel { id: entries; contents: root.controller.contents }
    FontMetrics { id: nameMetrics; font: Kirigami.Theme.defaultFont }
    // The popup never imports Quickshell itself: the dock injects the clipboard
    // service, and an absent one leaves Copy Path disabled.
    readonly property bool copyAvailable: root.clipboardService !== null
    readonly property real inset: Kirigami.Units.largeSpacing * 2
    readonly property int entryCount: root.controller.contents.count
    readonly property real gridIconSize: root.metrics.gridIconSize
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
    readonly property var gridLayout: FolderLayout.arrangement(root.entryCount, root.maximumColumns,
        FolderLayout.rowCeiling(root.availableContentHeight, root.cellHeight))
    readonly property var listLayout: FolderLayout.singleColumnArrangement(root.entryCount,
        FolderLayout.rowCeiling(root.availableContentHeight, root.rowHeight))
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
    // Width the labels ask for. Reading the revision re-measures the names when
    // an entry is renamed or the listing changes without changing its count.
    readonly property real listNaturalWidth: {
        const revision = root.controller.contents.revision
        if (revision < 0) return 0
        let widest = 0
        for (let index = 0; index < root.entryCount; ++index) {
            const entry = root.controller.contents.get(index)
            widest = Math.max(widest, nameMetrics.advanceWidth(String(entry.entryName || "")))
        }
        return widest + root.metrics.listIconSize + Kirigami.Units.largeSpacing * 4
    }
    // Height the fan may use.
    readonly property real fanMaximumContentHeight: Math.max(0, root.maximumHeight - root.chromeHeight)
    // Centre of the glyph on the row that faces the panel, in this item's
    // coordinates.
    readonly property real fanOriginIconCenterX: fan.baseIconX + fan.iconSize / 2
    readonly property real fanContentHeight: Math.max(0,
        Math.min(root.fanMaximumContentHeight, fan.implicitHeight))
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
            fan.requestInitialFocus()
            return
        }
        if (!grid || !list) return
        const view = root.viewMode === "grid" ? grid : list
        if (view.currentItem) view.currentItem.forceActiveFocus(reason)
        else header.focusFirst()
    }
    function restoreView(focusReason: int): void {
        if (!controller || !controller.contents || controller.contents.loading) return
        if (root.fanMode) {
            navigationFocusPending = false
            fan.requestInitialFocus()
            return
        }
        root.requestCurrentIndexSync()
        const view = root.viewMode === "grid" ? grid : list
        view.contentY = Math.max(0, Math.min(root.controller.scrollPosition, Math.max(0, view.contentHeight - view.height)))
        const restoreFocus = navigationFocusPending
        navigationFocusPending = false
        Qt.callLater(function() {
            if (!root || !header) return
            if (restoreFocus || !header.activeFocus) root.focusFirst(focusReason)
        })
    }
    // The views write their own current index while they load and scroll, so the
    // container re-applies the selected row instead of binding it once. Writing
    // it inside a model signal would force a synchronous layout while the
    // concatenated proxy is still changing, which crashes the view, so the sync
    // always waits for the event loop.
    function requestCurrentIndexSync(): void {
        Qt.callLater(root.syncCurrentIndex)
    }
    function syncCurrentIndex(): void {
        if (!grid || !list) return
        const gridIndex = root.gridActionSelected || root.entryCount === 0
            ? root.entryCount : root.controller.selectedIndex
        const listIndex = root.listActionSelected ? root.entryCount
            : root.controller.selectedIndex
        if (grid.currentIndex !== gridIndex) grid.currentIndex = gridIndex
        if (list.currentIndex !== listIndex) list.currentIndex = listIndex
    }
    function requestInitialFocus(): void {
        gridActionSelected = false
        listActionSelected = false
        navigationFocusPending = false
        // Opening does not paint a band: the pointer or the keyboard asks for it.
        Qt.callLater(function() { root.restoreView(Qt.MouseFocusReason) })
    }
    function selectGrid(index: int): void {
        root.pointerEmphasis = false
        // A listing that is still loading has no action row yet, so it cannot
        // take the selection.
        gridActionSelected = !root.controller.contents.loading && index === root.entryCount
        if (!gridActionSelected) controller.select(index)
        root.requestCurrentIndexSync()
        Qt.callLater(function() { root.focusFirst(Qt.TabFocusReason) })
    }
    function selectRow(index: int): void {
        root.pointerEmphasis = false
        listActionSelected = !root.controller.contents.loading && index === root.entryCount
        if (!listActionSelected) controller.select(index)
        root.requestCurrentIndexSync()
        Qt.callLater(function() { root.focusFirst(Qt.TabFocusReason) })
    }
    function openEntryMenu(anchor: Item, entry: var): bool {
        if (!anchor || !entry || root.fanMode) return false
        entryMenu.entryName = String(entry.entryName || "")
        entryMenu.entryUrl = entry.entryUrl
        entryMenu.entryPath = root.controller.localPath(entry.entryUrl)
        entryMenu.directory = entry.directory === true
        entryMenu.open(anchor)
        return true
    }
    function copyEntryPath(): bool {
        const service = root.clipboardService
        if (!service || entryMenu.entryPath.length === 0) return false
        return service.copyText(entryMenu.entryPath)
    }
    onViewModeChanged: {
        root.gridActionSelected = false
        root.listActionSelected = false
        root.requestCurrentIndexSync()
        Qt.callLater(function() { root.focusFirst(Qt.MouseFocusReason) })
    }
    Connections { target: root.controller; function onRestoreRequested() { root.requestInitialFocus() } }
    Connections {
        target: root.controller
        function onSelectedIndexChanged() { root.requestCurrentIndexSync() }
    }
    Connections {
        target: root.controller.contents
        function onStateChanged() {
            if (!root.controller.contents.loading)
                Qt.callLater(function() { root.restoreView(Qt.MouseFocusReason) })
        }
        function onCountChanged() { root.requestCurrentIndexSync() }
    }
    onGridActionSelectedChanged: root.requestCurrentIndexSync()
    onListActionSelectedChanged: root.requestCurrentIndexSync()
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
        FolderPopupHeader {
            id: header
            Layout.fillWidth: true
            // The arc has no card to carry a title or a close control: it is
            // dismissed by clicking outside, with Escape or by its own rows.
            visible: !root.fanMode
            title: root.controller.title
            canGoBack: root.controller.canGoBack
            onBackRequested: root.controller.back()
            onCloseRequested: root.closeRequested()
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
                : Math.max(root.viewMode === "grid" ? root.cellHeight : root.rowHeight, root.contentHeight)

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
                cellWidth: (width - root.scrollGutter) / root.columns
                cellHeight: root.cellHeight
                model: entries

                onContentYChanged: if (moving) root.controller.scrollPosition = contentY
                ScrollBar.vertical: PopupScrollBar {
                    motionEnabled: root.motionEnabled
                    thickness: root.metrics.indicatorThickness
                }
                delegate: FolderEntryButton {
                    id: gridEntry
                    required property int index
                    required entryName
                    required entryIcon
                    required description
                    required locationAction
                    required directory
                    objectName: locationAction
                        ? "folderOpenLocation" : "folderGridEntry-" + index
                    width: grid.cellWidth; height: grid.cellHeight
                    grid: true
                    metrics: root.metrics
                    motionEnabled: root.motionEnabled
                    highlighted: GridView.isCurrentItem
                    pointerEmphasis: root.pointerEmphasis
                    browsable: gridEntry.directory && root.browseSubfolders
                    onHoveredChanged: if (gridEntry.hovered) root.pointerEmphasis = true
                    onClicked: {
                        if (gridEntry.locationAction) root.controller.openLocation()
                        else { root.controller.select(gridEntry.index); root.controller.activate(gridEntry.index) }
                    }
                    onContextRequested: function(anchor) {
                        root.openEntryMenu(anchor, root.controller.contents.get(gridEntry.index))
                    }
                    Keys.onLeftPressed: root.selectGrid(Math.max(0, gridEntry.index - 1))
                    Keys.onRightPressed: root.selectGrid(Math.min(grid.count - 1, gridEntry.index + 1))
                    Keys.onUpPressed: root.selectGrid(Math.max(0, gridEntry.index - root.columns))
                    Keys.onDownPressed: root.selectGrid(Math.min(grid.count - 1, gridEntry.index + root.columns))
                }
                onCurrentIndexChanged: {
                    positionViewAtIndex(currentIndex, GridView.Contain)
                    if (activeFocus) Qt.callLater(function() {
                        if (root) root.focusFirst(Qt.OtherFocusReason)
                    })
                }
            }
            ListView {
                id: list
                objectName: "folderList"
                anchors.fill: parent
                visible: (root.viewMode === "list" || root.viewMode === "detail")
                    && !root.controller.contents.loading
                    && root.controller.contents.error.length === 0
                clip: true; boundsBehavior: Flickable.StopAtBounds
                model: entries

                onContentYChanged: if (moving) root.controller.scrollPosition = contentY
                ScrollBar.vertical: PopupScrollBar {
                    motionEnabled: root.motionEnabled
                    thickness: root.metrics.indicatorThickness
                }
                delegate: FolderEntryButton {
                    id: listEntry
                    required property int index
                    required entryName
                    required entryIcon
                    required description
                    required locationAction
                    required directory
                    objectName: locationAction
                        ? "folderOpenLocation" : "folderListEntry-" + index
                    width: list.width - root.scrollGutter
                    height: root.rowHeight
                    grid: false
                    detailed: root.viewMode === "detail"
                    metrics: root.metrics
                    motionEnabled: root.motionEnabled
                    highlighted: ListView.isCurrentItem
                    pointerEmphasis: root.pointerEmphasis
                    browsable: listEntry.directory && root.browseSubfolders
                    onHoveredChanged: if (listEntry.hovered) root.pointerEmphasis = true
                    onClicked: {
                        if (listEntry.locationAction) { root.controller.openLocation(); return }
                        root.listActionSelected = false
                        root.controller.select(listEntry.index)
                        root.controller.activate(listEntry.index)
                    }
                    onContextRequested: function(anchor) {
                        root.openEntryMenu(anchor, root.controller.contents.get(listEntry.index))
                    }
                    Keys.onUpPressed: root.selectRow(Math.max(0, listEntry.index - 1))
                    Keys.onDownPressed: root.selectRow(Math.min(list.count - 1, listEntry.index + 1))
                }
                onCurrentIndexChanged: {
                    positionViewAtIndex(currentIndex, ListView.Contain)
                    if (activeFocus) Qt.callLater(function() {
                        if (root) root.focusFirst(Qt.OtherFocusReason)
                    })
                }
            }
            FolderFanView {
                id: fan
                objectName: "folderFanView"
                anchors.fill: parent
                visible: root.fanMode && !root.controller.contents.loading
                    && root.controller.contents.error.length === 0
                contents: root.controller.contents
                dockEdge: root.dockEdge
                iconSize: Math.round(root.metrics.fanIconSize)
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
    }
    // Rows of a flickable never see a secondary click, so the gesture is caught
    // just above the listing, as the dock does for its tiles. Left clicks and
    // hover still reach the rows; the wheel is forwarded so the listing keeps
    // scrolling smoothly.
    MouseArea {
        id: entryPointer
        anchors.fill: parent
        anchors.margins: root.inset
        anchors.topMargin: root.inset + header.implicitHeight + Kirigami.Units.largeSpacing
        z: 1
        enabled: !root.fanMode
        acceptedButtons: Qt.RightButton
        propagateComposedEvents: true
        onClicked: function(mouse) {
            if (mouse.button !== Qt.RightButton) return
            const view = root.viewMode === "grid" ? grid : list
            const local = view.mapFromItem(entryPointer, mouse.x, mouse.y)
            const index = view.indexAt(local.x + view.contentX, local.y + view.contentY)
            if (index >= 0)
                root.openEntryMenu(view.itemAtIndex(index), root.controller.contents.get(index))
        }
        onWheel: function(wheel) {
            const view = root.viewMode === "grid" ? grid : list
            if (view.contentHeight > view.height)
                view.flick(0, wheel.angleDelta.y * 2)
            wheel.accepted = true
        }
    }
    FolderEntryContextMenu {
        id: entryMenu
        motionEnabled: root.motionEnabled
        copyAvailable: root.copyAvailable
        onOpenLocationRequested: {
            // A directory opens where it lives; a file reveals the folder that
            // holds it, which is what the label promises.
            if (entryMenu.directory && entryMenu.entryUrl.toString().length > 0)
                root.controller.open(entryMenu.entryUrl)
            else root.controller.openLocation()
        }
        onCopyPathRequested: root.copyEntryPath()
    }
}
