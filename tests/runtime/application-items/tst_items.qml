// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtTest
import Punchi.Kde as Native
import "../../../config"
import "../../../services"
import "../../../modules/settings"
import "../../../modules/dock"

TestCase {
    id: test
    name: "ApplicationItems"
    when: windowShown
    Component {
        id: fixture
        Window {
            id: window
            visible: true
            width: 1000
            height: 900
            property alias settingsView: view
            property alias catalog: catalog
            property alias dock: dock
            property alias settings: settings
            property alias launch: launcher
            PunchiShellSettings { id: settings }
            Native.DockItemCatalog {
                id: catalog
                applications: PunchiApplicationCatalog {}
                containers: settings.containers
                trashTitle: "Owned Trash"
            }
            PunchiSettingsView {
                id: view
                width: 850
                height: 650
                currentPage: 0
                settings: settings
                applicationCatalog: catalog
            }
            PunchiPinnedApplications { id: pinned; catalog: catalog; pinnedIds: settings.pinnedIds }
            PunchiDockView {
                id: dock
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                entries: pinned
                magnificationEnabled: false
                onItemActivated: function(appId) { launcher.launch(appId) }
            }
            Native.DesktopLauncher { id: adapter; activationItem: dock }
            PunchiApplicationLaunchService { id: launcher; entries: pinned; adapter: adapter }
        }
    }
    Component { id: settingsFixture; PunchiShellSettings {} }
    Component { id: serviceFixture; PunchiApplicationPinService { settings: null; catalog: null } }
    SignalSpy { id: completion; signalName: "launchCompleted" }
    function init() {
        // The isolated bus has no systemd user manager; retain its known KIO warning.
        failOnWarning(/^(?!Failed to determine systemd version, falling back to extremely legacy forking mode\.$).*/)
    }
    // An idle offscreen scene may produce no further frame; wait for one when
    // available and otherwise accept a visible, laid-out view.
    function waitForFrame(view: Item): bool {
        const window = view.Window.window
        if (!window) return false
        if (waitForRendering(window.contentItem, 1000)) return true
        return window.visible && view.visible && view.width > 0 && view.height > 0
    }
    // Click a control through the window: a page-local control can report a stale
    // scene position while a layout pass is pending.
    function openEditor(view: Item): var {
        verify(waitForFrame(view))
        const add = findChild(view, "addDockItem")
        verify(add.enabled)
        mouseClick(add)
        const page = findChild(view, "addDockItemPage")
        tryCompare(view, "addingItem", true)
        verify(page.visible && page.width > 0 && page.height > 0)
        return page
    }
    function selectOwned(dialog: var): void {
        const search = findChild(dialog, "applicationSearch")
        mouseClick(search)
        keyClick(Qt.Key_A, Qt.ControlModifier)
        for (const character of "punchi-add-sentinel") keyClick(character)
        const area = findChild(dialog, "applicationResultsArea")
        tryVerify(function() { return area.active && area.item !== null })
        const results = findChild(area.item, "applicationSearchResults")
        tryCompare(results, "count", 1)
        let row = null
        tryVerify(function() {
            row = findChild(results, "applicationResult-desktop:punchi-add-sentinel.desktop")
            return row !== null
        }, 5000, "the catalog result is offered")
        mouseClick(row)
    }
    function test_draftAcceptCancelAndNativeLaunch() {
        const window = createTemporaryObject(fixture, test)
        const view = window.settingsView
        tryVerify(function() { return window.catalog.application("desktop:punchi-add-sentinel.desktop").installed === true })
        tryCompare(window.dock, "itemCount", 11)
        const initial = window.settings.pinnedIds.join(",")
        let dialog = null
        for (let cycle = 0; cycle < 4; ++cycle) {
            dialog = openEditor(view)
            verify(!findChild(dialog, "confirmAddItem").enabled)
            selectOwned(dialog)
            verify(findChild(dialog, "confirmAddItem").enabled)
            compare(window.settings.pinnedIds.join(","), initial)
            mouseClick(findChild(dialog, "cancelAddItem"))
            tryCompare(dialog, "visible", false)
            compare(window.settings.pinnedIds.join(","), initial)
            tryCompare(findChild(view, "addDockItem"), "activeFocus", true)
        }
        dialog = openEditor(view)
        selectOwned(dialog)
        mouseClick(findChild(dialog, "confirmAddItem"))
        tryCompare(dialog, "visible", false)
        tryCompare(window.dock, "itemCount", 12)
        compare(window.settings.pinnedIds[10], "desktop:punchi-add-sentinel.desktop")
        compare(window.settings.pinnedIds[11], "item:trash")
        const restored = createTemporaryObject(settingsFixture, test)
        verify(restored.restore(JSON.parse(JSON.stringify(window.settings.snapshot()))))
        compare(restored.pinnedIds.join(","), window.settings.pinnedIds.join(","))
        const addedPins = restored.pinnedIds.join(",")
        restored.restore({version: 1, pinnedIds: ["desktop:/tmp/unsafe.desktop"]})
        compare(restored.pinnedIds.join(","), addedPins)
        dialog = openEditor(view)
        selectOwned(dialog)
        verify(!findChild(dialog, "confirmAddItem").enabled)
        keyClick(Qt.Key_Escape)
        tryCompare(dialog, "visible", false)
        compare(window.settings.pinnedIds.length, 12)
        completion.target = window.launch
        completion.clear()
        const tile = findChild(window.dock, "launcher-desktop:punchi-add-sentinel.desktop")
        verify(tile !== null)
        mouseClick(tile)
        tryCompare(completion, "count", 1)
        compare(completion.signalArguments[0][0], "punchi-add-sentinel.desktop")
        compare(completion.signalArguments[0][1], true)
        window.settings.reset()
        tryCompare(window.dock, "itemCount", 11)
        window.close()
    }
    function test_hiddenAndUnknownApplicationsAreNotSelectable() {
        const window = createTemporaryObject(fixture, test)
        const controller = createTemporaryObject(serviceFixture, test)
        controller.settings = window.settings
        controller.catalog = window.catalog
        controller.select("desktop:punchi-add-hidden.desktop")
        compare(controller.canAdd, false)
        compare(controller.accept(), false)
        controller.select("desktop:/tmp/unknown.desktop")
        compare(controller.canAdd, false)
        compare(controller.accept(), false)
        controller.search("punchi-add-hidden")
        tryCompare(controller.applications, "count", 0)
        compare(window.settings.pinnedIds.length, 11)
        window.close()
    }

    function test_addContainerAndSingletonTrashCanBeRemovedAndReadded() {
        const window = createTemporaryObject(fixture, test)
        const view = window.settingsView
        tryCompare(window.dock, "itemCount", 11)

        let dialog = openEditor(view)
        dialog.itemType = "trash"
        verify(!findChild(dialog, "confirmAddItem").enabled,
            "the default Trash cannot be added twice")
        mouseClick(findChild(dialog, "cancelAddItem"))
        tryCompare(dialog, "visible", false)
        const trashRow = findChild(view, "configuredItem-item:trash")
        verify(trashRow !== null)
        const itemList = findChild(view, "settingsDockItems")
        itemList.positionViewAtIndex(itemList.count - 1, ListView.Contain)
        verify(waitForRendering(itemList))
        mouseClick(trashRow)
        compare(itemList.currentIndex, itemList.count - 1)
        mouseClick(findChild(view, "removeDockItem"))
        compare(window.settings.pinnedIds.indexOf("item:trash"), -1)
        compare(window.dock.itemCount, 10)

        dialog = openEditor(view)
        dialog.itemType = "container"
        dialog.containerPath = "/tmp/punchi-discarded-container"
        dialog.containerLayout = "list"
        // The type switch re-lays out the editor; render it before clicking so
        // the control positions are current.
        grabImage(dialog)
        mouseClick(findChild(dialog, "cancelAddItem"))
        tryCompare(dialog, "visible", false)
        compare(window.settings.containers.length, 2)
        verify(!window.settings.pinnedIds.some(id => id.indexOf("item:folder:") === 0
            && id !== "item:folder:home"))

        dialog = openEditor(view)
        dialog.itemType = "trash"
        verify(findChild(dialog, "confirmAddItem").enabled)
        mouseClick(findChild(dialog, "confirmAddItem"))
        tryCompare(dialog, "visible", false)
        compare(window.settings.pinnedIds.filter(id => id === "item:trash").length, 1)
        compare(window.dock.itemCount, 11)

        dialog = openEditor(view)
        dialog.itemType = "container"
        dialog.containerPath = "/tmp/punchi-owned-container"
        dialog.containerLayout = "detail"
        verify(findChild(dialog, "confirmAddItem").enabled)
        compare(window.settings.containers.length, 2,
            "the selected folder stays a draft until Add")
        mouseClick(findChild(dialog, "confirmAddItem"))
        tryCompare(dialog, "visible", false)
        const containerId = window.settings.pinnedIds.find(id => id.indexOf("item:folder:") === 0
            && id !== "item:folder:home")
        verify(containerId.length > 0)
        compare(window.settings.container(containerId).layout, "detail")
        compare(window.dock.itemCount, 12)
        const containerRow = findChild(view, "configuredItem-" + containerId)
        verify(containerRow !== null)
        itemList.positionViewAtIndex(itemList.count - 2, ListView.Contain)
        verify(waitForRendering(itemList))
        mouseClick(containerRow)
        mouseClick(findChild(view, "removeDockItem"))
        compare(window.settings.pinnedIds.indexOf(containerId), -1)
        compare(window.settings.container(containerId), null)
        compare(window.dock.itemCount, 11)
        window.close()
    }

}
