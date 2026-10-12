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
            ShellSettings { id: settings }
            ApplicationCatalog { id: catalog }
            SettingsView {
                id: view
                width: 850
                height: 650
                currentPage: 0
                settings: settings
                applicationCatalog: catalog
            }
            PinnedApplications { id: pinned; catalog: catalog; pinnedIds: settings.pinnedIds }
            DockView {
                id: dock
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                entries: pinned
                magnificationEnabled: false
                onItemActivated: function(appId) { launcher.launch(appId) }
            }
            Native.DesktopLauncher { id: adapter; activationItem: dock }
            ApplicationLaunchService { id: launcher; entries: pinned; adapter: adapter }
        }
    }
    Component { id: settingsFixture; ShellSettings {} }
    Component { id: serviceFixture; ApplicationPinService { settings: null; catalog: null } }
    SignalSpy { id: completion; signalName: "launchCompleted" }
    function init() {
        // The isolated bus has no systemd user manager; retain its known KIO warning.
        failOnWarning(/^(?!Failed to determine systemd version, falling back to extremely legacy forking mode\.$).*/)
    }
    function openEditor(view: Item): var {
        verify(waitForRendering(view))
        const add = findChild(view, "addDockApplication")
        verify(add.enabled)
        mouseClick(add)
        const dialog = findChild(view, "addApplicationDialog")
        tryCompare(dialog, "opened", true)
        verify(dialog.width > 0 && dialog.height > 0, "geometry " + [dialog.width, dialog.height, dialog.implicitHeight, dialog.hostWidth, dialog.hostHeight, dialog.parent].join(" / "))
        return dialog
    }
    function selectOwned(dialog: var): void {
        const search = findChild(dialog, "applicationSearch")
        mouseClick(search)
        keyClick(Qt.Key_A, Qt.ControlModifier)
        for (const character of "punchi-add-sentinel") keyClick(character)
        const results = findChild(dialog, "applicationSearchResults")
        tryCompare(results, "count", 1)
        tryVerify(function() { return findChild(results, "applicationResult-desktop:punchi-add-sentinel.desktop") !== null })
        const row = findChild(results, "applicationResult-desktop:punchi-add-sentinel.desktop")
        mouseClick(row)
    }
    function test_draftAcceptCancelAndNativeLaunch() {
        const window = createTemporaryObject(fixture, test)
        const view = window.settingsView
        tryVerify(function() { return window.catalog.application("desktop:punchi-add-sentinel.desktop").installed === true })
        tryCompare(window.dock, "itemCount", 8)
        const initial = window.settings.pinnedIds.join(",")
        let dialog = null
        for (let cycle = 0; cycle < 4; ++cycle) {
            dialog = openEditor(view)
            verify(!findChild(dialog, "confirmAddApplication").enabled)
            selectOwned(dialog)
            verify(findChild(dialog, "confirmAddApplication").enabled)
            compare(window.settings.pinnedIds.join(","), initial)
            mouseClick(findChild(dialog, "discardAddApplication"))
            tryCompare(dialog, "visible", false)
            compare(window.settings.pinnedIds.join(","), initial)
            tryCompare(findChild(view, "addDockApplication"), "activeFocus", true)
        }
        dialog = openEditor(view)
        selectOwned(dialog)
        mouseClick(findChild(dialog, "confirmAddApplication"))
        tryCompare(dialog, "visible", false)
        tryCompare(window.dock, "itemCount", 9)
        compare(window.settings.pinnedIds[8], "desktop:punchi-add-sentinel.desktop")
        const restored = createTemporaryObject(settingsFixture, test)
        verify(restored.restore(JSON.parse(JSON.stringify(window.settings.snapshot()))))
        compare(restored.pinnedIds.join(","), window.settings.pinnedIds.join(","))
        const addedPins = restored.pinnedIds.join(",")
        restored.restore({version: 1, pinnedIds: ["desktop:/tmp/unsafe.desktop"]})
        compare(restored.pinnedIds.join(","), addedPins)
        dialog = openEditor(view)
        selectOwned(dialog)
        verify(!findChild(dialog, "confirmAddApplication").enabled)
        keyClick(Qt.Key_Escape)
        tryCompare(dialog, "visible", false)
        compare(window.settings.pinnedIds.length, 9)
        completion.target = window.launch
        completion.clear()
        const tile = findChild(window.dock, "launcher-desktop:punchi-add-sentinel.desktop")
        verify(tile !== null)
        mouseClick(tile)
        tryCompare(completion, "count", 1)
        compare(completion.signalArguments[0][0], "punchi-add-sentinel.desktop")
        compare(completion.signalArguments[0][1], true)
        window.settings.reset()
        tryCompare(window.dock, "itemCount", 8)
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
        compare(window.settings.pinnedIds.length, 8)
        window.close()
    }

}
