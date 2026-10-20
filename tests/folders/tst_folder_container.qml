// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Punchi.Kde as Native
import "../../modules/folders"
import "../../modules/dock"
import "../../components"
import "../../config"
import "../../services"
import "../../modules/settings"

TestCase {
    id: test
    name: "FolderContainer"
    when: windowShown
    visible: true
    width: 800; height: 800
    property string captureDirectory: ""
    property bool captured: false
    function capture(item: Item, name: string): void {
        if (!captureDirectory) return
        captured = false
        verify(item.grabToImage(function(result) {
            verify(result.saveToFile(test.captureDirectory + "/" + name + ".png"))
            test.captured = true
        }))
        tryCompare(test, "captured", true)
    }
    SignalSpy { id: clicked; signalName: "clicked" }
    SignalSpy { id: menuSortSpy; signalName: "folderSortRequested" }
    SignalSpy { id: menuLayoutSpy; signalName: "folderLayoutRequested" }
    Component { id: editingFixture; SettingsEditService { settings: ShellSettings {} } }
    Component {
        id: folderMenuFixture
        DockContextContent {
            folderItem: true
            folderContainer: QtObject {
                property string title: "Owned folder"
                property string layout: "grid"
                property string sortMode: "modified"
            }
        }
    }
    Component {
        id: verticalFolderMenuFixture
        DockContextContent {
            folderItem: true
            settings: ShellSettings { dockEdge: "left" }
            folderContainer: QtObject {
                property string title: "Owned folder"
                property string layout: "fan"
                property string sortMode: "modified"
            }
        }
    }
    Component {
        id: settingsFixture
        Item {
            width: 780; height: 680
            property alias editor: editor
            property alias view: view
            SettingsEditService {
                id: editor
                settings: ShellSettings { pinnedIds: ["item:downloads", "item:trash"] }
                Component.onCompleted: begin()
            }
            Native.DockItemCatalog {
                id: catalog
                downloadsTitle: "Downloads"
                trashTitle: "Trash"
                containers: editor.draft.containers
            }
            SettingsView {
                id: view
                anchors.fill: parent
                currentPage: 0
                settings: editor.draft
                applicationCatalog: catalog
                hasPendingChanges: editor.dirty
                onApplyRequested: editor.apply()
                onCloseRequested: editor.cancel()
            }
        }
    }
    Component {
        id: fixture
        Window {
            id: window
            width: 760; height: 740
            visible: true
            property alias popup: popup
            property alias source: source
            property alias opener: opener
            property alias settings: settings
            ShellSettings { id: settings }
            QtObject {
                id: opener
                property bool accepted: true
                property var calls: []
                function openFolderUrl(model: var, location: url): bool {
                    calls = calls.concat([location.toString()])
                    return accepted
                }
            }
            Item {
                id: host
                anchors.fill: parent
                LauncherTile {
                    id: source
                    x: 340; y: 640
                    title: "Downloads"; iconName: "folder-downloads"; appId: "item:downloads"
                    reducedMotion: true
                    onActivated: popup.toggleForItem(source, "item:downloads", settings.container("item:downloads"))
                }
                FolderContainerPopup { id: popup; hostWindow: window; settings: settings; opener: opener }
            }
        }
    }
    function init(): void { failOnWarning(/.*/) }
    function openWindow(edge: string): var {
        edge = edge || "bottom"
        const window = createTemporaryObject(fixture, test)
        verify(window !== null)
        window.settings.dockEdge = edge
        if (edge !== "bottom") {
            window.source.x = edge === "left" ? 10 : 690
            window.source.y = 350
        }
        verify(waitForRendering(window.contentItem))
        mouseClick(window.source)
        tryCompare(window.popup, "opened", true)
        tryCompare(window.popup.contents, "loading", false)
        compare(window.popup.contents.error, "")
        return window
    }
    function row(contents: var, name: string): int {
        for (let index = 0; index < contents.count; ++index)
            if (contents.get(index).entryName === name) return index
        return -1
    }
    function chooseView(window: var, index: int): void {
        // The presentation is chosen in the settings window; the popup only
        // follows it. The settings-side selector keeps its own coverage below.
        window.settings.downloadsView = ["grid", "list", "detail"][index]
        tryCompare(window.settings, "downloadsView", ["grid", "list", "detail"][index])
    }
    function test_defaultAndMigration(): void {
        const settings = createTemporaryObject(Qt.createComponent("../../config/ShellSettings.qml"), test)
        compare(settings.downloadsView, "grid")
        compare(settings.container("item:downloads").layout, "grid")
        compare(settings.pinnedIds.slice(-2).join(","), "item:downloads,item:trash")
        settings.restore({version: 2, pinnedIds: ["files", "item:trash"]})
        compare(settings.pinnedIds.join(","), "files,item:downloads,item:trash")
        settings.restore(settings.snapshot())
        compare(settings.pinnedIds.length, 3)
        settings.restore({version: 3, downloadsView: "detail", pinnedIds: ["files", "item:trash"]})
        compare(settings.pinnedIds.join(","), "files,item:trash")
        compare(settings.downloadsView, "detail")
        compare(settings.container("item:downloads").layout, "detail")
        settings.restore({version: 3, downloadsView: "invalid", pinnedIds: ["files"]})
        compare(settings.downloadsView, "detail")
    }
    function test_folderLayoutsBelongToEachItem(): void {
        const settings = createTemporaryObject(Qt.createComponent("../../config/ShellSettings.qml"), test)
        const id = settings.addContainer("/tmp/owned-folder", "Owned folder", "folder")
        verify(id.length > 0)
        verify(settings.setContainerLayout("item:downloads", "detail"))
        verify(settings.setContainerLayout(id, "list"))
        compare(settings.container("item:downloads").layout, "detail")
        compare(settings.container(id).layout, "list")
        compare(settings.downloadsView, "detail")
        compare(settings.container("item:downloads").sortMode, "modified")
        verify(settings.setContainerSortMode("item:downloads", "created"))
        verify(settings.setContainerSortMode(id, "kind"))
        const restored = createTemporaryObject(Qt.createComponent("../../config/ShellSettings.qml"), test)
        verify(restored.restore(settings.snapshot()))
        compare(restored.container(id).layout, "list")
        compare(restored.container(id).sortMode, "kind")
        compare(restored.container("item:downloads").layout, "detail")
        compare(restored.container("item:downloads").sortMode, "created")
        verify(settings.setContainerSortMode(id, "size"))
        verify(restored.restore(settings.snapshot()))
        compare(restored.container(id).sortMode, "size")
        verify(restored.restore({version: 4, downloadsView: "list",
            containers: [{id: "downloads", path: "", title: "Downloads", icon: "folder-downloads"}]}))
        compare(restored.container("item:downloads").layout, "list")
        compare(restored.container("item:downloads").sortMode, "modified")
    }
    function test_contextMenuExposesSortAndViewChoices(): void {
        const menu = createTemporaryObject(folderMenuFixture, test)
        verify(menu !== null)
        menuSortSpy.target = menu
        menuSortSpy.clear()
        menuLayoutSpy.target = menu
        menuLayoutSpy.clear()
        const size = findChild(menu, "folderSort-size")
        const created = findChild(menu, "folderSort-created")
        const type = findChild(menu, "folderSort-kind")
        const detail = findChild(menu, "folderLayout-detail")
        verify(size !== null && created !== null && type !== null && detail !== null)
        compare(size.text, "Size")
        compare(type.text, "Type")
        mouseClick(size)
        compare(menuSortSpy.count, 1)
        compare(menuSortSpy.signalArguments[0][0], "size")
        mouseClick(created)
        compare(menuSortSpy.count, 2)
        compare(menuSortSpy.signalArguments[1][0], "created")
        mouseClick(type)
        compare(menuSortSpy.count, 3)
        compare(menuSortSpy.signalArguments[2][0], "kind")
        mouseClick(detail)
        compare(menuLayoutSpy.count, 1)
        compare(menuLayoutSpy.signalArguments[0][0], "detail")
        verify(findChild(menu, "folderLayout-fan") !== null)
        compare(findChild(menu, "openFolderAction").text, "Open “Owned folder”")
    }
    function test_popupShowsGridContent(): void {
        const window = openWindow("bottom")
        const popup = window.popup
        const grid = findChild(popup.contentItem, "folderGrid")
        verify(grid !== null)
        verify(popup.contents.count > 0)
        tryCompare(grid, "count", popup.contents.count + 1)
        verify(popup.height > 0)
        verify(grid.height > 0)
        verify(grid.contentHeight > 0)
        const firstEntry = findChild(grid, "folderGridEntry-0")
        const firstIconArea = findChild(firstEntry, "folderEntryIconArea")
        verify(firstEntry !== null && firstIconArea !== null)
        compare(firstIconArea.width, popup.contentItem.gridIconSize)
        verify(grid.cellHeight > firstIconArea.height)
        verify(findChild(popup.contentItem, "folderClose") !== null)
        const title = findChild(popup.contentItem, "folderPopupTitle")
        verify(title !== null)
        compare(title.text, popup.controller.title)
        compare(title.shadowAmount, 0.25)
        compare(title.shadowBlur, 0.25)
        compare(title.shadowOpacity, 0.5625)
        compare(title.shadowOffset, 0.125)
        compare(title.layer.enabled, title.shadowAvailable)
        window.close()
    }
    function test_fanLayoutPersistsForTheContainer(): void {
        const settings = createTemporaryObject(Qt.createComponent("../../config/ShellSettings.qml"), test)
        verify(settings.setContainerLayout("item:downloads", "fan"))
        compare(settings.container("item:downloads").layout, "fan")
        compare(settings.downloadsView, "fan")
        const restored = createTemporaryObject(Qt.createComponent("../../config/ShellSettings.qml"), test)
        verify(restored.restore(settings.snapshot()))
        compare(restored.container("item:downloads").layout, "fan")
        compare(restored.downloadsView, "fan")
        compare(restored.fanSupported, true)
        // A vertical dock presents Grid without rewriting the stored choice.
        restored.dockEdge = "left"
        compare(restored.fanSupported, false)
        compare(restored.effectiveContainerLayout("item:downloads"), "grid")
        compare(restored.container("item:downloads").layout, "fan")
        restored.dockEdge = "bottom"
        compare(restored.effectiveContainerLayout("item:downloads"), "fan")
        // The arc is a presentation, not a schema change: older profiles still
        // load and keep unsupported values out of the container.
        verify(restored.restore({version: 7, downloadsView: "fan",
            containers: [{id: "downloads", path: "", title: "Downloads",
                icon: "folder-downloads", layout: "fan", sortMode: "modified"}]}))
        compare(restored.container("item:downloads").layout, "fan")
        verify(restored.restore({version: 7, downloadsView: "grid",
            containers: [{id: "downloads", path: "", title: "Downloads",
                icon: "folder-downloads", layout: "unknown", sortMode: "modified"}]}))
        compare(restored.container("item:downloads").layout, "grid")
    }
    function test_fanIsUnavailableOnVerticalDocks(): void {
        const menu = createTemporaryObject(verticalFolderMenuFixture, test)
        verify(menu !== null)
        menuLayoutSpy.target = menu
        menuLayoutSpy.clear()
        const fanAction = findChild(menu, "folderLayout-fan")
        verify(fanAction !== null)
        verify(!fanAction.enabled)
        // The container keeps its stored presentation, while the menu and the
        // popup present Grid: a vertical panel has no near row to unfold from.
        compare(String(menu.folderContainer.layout), "fan")
        compare(menu.folderLayout, "grid")
        verify(findChild(menu, "folderLayout-grid").marked)
        mouseClick(fanAction)
        compare(menuLayoutSpy.count, 0)
    }
    function test_popupShowsFanContent(): void {
        const window = openWindow("bottom")
        const popup = window.popup
        verify(window.settings.setContainerLayout("item:downloads", "fan"))
        tryCompare(popup.contentItem, "viewMode", "fan")
        const fanView = findChild(popup.contentItem, "folderFanView")
        verify(fanView !== null)
        tryVerify(function() {
            return fanView.visible && fanView.entryCount === popup.contents.count
        })
        verify(!findChild(popup.contentItem, "folderGrid").visible)
        verify(!findChild(popup.contentItem, "folderList").visible)
        verify(!findChild(popup.contentItem, "folderOpenLocation").visible)
        compare(findChild(fanView, "folderFanList").count, popup.contents.count)
        verify(popup.height > 0)
        verify(popup.contentItem.tailExtent === 0)
        // The arc paints no surface: the rows are the popup, with no chrome.
        verify(findChild(popup.contentItem, "folderFanSurface") === null)
        tryVerify(function() { return fanView.height === fanView.implicitHeight })
        fuzzyCompare(popup.height, fanView.height, 1)
        fuzzyCompare(popup.width, fanView.width, 1)
        // It grows out of the dock icon: the row that faces the panel is
        // centred on the glyph instead of on an empty card.
        const iconCenter = window.source.parent.mapToItem(window.contentItem,
            window.source.iconTopCenter)
        fuzzyCompare(popup.x + popup.contentItem.fanOriginIconCenterX,
            iconCenter.x, 1)
        capture(popup.contentItem, "fan")
        const action = findChild(fanView, "folderFanOpenLocation")
        verify(action !== null && action.visible)
        compare(action.Accessible.name, "Open")
        mouseClick(action)
        tryCompare(popup, "opened", false)
        compare(window.opener.calls.length, 1)
        window.close()
    }
    function test_popupKeepsRowsWhenPanelWindowIsExpanded(): void {
        const window = createTemporaryObject(fixture, test)
        verify(window !== null)
        // Dock's PanelWindow spans the screen while its compact content occupies
        // only a small allocation at the bottom edge.
        window.popup.hostBaseHeight = 90
        window.source.y = 640
        verify(waitForRendering(window.contentItem))
        mouseClick(window.source)
        tryCompare(window.popup, "opened", true)
        tryCompare(window.popup.contents, "loading", false)
        const viewport = findChild(window.popup.contentItem, "folderEntriesViewport")
        verify(viewport !== null)
        tryVerify(function() { return viewport.height >= window.popup.contentItem.cellHeight })
        verify(findChild(window.popup.contentItem, "folderGrid").height >= window.popup.contentItem.cellHeight)
        window.close()
    }
    function test_gridLocationActionMatchesReferenceAndCloseWorks(): void {
        const window = openWindow("bottom")
        const popup = window.popup
        const grid = findChild(popup.contentItem, "folderGrid")
        tryCompare(grid, "count", popup.contents.count + 1)
        const action = findChild(grid, "folderGridEntry-" + popup.contents.count)
        verify(action !== null)
        verify(action.locationAction)
        verify(findChild(action, "folderGridOpenLocationControl") !== null)
        compare(findChild(action, "folderEntryIcon").source, "folder-open")
        const openLabel = findChild(action, "folderEntryNameLabel")
        verify(openLabel !== null && openLabel.visible)
        compare(openLabel.text, "Open")
        compare(action.Accessible.name, "Open in File Manager")
        const regularEntry = findChild(grid, "folderGridEntry-0")
        compare(findChild(regularEntry, "folderEntryIcon").source, regularEntry.entryIcon)
        const regularContent = findChild(regularEntry, "folderEntryContent")
        const actionContent = findChild(action, "folderEntryContent")
        const regularIconArea = findChild(regularEntry, "folderEntryIconArea")
        const actionIconArea = findChild(action, "folderEntryIconArea")
        const regularLabel = findChild(regularEntry, "folderEntryNameLabel")
        verify(regularEntry !== null && regularContent !== null && actionContent !== null)
        compare(actionContent.width, regularContent.width)
        compare(actionIconArea.width, regularIconArea.width)
        compare(actionIconArea.height, regularIconArea.height)
        compare(openLabel.x, regularLabel.x)
        compare(openLabel.y, regularLabel.y)
        compare(findChild(popup.contentItem, "folderNextPage"), null)
        mouseClick(findChild(popup.contentItem, "folderClose"))
        tryCompare(popup, "visible", false)
        window.close()
    }
    function test_gridNavigationBackAndLocationAction(): void {
        const window = openWindow("bottom")
        const popup = window.popup
        verify(popup.contents.count >= 3)
        compare(popup.contents.get(0).entryName, "newest.txt")
        compare(row(popup.contents, ".hidden"), -1)
        const grid = findChild(popup.contentItem, "folderGrid")
        compare(grid.count, popup.contents.count + 1)
        verify(waitForRendering(popup.contentItem))
        capture(popup.contentItem, "grid")
        const nested = row(popup.contents, "nested")
        verify(nested >= 0)
        const entry = findChild(grid, "folderGridEntry-" + nested)
        verify(entry !== null)
        compare(popup.contents.get(nested).directory, true)
        compare(entry.entryName, "nested")
        verify(entry.visible)
        clicked.target = entry; clicked.clear()
        mouseClick(entry)
        compare(clicked.count, 1)
        tryCompare(popup.controller, "title", "nested")
        tryCompare(popup.contents, "loading", false)
        tryCompare(popup.contents, "count", 1)
        compare(popup.controller.canGoBack, true)
        mouseClick(findChild(popup.contentItem, "folderBack"))
        tryCompare(popup.controller, "canGoBack", false)
        tryCompare(popup.contents, "loading", false)
        compare(popup.contents.get(popup.controller.selectedIndex).entryName, "nested")
        grid.positionViewAtIndex(grid.count - 1, GridView.Contain)
        const location = findChild(grid, "folderGridEntry-" + popup.contents.count)
        verify(location !== null)
        mouseClick(location)
        tryCompare(popup, "visible", false)
        compare(decodeURI(window.opener.calls[0]), decodeURI(popup.contents.location.toString()))
        compare(popup.contents.active, false)
        window.close()
    }
    function test_listDetailFileAndRejectedDispatch(): void {
        const window = openWindow("bottom")
        chooseView(window, 1)
        const list = findChild(window.popup.contentItem, "folderList")
        verify(list.visible)
        verify(waitForRendering(window.popup.contentItem))
        capture(window.popup.contentItem, "list")
        const openLocation = findChild(window.popup.contentItem, "folderOpenLocation")
        verify(openLocation.visible)
        compare(openLocation.icon.name, "folder-open")
        chooseView(window, 2)
        compare(openLocation.icon.name, "folder-open")
        const item = findChild(list, "folderListEntry-0")
        verify(item !== null)
        compare(item.detailed, true)
        verify(item.description.length > 0)
        verify(findChild(item, "folderEntryNameLabel") !== null)
        verify(waitForRendering(window.popup.contentItem))
        capture(window.popup.contentItem, "detail")
        window.opener.accepted = false
        // Rejection logging is an existing internal diagnostic, not UI failure.
        ignoreWarning("Punchi Dock Quickshell: folder activation rejected")
        mouseClick(item)
        verify(window.popup.visible)
        window.opener.accepted = true
        mouseClick(item)
        tryCompare(window.popup, "visible", false)
        compare(window.settings.downloadsView, "detail")
        window.close()
    }
    function test_popupMarqueeKeepsEntryGeometryAndAccessibleName(): void {
        const window = openWindow("bottom")
        const popup = window.popup
        const longName = "A deliberately long folder popup filename for marquee.txt"
        const index = row(popup.contents, longName)
        verify(index >= 0)
        const grid = findChild(popup.contentItem, "folderGrid")
        const entry = findChild(grid, "folderGridEntry-" + index)
        const label = findChild(entry, "folderEntryNameLabel")
        verify(entry !== null && label !== null)
        tryCompare(label, "overflowing", true)
        compare(entry.Accessible.name, longName)
        verify(label.Accessible.ignored)
        const originalWidth = label.width
        const originalHeight = entry.height
        mouseMove(entry, entry.width / 2, entry.height / 2)
        tryCompare(label, "hovered", true)
        tryVerify(function() { return label.scrollOffset < -1 })
        compare(label.width, originalWidth)
        compare(entry.height, originalHeight)
        mouseMove(popup.contentItem, popup.contentItem.width - 2, popup.contentItem.height - 2)
        tryCompare(label, "hovered", false)
        tryCompare(label, "scrollOffset", 0)

        chooseView(window, 1)
        const list = findChild(popup.contentItem, "folderList")
        const rowEntry = findChild(list, "folderListEntry-" + index)
        const rowLabel = findChild(rowEntry, "folderEntryNameLabel")
        verify(rowEntry !== null && rowLabel !== null)
        tryCompare(rowLabel, "overflowing", true)
        compare(rowEntry.Accessible.name, longName)
        const rowHeight = rowEntry.height
        rowEntry.forceActiveFocus(Qt.TabFocusReason)
        tryCompare(rowLabel, "focused", true)
        tryCompare(rowLabel, "revealFullText", true)
        compare(rowEntry.height, rowHeight)
        window.close()
    }

    function test_popupMarqueeHonorsReducedMotion(): void {
        const window = openWindow("bottom")
        const longName = "A deliberately long folder popup filename for marquee.txt"
        const index = row(window.popup.contents, longName)
        verify(index >= 0)
        window.settings.reducedMotion = true
        const grid = findChild(window.popup.contentItem, "folderGrid")
        const entry = findChild(grid, "folderGridEntry-" + index)
        const label = findChild(entry, "folderEntryNameLabel")
        verify(label !== null)
        tryCompare(window.popup.contentItem, "motionEnabled", false)
        label.hovered = true
        compare(label.scrollOffset, 0)
        tryCompare(label, "fullNameTooltipVisible", true)
        window.close()
    }
    function test_escapeToggleAndKeyboard(): void {
        const window = openWindow("bottom")
        const grid = findChild(window.popup.contentItem, "folderGrid")
        const first = findChild(grid, "folderGridEntry-0")
        first.forceActiveFocus(Qt.TabFocusReason)
        keyClick(Qt.Key_Right)
        tryCompare(window.popup.controller, "selectedIndex", 1)
        const second = findChild(grid, "folderGridEntry-1")
        tryCompare(second, "activeFocus", true)
        keyClick(Qt.Key_Escape)
        tryCompare(window.popup, "visible", false)
        compare(window.popup.contents.active, false)
        mouseClick(window.source)
        tryCompare(window.popup, "opened", true)
        mouseClick(window.source)
        tryCompare(window.popup, "visible", false)
        window.close()
    }
    function test_sidePlacement_data(): var { return [{tag:"left", edge:"left"}, {tag:"right", edge:"right"}] }
    function test_sidePlacement(data: var): void {
        const window = openWindow(data.edge)
        const popup = window.popup
        const surface = findChild(popup.contentItem, "folderContainerSurface")
        compare(surface.tailEdge, data.edge)
        fuzzyCompare(surface.tailHeight, popup.contentItem.tailExtent, 0.01)
        fuzzyCompare(surface.tailBaseScale, 0.9, 0.01)
        verify(surface.effectiveTailTipRadius > 0)
        verify(popup.x >= 0 && popup.y >= 0)
        verify(popup.x + popup.width <= window.width)
        verify(popup.y + popup.height <= window.height)
        const top = window.source.parent.mapToItem(window.contentItem, window.source.iconTopCenter)
        const anchor = Qt.rect(top.x - window.source.iconSize / 2, top.y, window.source.iconSize, window.source.iconSize)
        if (data.edge === "left") verify(popup.x >= anchor.x + anchor.width)
        else verify(popup.x + popup.width <= anchor.x)
        // The arc belongs to horizontal panels: a vertical dock keeps its
        // balloon and presents Grid even when the container stores the fan.
        verify(window.settings.setContainerLayout("item:downloads", "fan"))
        compare(popup.contentItem.viewMode, "grid")
        compare(window.settings.effectiveContainerLayout("item:downloads"), "grid")
        compare(window.settings.container("item:downloads").layout, "fan")
        verify(surface.visible)
        const fanView = findChild(popup.contentItem, "folderFanView")
        verify(fanView !== null)
        verify(!fanView.visible)
        verify(popup.x >= 0 && popup.y >= 0)
        verify(popup.x + popup.width <= window.width)
        verify(popup.y + popup.height <= window.height)
        window.close()
    }
    function test_viewDraftApplyCancelAndExternalUpdates(): void {
        const editor = createTemporaryObject(editingFixture, test)
        editor.begin()
        editor.draft.downloadsView = "detail"
        compare(editor.settings.downloadsView, "grid")
        editor.cancel()
        compare(editor.draft.downloadsView, "grid")
        editor.begin()
        editor.settings.downloadsView = "list"
        compare(editor.draft.downloadsView, "list")
        editor.draft.downloadsView = "detail"
        editor.apply()
        compare(editor.settings.downloadsView, "detail")
        compare(editor.dirty, false)
    }
    function test_itemViewControlPendingAndReactive(): void {
        const fixture = createTemporaryObject(settingsFixture, test)
        verify(waitForRendering(fixture))
        const row = findChild(fixture.view, "configuredItem-item:downloads")
        verify(row !== null)
        mouseClick(row)
        const selector = findChild(fixture.view, "folderViewSetting")
        verify(selector.visible)
        selector.forceActiveFocus(Qt.TabFocusReason)
        keyClick(Qt.Key_End)
        keyClick(Qt.Key_Up)
        keyClick(Qt.Key_Return)
        compare(fixture.view.settings.downloadsView, "detail")
        compare(fixture.editor.settings.downloadsView, "grid")
        mouseClick(findChild(fixture.view, "applyDockSettings"))
        compare(fixture.editor.settings.downloadsView, "detail")
        fixture.editor.settings.downloadsView = "list"
        compare(selector.currentIndex, 1)
        selector.forceActiveFocus(Qt.TabFocusReason)
        keyClick(Qt.Key_Home)
        keyClick(Qt.Key_Return)
        compare(fixture.view.settings.downloadsView, "grid")
        mouseClick(findChild(fixture.view, "closeDockSettings"))
        compare(fixture.editor.settings.downloadsView, "list")
    }
    function test_viewSelectorHidesTheArcOnVerticalDocks(): void {
        const fixture = createTemporaryObject(settingsFixture, test)
        fixture.view.settings.dockEdge = "left"
        verify(waitForRendering(fixture))
        mouseClick(findChild(fixture.view, "configuredItem-item:downloads"))
        const selector = findChild(fixture.view, "folderViewSetting")
        verify(selector.visible)
        compare(selector.count, 3)
        compare(selector.model[selector.count - 1], "Detail")
        // The selector still writes a flat presentation for the container.
        selector.forceActiveFocus(Qt.TabFocusReason)
        keyClick(Qt.Key_End)
        keyClick(Qt.Key_Return)
        compare(fixture.view.settings.container("item:downloads").layout, "detail")
    }
    function test_viewSelectorOffersTheArc(): void {
        const fixture = createTemporaryObject(settingsFixture, test)
        verify(waitForRendering(fixture))
        mouseClick(findChild(fixture.view, "configuredItem-item:downloads"))
        const selector = findChild(fixture.view, "folderViewSetting")
        verify(selector.visible)
        compare(selector.count, 4)
        selector.forceActiveFocus(Qt.TabFocusReason)
        keyClick(Qt.Key_End)
        keyClick(Qt.Key_Return)
        compare(fixture.view.settings.downloadsView, "fan")
        mouseClick(findChild(fixture.view, "applyDockSettings"))
        compare(fixture.editor.settings.downloadsView, "fan")
    }
    function test_settingsViewSelectorIsScopedToSelectedFolder(): void {
        const fixture = createTemporaryObject(settingsFixture, test)
        const customId = fixture.view.settings.addContainer("/tmp/owned-folder", "Owned folder", "folder")
        verify(customId.length > 0)
        fixture.view.settings.pinnedIds = ["item:downloads", customId, "item:trash"]
        verify(waitForRendering(fixture))
        mouseClick(findChild(fixture.view, "configuredItem-" + customId))
        const selector = findChild(fixture.view, "folderViewSetting")
        verify(selector.visible)
        compare(selector.currentIndex, 0)
        selector.forceActiveFocus(Qt.TabFocusReason)
        keyClick(Qt.Key_End)
        keyClick(Qt.Key_Up)
        keyClick(Qt.Key_Return)
        compare(fixture.view.settings.container(customId).layout, "detail")
        compare(fixture.view.settings.container("item:downloads").layout, "grid")
        mouseClick(findChild(fixture.view, "applyDockSettings"))
        compare(fixture.editor.settings.container(customId).layout, "detail")
        compare(fixture.editor.settings.container("item:downloads").layout, "grid")
    }
}
