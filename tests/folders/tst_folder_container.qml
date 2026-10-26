// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import org.kde.kirigami as Kirigami
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
    FontMetrics { id: nameFontMetrics; font: Kirigami.Theme.defaultFont }
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
            property alias copier: copier
            ShellSettings { id: settings }
            QtObject {
                id: copier
                property var paths: []
                function copyText(text: string): bool {
                    paths = paths.concat([String(text)])
                    return true
                }
            }
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
                FolderContainerPopup {
                    id: popup; hostWindow: window; settings: settings; opener: opener
                    clipboardService: copier
                }
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
    function test_popupSkipsEntriesTheOwnerKeptOut(): void {
        const window = openWindow("bottom")
        const popup = window.popup
        const grid = findChild(popup.contentItem, "folderGrid")
        const total = popup.contents.count
        verify(total > 1)
        verify(row(popup.contents, "old.txt") >= 0, "the owned file is listed first")
        // The stored list hides only what it names; every other entry stays.
        verify(window.settings.setContainerHiddenEntries("item:downloads", ["old.txt"]))
        tryCompare(popup.contents, "count", total - 1)
        compare(row(popup.contents, "old.txt"), -1, "the hidden entry leaves the popup")
        verify(row(popup.contents, "newest.txt") >= 0)
        tryCompare(grid, "count", popup.contents.count + 1)
        verify(findChild(grid, "folderGridEntry-0") !== null)
        // Clearing the list shows the folder as it is again.
        verify(window.settings.setContainerHiddenEntries("item:downloads", []))
        tryCompare(popup.contents, "count", total)
        verify(row(popup.contents, "old.txt") >= 0)
        // An entry the owner hid but that no longer exists is harmless.
        verify(window.settings.setContainerHiddenEntries("item:downloads", ["missing.txt"]))
        tryCompare(popup.contents, "count", total)
        verify(row(popup.contents, "old.txt") >= 0, "a stale name hides nothing else")
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
        // Only the arc carries the action row here: the flat views, and the
        // shared last row, stay hidden.
        verify(!findChild(popup.contentItem, "folderGrid").visible)
        verify(!findChild(popup.contentItem, "folderList").visible)
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
        const action = findChild(grid, "folderOpenLocation")
        verify(action !== null)
        verify(action.locationAction)
        compare(findChild(action, "folderEntryIcon").source, "folder-open")
        const openLabel = findChild(action, "folderEntryNameLabel")
        verify(openLabel !== null && openLabel.visible)
        compare(openLabel.text, "Open")
        compare(action.Accessible.name, "Open")
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
    // A delegate can ask for a row while the listing shrinks or grows. Cycling
    // every presentation around hiding and restoring an entry keeps that path
    // covered instead of trusting the concatenated row mapping.
    function test_listingChangesKeepEveryPresentationAlive(): void {
        const window = openWindow("bottom")
        const popup = window.popup
        const originalCount = popup.contents.count
        verify(originalCount >= 3)
        const hiddenName = popup.contents.get(1).entryName
        const views = ["grid", "list", "detail"]
        for (let pass = 0; pass < 2; ++pass) {
            const expected = pass === 0 ? originalCount : originalCount - 1
            for (let index = 0; index < views.length; ++index) {
                chooseView(window, index)
                tryCompare(popup.contents, "loading", false)
                verify(waitForRendering(popup.contentItem))
                tryCompare(popup.contents, "count", expected)
            }
            verify(window.settings.setContainerHiddenEntries("item:downloads", pass === 0 ? [hiddenName] : []))
            tryCompare(popup.contents, "loading", false)
        }
        const grid = findChild(popup.contentItem, "folderGrid")
        tryCompare(grid, "count", popup.contents.count + 1)
        verify(findChild(grid, "folderOpenLocation") !== null)
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
        const location = findChild(grid, "folderOpenLocation")
        verify(location !== null)
        mouseClick(location)
        tryCompare(popup, "visible", false)
        compare(decodeURI(window.opener.calls[0]), decodeURI(popup.contents.location.toString()))
        compare(popup.contents.active, false)
        window.close()
    }
    function test_browseSubfoldersSwitchGovernsNavigation(): void {
        const settings = createTemporaryObject(Qt.createComponent("../../config/ShellSettings.qml"), test)
        // Existing profiles keep entering subfolders: the switch defaults on.
        compare(settings.container("item:downloads").browseSubfolders, true)
        compare(settings.containerBrowseSubfolders("item:downloads"), true)
        verify(settings.setContainerBrowseSubfolders("item:downloads", false))
        compare(settings.container("item:downloads").browseSubfolders, false)
        compare(settings.containerBrowseSubfolders("item:downloads"), false)
        // An unrelated edit must not lose the switch.
        verify(settings.setContainerLayout("item:downloads", "list"))
        compare(settings.containerBrowseSubfolders("item:downloads"), false)
        verify(settings.setContainerSortMode("item:downloads", "name"))
        compare(settings.containerBrowseSubfolders("item:downloads"), false)
        const restored = createTemporaryObject(Qt.createComponent("../../config/ShellSettings.qml"), test)
        verify(restored.restore(settings.snapshot()))
        compare(restored.containerBrowseSubfolders("item:downloads"), false)
        // A stored value of another type is not a valid container.
        verify(restored.restore({version: 7, downloadsView: "grid",
            containers: [{id: "downloads", path: "", title: "Downloads",
                icon: "folder-downloads", layout: "grid", sortMode: "modified"}]}))
        compare(restored.containerBrowseSubfolders("item:downloads"), true)
    }
    function test_folderSelectionOpensInsteadOfEnteringWhenDisabled(): void {
        const window = openWindow("bottom")
        const popup = window.popup
        verify(popup.contents.count >= 3)
        verify(window.settings.setContainerBrowseSubfolders("item:downloads", false))
        tryVerify(function() { return !popup.controller.browseSubfolders })
        const grid = findChild(popup.contentItem, "folderGrid")
        const nested = row(popup.contents, "nested")
        verify(nested >= 0)
        const entry = findChild(grid, "folderGridEntry-" + nested)
        verify(entry !== null)
        mouseClick(entry)
        // The directory is opened where it lives; the popup never replaces its
        // contents with the subfolder.
        tryCompare(popup, "opened", false)
        compare(window.opener.calls.length, 1)
        verify(decodeURI(window.opener.calls[0]).endsWith("/nested"))
        compare(popup.controller.history.length, 0)
        window.close()
    }
    function test_fanNeverEntersASubfolder(): void {
        const window = openWindow("bottom")
        const popup = window.popup
        verify(window.settings.setContainerLayout("item:downloads", "fan"))
        tryCompare(popup.contentItem, "viewMode", "fan")
        compare(popup.controller.browseSubfolders, true)
        const fanView = findChild(popup.contentItem, "folderFanView")
        tryVerify(function() { return fanView.visible && fanView.entryCount > 0 })
        const nested = row(popup.contents, "nested")
        verify(nested >= 0)
        let entry = null
        tryVerify(function() {
            entry = findChild(fanView, "folderFanEntry-" + nested)
            return entry !== null
        })
        mouseClick(entry)
        // The arc is a leaf even with the switch on: a directory opens in the
        // file manager and the popup closes.
        tryCompare(popup, "opened", false)
        compare(window.opener.calls.length, 1)
        verify(decodeURI(window.opener.calls[0]).endsWith("/nested"))
        compare(popup.controller.history.length, 0)
        // The switch is untouched by the arc.
        compare(window.settings.containerBrowseSubfolders("item:downloads"), true)
        window.close()
    }
    function test_detailsPanelOffersTheSwitchOnlyForFolders(): void {
        const fixture = createTemporaryObject(settingsFixture, test)
        verify(waitForRendering(fixture))
        const selector = findChild(fixture.view, "folderViewSetting")
        verify(selector !== null)
        // Nothing selected: the container block keeps its switch away.
        verify(!findChild(fixture.view, "itemDetailsType").text.endsWith("Folder"))
        mouseClick(findChild(fixture.view, "configuredItem-item:downloads"))
        compare(findChild(fixture.view, "itemDetailsType").text, "Folder")
        const browse = findChild(fixture.view, "containerBrowseSubfolders")
        verify(browse !== null)
        compare(browse.text, "Browse subfolders")
        compare(browse.checked, true)
        capture(fixture.view, "settings")
        // The switch is a keyboard-reachable control: Space toggles it and the
        // draft follows, leaving the saved profile alone until Apply.
        browse.forceActiveFocus(Qt.TabFocusReason)
        keyClick(Qt.Key_Space)
        compare(fixture.view.settings.containerBrowseSubfolders("item:downloads"), false)
        compare(browse.checked, false)
        compare(fixture.editor.settings.containerBrowseSubfolders("item:downloads"), true)
        mouseClick(findChild(fixture.view, "applyDockSettings"))
        compare(fixture.editor.settings.containerBrowseSubfolders("item:downloads"), false)
        // Trash has no container, so its details offer no subfolder switch and
        // no entry list.
        mouseClick(findChild(fixture.view, "configuredItem-item:trash"))
        compare(findChild(fixture.view, "itemDetailsType").text, "Trash")
        compare(browse.checked, true)
        verify(!findChild(fixture.view, "detailsEntrySelection").visible)
        // A folder offers the list that decides what its popup shows.
        mouseClick(findChild(fixture.view, "configuredItem-item:downloads"))
        const selection = findChild(fixture.view, "detailsEntrySelection")
        verify(selection.visible)
        const entries = findChild(selection, "folderEntrySelectionList")
        tryVerify(function() { return entries.count > 0 })
        compare(findChild(selection, "folderEntrySelectionCount").text, "All shown")
    }
    function test_listDetailFileAndRejectedDispatch(): void {
        const window = openWindow("bottom")
        chooseView(window, 1)
        const list = findChild(window.popup.contentItem, "folderList")
        verify(list.visible)
        verify(waitForRendering(window.popup.contentItem))
        capture(window.popup.contentItem, "list")
        const openLocation = findChild(list, "folderOpenLocation")
        verify(openLocation !== null && openLocation.visible)
        verify(openLocation.locationAction)
        compare(findChild(openLocation, "folderEntryIcon").source, "folder-open")
        compare(openLocation.text, "Open")
        chooseView(window, 2)
        verify(findChild(list, "folderOpenLocation").visible)
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

    function test_listWidthFollowsTheRestingLabelCap(): void {
        const window = openWindow("bottom")
        chooseView(window, 1)
        const content = window.popup.contentItem
        const longName = "A deliberately long folder popup filename for marquee.txt"
        const cap = Math.ceil(nameFontMetrics.advanceWidth("MMMMMMMMMM"))
        const nameWidth = Math.ceil(nameFontMetrics.advanceWidth(longName))
        verify(nameWidth > cap, "the fixture name must exceed the resting cap")
        verify(content.browseSubfolders)
        const chevron = Kirigami.Units.iconSizes.small + Kirigami.Units.largeSpacing
        const chrome = content.inset * 2 + content.scrollGutter
        function ask(chevronWidth: real): real {
            return Math.min(cap, nameWidth) + chevronWidth
                + content.metrics.listIconSize + Kirigami.Units.largeSpacing * 4
        }
        // The surface asks for the capped name plus the chevron column the
        // navigable directory paints, never for the whole name.
        fuzzyCompare(content.listNaturalWidth, ask(chevron), 1)
        fuzzyCompare(content.implicitWidth, Math.min(content.maximumWidth,
            Math.max(Kirigami.Units.gridUnit * 16, ask(chevron) + chrome)), 1)
        verify(content.implicitWidth < Math.min(content.maximumWidth,
            Math.max(Kirigami.Units.gridUnit * 16, nameWidth
                + content.metrics.listIconSize + Kirigami.Units.largeSpacing * 4 + chrome)),
            "the whole name must not reserve room no row can paint")
        // Without the browser there is no chevron column to reserve.
        verify(window.settings.setContainerBrowseSubfolders("item:downloads", false))
        tryCompare(content, "browseSubfolders", false)
        fuzzyCompare(content.listNaturalWidth, ask(0), 1)
        fuzzyCompare(content.listNaturalWidth + chevron, ask(chevron), 1)
        // A narrower surface still leaves the long name to the existing carousel.
        const list = findChild(content, "folderList")
        const longIndex = row(window.popup.contents, longName)
        verify(longIndex >= 0)
        const rowEntry = findChild(list, "folderListEntry-" + longIndex)
        const rowLabel = findChild(rowEntry, "folderEntryNameLabel")
        verify(rowEntry !== null && rowLabel !== null)
        tryCompare(rowLabel, "overflowing", true)
        mouseMove(rowEntry, rowEntry.width / 2, rowEntry.height / 2)
        tryVerify(function() { return rowLabel.scrollOffset < -1 })
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

    function test_captureEmphasisStates(): void {
        // Developer preview of the two native bands; normal CTest skips it.
        if (!captureDirectory) return
        const window = openWindow("bottom")
        const content = window.popup.contentItem
        chooseView(window, 1)
        tryCompare(window.popup.contents, "loading", false)
        const list = findChild(content, "folderList")
        const hovered = row(window.popup.contents, "old.txt")
        const entry = findChild(list, "folderListEntry-" + hovered)
        tryVerify(function() { return entry.visible })
        mouseMove(entry, entry.width / 2, entry.height / 2)
        tryCompare(entry, "hovered", true)
        tryVerify(function() {
            return Math.abs(entry.background.color.a - content.metrics.hoverAlpha) < 0.01
        })
        wait(200)
        verify(waitForRendering(content))
        capture(content, "list-hover")
        content.selectRow(row(window.popup.contents, "newest.txt"))
        tryCompare(content, "pointerEmphasis", false)
        // Let the pointer band finish fading before the preview is taken.
        wait(200)
        verify(waitForRendering(content))
        capture(content, "list-keyboard")
        window.close()
    }
    function test_oneEmphasisBandAtATime(): void {
        const window = openWindow("bottom")
        chooseView(window, 1)
        const content = window.popup.contentItem
        tryCompare(window.popup.contents, "loading", false)
        const list = findChild(content, "folderList")
        const hoveredIndex = row(window.popup.contents, "old.txt")
        const currentIndex = row(window.popup.contents, "newest.txt")
        verify(hoveredIndex >= 0 && currentIndex >= 0, "hovered=" + hoveredIndex
            + " current=" + currentIndex + " count=" + window.popup.contents.count
            + " entryCount=" + content.entryCount)
        const hoveredRow = findChild(list, "folderListEntry-" + hoveredIndex)
        const currentRow = findChild(list, "folderListEntry-" + currentIndex)
        verify(hoveredRow !== null && currentRow !== null)
        tryVerify(function() { return hoveredRow.visible })
        // Opening leaves the listing unbanded: the pointer owns the emphasis and
        // no row is hovered yet.
        compare(content.pointerEmphasis, true)
        compare(currentRow.background.color.a, 0)
        mouseMove(hoveredRow, hoveredRow.width / 2, hoveredRow.height / 2)
        tryCompare(hoveredRow, "hovered", true)
        tryCompare(content, "pointerEmphasis", true)
        // Pointer band: the native third of the hover colour with its hairline.
        tryVerify(function() {
            return Math.abs(hoveredRow.background.color.a - content.metrics.hoverAlpha) < 0.01
        })
        compare(hoveredRow.background.border.width, content.metrics.rowBorderWidth)
        compare(hoveredRow.background.border.color, content.metrics.rowHoverBorderColor)
        // The keyboard takes the emphasis back: the current row paints the solid
        // highlight and the pointer row drops its band, so only one shows.
        content.selectRow(currentIndex)
        tryCompare(content, "pointerEmphasis", false)
        tryVerify(function() { return currentRow.background.color.a > 0.99 }, 5000,
            "the keyboard band never reached the theme highlight")
        compare(currentRow.background.color, content.metrics.rowSelectedColor)
        compare(currentRow.background.border.width, content.metrics.rowBorderWidth)
        tryVerify(function() { return hoveredRow.background.color.a < 0.01 })
        compare(hoveredRow.background.border.width, 0)
        // Moving the pointer again returns the band to it.
        mouseMove(hoveredRow, hoveredRow.width / 3, hoveredRow.height / 2)
        tryCompare(content, "pointerEmphasis", true)
        tryVerify(function() {
            return Math.abs(hoveredRow.background.color.a - content.metrics.hoverAlpha) < 0.01
        })
        // The keyboard band fades out with the same curve.
        tryVerify(function() { return currentRow.background.color.a < 0.01 })
        window.close()
    }
    function test_reloadDuringPresentationSwitchKeepsTheView(): void {
        // A listing that reloads while the popup is laid out used to write the
        // current index inside the model change, which crashed the view.
        const window = openWindow("bottom")
        const popup = window.popup
        const content = popup.contentItem
        const grid = findChild(content, "folderGrid")
        verify(grid !== null)
        for (let step = 0; step < 4; ++step) {
            chooseView(window, step % 3)
            verify(window.settings.setContainerSortMode("item:downloads",
                step % 2 === 0 ? "name" : "modified"))
            tryCompare(popup.contents, "loading", false)
            verify(content.entryCount >= 3)
            tryVerify(function() { return grid.currentIndex >= 0 })
        }
        compare(popup.opened, true)
        verify(content.implicitHeight > 0)
        window.close()
    }
    function test_scrollGutterExistsOnlyWhileTheContentScrolls(): void {
        const window = openWindow("bottom")
        const content = window.popup.contentItem
        chooseView(window, 1)
        tryCompare(content, "scrollRequired", false)
        compare(content.scrollGutter, 0)
        const bar = findChild(findChild(content, "folderList"), "popupScrollBar")
        verify(bar !== null)
        compare(bar.thickness, content.metrics.indicatorThickness)
        const rowHeight = content.rowHeight
        content.maximumHeight = content.chromeHeight + rowHeight * 2
        tryCompare(content, "scrollRequired", true)
        verify(content.scrollGutter >= content.metrics.indicatorThickness)
        fuzzyCompare(content.contentHeight, rowHeight * 2, 0.5)
        verify(content.implicitHeight <= content.maximumHeight + 0.5)
        // The indicator rests invisible until the view moves.
        tryCompare(bar, "opacity", 0)
        window.close()
    }
    function test_browsableDirectoriesShowAChevron(): void {
        const window = openWindow("bottom")
        const content = window.popup.contentItem
        const grid = findChild(content, "folderGrid")
        const nested = row(window.popup.contents, "nested")
        verify(nested >= 0)
        const gridRow = findChild(grid, "folderGridEntry-" + nested)
        verify(!findChild(gridRow, "folderEntryChevron").visible)
        chooseView(window, 1)
        const list = findChild(content, "folderList")
        const directoryRow = findChild(list, "folderListEntry-" + nested)
        const fileRow = findChild(list, "folderListEntry-" + row(window.popup.contents, "newest.txt"))
        tryVerify(function() { return directoryRow.visible })
        verify(findChild(directoryRow, "folderEntryChevron").visible)
        verify(!findChild(fileRow, "folderEntryChevron").visible)
        // Turning the switch off opens directories where they live, so the
        // affordance disappears with it.
        verify(window.settings.setContainerBrowseSubfolders("item:downloads", false))
        tryVerify(function() { return !findChild(directoryRow, "folderEntryChevron").visible })
        window.close()
    }
    function test_entryMenuCopiesThePathAndOpensTheDirectory(): void {
        const window = openWindow("bottom")
        const content = window.popup.contentItem
        chooseView(window, 1)
        const list = findChild(content, "folderList")
        const nested = row(window.popup.contents, "nested")
        verify(nested >= 0)
        const entry = findChild(list, "folderListEntry-" + nested)
        verify(entry !== null)
        tryVerify(function() { return entry.visible })
        mouseClick(entry, entry.width / 2, entry.height / 2, Qt.RightButton)
        const menu = findChild(content, "folderEntryMenu")
        tryCompare(menu, "visible", true)
        tryCompare(menu, "visible", true)
        const copy = findChild(menu, "folderEntryCopyPath")
        verify(copy !== null && copy.enabled)
        mouseClick(copy)
        tryCompare(menu, "visible", false)
        compare(window.copier.paths.length, 1)
        verify(window.copier.paths[0].endsWith("/nested"))
        compare(window.opener.calls.length, 0)
        mouseClick(entry, entry.width / 2, entry.height / 2, Qt.RightButton)
        tryCompare(menu, "visible", true)
        mouseClick(findChild(menu, "folderEntryOpenLocation"))
        tryCompare(window.popup, "opened", false)
        compare(window.opener.calls.length, 1)
        verify(decodeURI(window.opener.calls[0]).endsWith("/nested"))
        window.close()
    }
    function test_popupIconSizesFollowEachPresentation(): void {
        const window = openWindow("bottom")
        const content = window.popup.contentItem
        const fan = findChild(content, "folderFanView")
        compare(content.gridIconSize, Kirigami.Units.iconSizes.large)
        compare(content.metrics.listIconSize, Kirigami.Units.iconSizes.medium)
        compare(content.metrics.fanIconSize, Kirigami.Units.iconSizes.large)
        window.settings.popupIconSize = 64
        tryCompare(content, "gridIconSize", 64)
        // The rows and the arc keep their own glyph instead of inheriting it.
        compare(content.metrics.listIconSize, Kirigami.Units.iconSizes.medium)
        compare(content.metrics.fanIconSize, Kirigami.Units.iconSizes.large)
        tryCompare(fan, "iconSize", Kirigami.Units.iconSizes.large)
        window.settings.popupFanIconSize = 34
        tryCompare(content.metrics, "fanIconSize", 34)
        tryCompare(fan, "iconSize", 34)
        compare(content.gridIconSize, 64)
        window.settings.popupListIconSize = 40
        tryCompare(content.metrics, "listIconSize", 40)
        compare(content.gridIconSize, 64)
        compare(content.metrics.fanIconSize, 34)
        window.close()
    }
    function test_popupAppearanceFollowsTheSettings(): void {
        const window = openWindow("bottom")
        const content = window.popup.contentItem
        compare(content.metrics.scale, 1)
        compare(content.gridIconSize, 48)
        const rowHeight = content.rowHeight
        window.settings.popupScale = 1.2
        window.settings.popupIconSize = 64
        tryCompare(content, "gridIconSize", Math.round(64 * 1.2))
        verify(content.rowHeight > rowHeight)
        chooseView(window, 1)
        verify(content.rowHeight > rowHeight)
        verify(window.popup.height > 0)
        window.close()
    }
}
