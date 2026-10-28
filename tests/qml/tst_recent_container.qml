// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import org.kde.kirigami as Kirigami
import Punchi.Kde as Native
import "../../modules/recent"
import "../../modules/dock"
import "../../components"
import "../../config"
import "../../services"

TestCase {
    id: test
    name: "RecentApplicationsContainer"
    when: windowShown
    visible: true
    width: 820
    height: 780

    signal activated(string appId)
    SignalSpy { id: activationSpy; target: test; signalName: "activated" }

    Component {
        id: fixture
        Window {
            id: window
            width: 760; height: 740
            visible: true
            property alias popup: popup
            property alias source: source
            property alias settings: settings
            property alias selection: selection
            property alias recentSource: recentSource
            ListModel {
                id: recentSource
                ListElement { storageId: "org.kde.kate.desktop"; name: "Kate"; icon: "kate" }
                ListElement { storageId: "org.kde.gwenview.desktop"; name: "Gwenview"; icon: "gwenview" }
                ListElement { storageId: "org.kde.okular.desktop"; name: "Okular"; icon: "okular" }
            }
            Native.RecentApplicationsModel {
                id: selection
                enabled: true
                sourceModel: recentSource
                maximumItems: 20
            }
            ShellSettings { id: settings }
            Item {
                anchors.fill: parent
                LauncherTile {
                    id: source
                    x: 340; y: 640
                    title: "Recent applications"; iconName: "folder-temp"; appId: "item:recent"
                    reducedMotion: true
                    onActivated: popup.toggleForItem(source, false)
                }
                RecentApplicationsPopup {
                    id: popup
                    hostWindow: window
                    settings: settings
                    selection: selection
                    onActivateRequested: function(appId) { test.activated(appId) }
                }
            }
        }
    }
    Component {
        id: contentFixture
        Item {
            width: 460; height: 420
            property alias content: content
            property alias selection: selection
            Native.RecentApplicationsModel {
                id: selection
                enabled: true
                sourceModel: ListModel {}
            }
            RecentApplicationsContent {
                id: content
                anchors.fill: parent
                selection: selection
                maximumWidth: parent.width
                maximumHeight: parent.height
                reducedMotion: true
            }
        }
    }
    Component {
        id: menuFixture
        DockContextContent {
            id: menu
            property var layouts: []
            recentContainer: true
            recentContainerLayout: "list"
            settings: ShellSettings {}
            onRecentLayoutRequested: function(layout) { menu.layouts = menu.layouts.concat([layout]) }
        }
    }

    // The catalogue fills itself asynchronously, so the exclusion list has to
    // follow the revision a late-loaded preset row announces.
    Component {
        id: exclusionFixture
        Item {
            property alias recent: recent
            property alias catalog: catalog
            QtObject {
                id: catalog
                property int revision: 0
                property var desktopIds: ({})
                function application(appId) {
                    return desktopIds[appId]
                        ? ({appId: appId, desktopId: desktopIds[appId]}) : null
                }
            }
            QtObject {
                id: preferences
                property bool recentApplicationsEnabled: false
                property int recentApplicationsCount: 5
                property var pinnedIds: ["files"]
            }
            RecentApplications {
                id: recent
                settings: preferences
                catalog: catalog
                runningDesktopIds: ["org.kde.kate.desktop"]
            }
        }
    }

    function init(): void { failOnWarning(/.*/) }

    function openWindow(view: string): var {
        const window = createTemporaryObject(fixture, test)
        verify(window !== null)
        if (view) window.settings.recentApplicationsContainerLayout = view
        verify(waitForRendering(window.contentItem))
        mouseClick(window.source)
        tryCompare(window.popup, "opened", true)
        return window
    }

    function test_defaultSettingsOpenTheList(): void {
        const window = openWindow("")
        const popup = window.popup
        const content = popup.contentItem
        compare(window.settings.recentApplicationsContainerLayout, "list")
        compare(content.viewMode, "list")
        compare(content.entryCount, 3)
        compare(content.selection.get(0).entryName, "Kate")
        const list = findChild(content, "recentApplicationsList")
        verify(list !== null)
        verify(list.visible)
        tryCompare(list, "count", 3)
        const first = findChild(list, "recentApplicationRow-0")
        verify(first !== null)
        compare(first.text, "Kate")
        verify(findChild(content, "recentApplicationsEmpty") !== null)
        verify(!findChild(content, "recentApplicationsEmpty").visible)
        window.close()
    }

    function test_listRowLaunchesItsApplication(): void {
        const window = openWindow("list")
        const content = window.popup.contentItem
        const list = findChild(content, "recentApplicationsList")
        tryCompare(list, "count", 3)
        tryVerify(function() { return findChild(list, "recentApplicationRow-1") !== null })
        activationSpy.clear()
        mouseClick(findChild(list, "recentApplicationRow-1"))
        compare(activationSpy.count, 1)
        compare(activationSpy.signalArguments[0][0], "desktop:org.kde.gwenview.desktop")
        window.close()
    }

    function test_detailRowsKeepTheSameEntries(): void {
        const window = openWindow("detail")
        const content = window.popup.contentItem
        compare(content.viewMode, "detail")
        const list = findChild(content, "recentApplicationsList")
        tryCompare(list, "count", 3)
        const row = findChild(list, "recentApplicationRow-0")
        verify(row !== null)
        verify(row.detailed)
        verify(content.rowHeight > content.listRowHeight)
        compare(row.height, content.rowHeight)
        window.close()
    }

    function test_gridKeyboardMovesAndActivates(): void {
        const window = openWindow("grid")
        const content = window.popup.contentItem
        const grid = findChild(content, "recentApplicationsGrid")
        verify(grid.visible)
        tryCompare(grid, "count", 3)
        const first = findChild(grid, "recentApplicationEntry-0")
        verify(first !== null)
        tryCompare(first, "activeFocus", true)
        keyClick(Qt.Key_Right)
        const second = findChild(grid, "recentApplicationEntry-1")
        verify(second !== null)
        tryCompare(second, "activeFocus", true)
        activationSpy.clear()
        keyClick(Qt.Key_Return)
        compare(activationSpy.count, 1)
        compare(activationSpy.signalArguments[0][0], "desktop:org.kde.gwenview.desktop")
        window.close()
    }

    function test_fanPresentationUnfoldsTheArc(): void {
        const window = openWindow("fan")
        const content = window.popup.contentItem
        compare(content.fanMode, true)
        const fan = findChild(content, "recentApplicationsFan")
        verify(fan !== null)
        verify(fan.visible)
        tryCompare(fan, "entryCount", 3)
        compare(fan.hasLocationAction, false)
        // The arc starts on the row that faces the panel, without a keyboard band
        // painted by a pointer opening.
        tryVerify(function() { return fan.focusedOrder >= 0 })
        verify(window.popup.width > 0)
        window.close()
    }

    function test_emptySelectionShowsTheEmptyState(): void {
        const fixtureItem = createTemporaryObject(contentFixture, test)
        verify(fixtureItem !== null)
        tryCompare(fixtureItem.content, "entryCount", 0)
        const empty = findChild(fixtureItem.content, "recentApplicationsEmpty")
        verify(empty !== null)
        verify(empty.visible)
        compare(empty.text, "Empty")
        // The surface keeps the header instead of collapsing to nothing.
        verify(fixtureItem.content.height > 0)
    }

    function test_pinnedAndRunningApplicationsLeaveTheSelection(): void {
        const item = createTemporaryObject(exclusionFixture, test)
        verify(item !== null)
        // A catalogue that has not resolved its preset rows yet excludes only
        // the running application; the pinned desktop id is still unknown.
        compare(item.recent.excludedStorageIds.length, 1)
        compare(item.recent.excludedStorageIds[0], "org.kde.kate.desktop")
        item.catalog.desktopIds = {"files": "org.kde.dolphin.desktop"}
        item.catalog.revision = item.catalog.revision + 1
        tryCompare(item.recent, "excludedStorageIds", ["org.kde.dolphin.desktop",
            "org.kde.kate.desktop"])
    }
    function test_contextMenuOffersTheContainerViews(): void {
        const menu = createTemporaryObject(menuFixture, test)
        verify(menu !== null)
        verify(waitForRendering(menu))
        const grid = findChild(menu, "recentLayout-grid")
        const list = findChild(menu, "recentLayout-list")
        const detail = findChild(menu, "recentLayout-detail")
        const fan = findChild(menu, "recentLayout-fan")
        verify(grid !== null && list !== null && detail !== null && fan !== null)
        verify(grid.visible && list.visible && detail.visible && fan.visible)
        verify(list.marked)
        verify(!grid.marked)
        // The container has nothing to sort and no folder to open.
        verify(!findChild(menu, "openFolderAction").visible)
        verify(!findChild(menu, "folderSort-name").visible)
        menu.focusFirst()
        tryCompare(grid, "activeFocus", true)
        compare(menu.layouts.length, 0)
        mouseClick(detail)
        compare(menu.layouts.length, 1)
        compare(menu.layouts[0], "detail")
    }

    function test_fanIsWithheldOnASideDock(): void {
        const menu = createTemporaryObject(menuFixture, test)
        verify(menu !== null)
        menu.settings.dockEdge = "left"
        const fan = findChild(menu, "recentLayout-fan")
        verify(fan !== null)
        tryCompare(fan, "enabled", false)
    }

    function test_closingRestoresFocusToTheContainerItem(): void {
        const window = openWindow("list")
        const popup = window.popup
        compare(popup.sourceItem, window.source)
        window.source.forceActiveFocus(Qt.PopupFocusReason)
        popup.dismiss()
        tryCompare(popup, "opened", false)
        tryCompare(window.source, "activeFocus", true)
        window.close()
    }
}
