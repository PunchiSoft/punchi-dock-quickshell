// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import org.kde.kirigami as Kirigami
import "../../config"
import "../../services"
import "../../modules/settings"

TestCase {
    id: test
    name: "SettingsEditing"
    when: windowShown
    Component { id: fixture; SettingsWindow { settings: ShellSettings {} } }
    Component {
        id: populatedWindowFixture
        SettingsWindow { settings: ShellSettings {} applicationCatalog: DockFixtureModel {} }
    }
    Component { id: serviceFixture; SettingsEditService { settings: ShellSettings {} } }
    Component { id: pinsFixture; PinnedApplications { catalog: DockFixtureModel {} pinnedIds: [] } }

    function init(): void {
        // Offscreen QPA cannot raise a real window; keep its diagnostic visible.
        failOnWarning(/^(?!This plugin does not support raise\(\)$).*/)
    }
    function openWindow(): var {
        const window = createTemporaryObject(fixture, test)
        window.open()
        tryCompare(window, "visible", true)
        verify(waitForRendering(window.contentItem))
        return window
    }
    function control(window: var, name: string): var {
        const item = findChild(window.contentItem, name)
        verify(item !== null, name)
        return item
    }
    function test_applyAcceptCloseAndKeyboard(): void {
        const window = openWindow()
        const view = control(window, "dockSettingsView")
        const apply = control(window, "applyDockSettings")
        const toggle = control(window, "magnification")
        verify(!apply.enabled)
        mouseClick(toggle)
        compare(view.settings.magnificationEnabled, false)
        compare(window.settings.magnificationEnabled, true)
        verify(window.hasPendingChanges)
        verify(apply.enabled)
        mouseClick(apply)
        compare(window.settings.magnificationEnabled, false)
        verify(window.visible)
        verify(!apply.enabled)
        mouseClick(control(window, "bounceEnabled"))
        mouseClick(control(window, "closeDockSettings"))
        tryCompare(window, "visible", false)
        compare(window.settings.bounceEnabled, true)
        window.open()
        verify(waitForRendering(window.contentItem))
        compare(view.settings.bounceEnabled, true)
        compare(view.settings.magnificationEnabled, false)
        toggle.forceActiveFocus(Qt.TabFocusReason)
        keyClick(Qt.Key_Space)
        compare(window.settings.magnificationEnabled, false)
        const accept = control(window, "acceptDockSettings")
        accept.forceActiveFocus(Qt.TabFocusReason)
        keyClick(Qt.Key_Space)
        tryCompare(window, "visible", false)
        compare(window.settings.magnificationEnabled, true)
        window.open()
        verify(waitForRendering(window.contentItem))
        mouseClick(toggle)
        keyClick(Qt.Key_Escape)
        tryCompare(window, "visible", false)
        compare(window.settings.magnificationEnabled, true)
    }
    function test_resetPendingAndReopen(): void {
        const window = openWindow()
        const view = control(window, "dockSettingsView")
        window.settings.sizePercent = 150
        window.settings.panelMode = "desktop"
        window.settings.pinnedIds = ["files", "browser"]
        compare(view.settings.sizePercent, 150)
        mouseClick(control(window, "resetDockSettings"))
        compare(view.settings.sizePercent, 100)
        compare(view.settings.pinnedIds.length, 8)
        compare(window.settings.sizePercent, 150)
        compare(window.settings.pinnedIds.length, 2)
        // A repeated Configure action raises the existing editor without losing edits.
        window.open()
        compare(view.settings.sizePercent, 100)
        verify(window.hasPendingChanges)
        window.close()
        window.open()
        verify(waitForRendering(window.contentItem))
        compare(view.settings.sizePercent, 150)
        compare(view.settings.pinnedIds.length, 2)
        verify(!window.hasPendingChanges)
        mouseClick(control(window, "resetDockSettings"))
        mouseClick(control(window, "applyDockSettings"))
        compare(window.settings.sizePercent, 100)
        compare(window.settings.panelMode, "overlay")
        compare(window.settings.pinnedIds.length, 8)
        window.close()
    }
    function test_externalChangesAndLivePinnedConsumer(): void {
        const editor = createTemporaryObject(serviceFixture, test)
        const pins = createTemporaryObject(pinsFixture, test)
        pins.pinnedIds = Qt.binding(() => editor.settings.pinnedIds)
        editor.begin()
        editor.draft.sizePercent = 125
        editor.draft.pinnedIds = ["files"]
        compare(pins.count, 8)
        editor.settings.panelMode = "desktop"
        compare(editor.draft.panelMode, "dodge-windows")
        compare(editor.draft.sizePercent, 125)
        editor.apply()
        compare(editor.settings.sizePercent, 125)
        compare(editor.settings.panelMode, "dodge-windows")
        compare(pins.count, 1)
        verify(!editor.dirty)
        editor.draft.sizePercent = 140
        editor.settings.sizePercent = 150
        compare(editor.draft.sizePercent, 140)
        editor.settings.bounceEnabled = false
        editor.apply()
        compare(editor.settings.sizePercent, 140)
        compare(editor.settings.bounceEnabled, false)
        editor.draft.maximumIconScale = 3
        editor.settings.maximumIconScale = 3
        verify(!editor.dirty)
        editor.draft.pinnedIds = []
        editor.cancel()
        compare(pins.count, 1)
        compare(editor.draft.pinnedIds.length, 1)
        verify(!editor.dirty)
    }
    function test_sidebarAndFooterGeometry(): void {
        const window = openWindow()
        const view = control(window, "dockSettingsView")
        const sidebar = control(window, "settingsSidebar")
        const main = control(window, "settingsMainContent")
        compare(sidebar.width, Kirigami.Units.gridUnit * 8)
        verify(sidebar.x + sidebar.width <= main.x)
        verify(main.width > sidebar.width * 2)
        mouseClick(control(window, "itemsSettingsPage"))
        compare(view.currentPage, 0)
        const add = control(window, "addDockApplication")
        compare(add.text, "Add Item")
        compare(add.icon.name, "list-add")
        const addPosition = add.mapToItem(view, 0, 0)
        const mainPosition = main.mapToItem(view, 0, 0)
        verify(Math.abs(addPosition.x - mainPosition.x) <= 1)
        const reset = control(window, "resetDockSettings")
        const apply = control(window, "applyDockSettings")
        const accept = control(window, "acceptDockSettings")
        const close = control(window, "closeDockSettings")
        const resetPosition = reset.mapToItem(view, 0, 0)
        verify(Math.abs(resetPosition.x - mainPosition.x) <= 1)
        verify(resetPosition.y > addPosition.y)
        verify(apply.x < accept.x && accept.x < close.x)
        verify(close.mapToItem(view, close.width, 0).x <= view.width)
        window.width = window.minimumWidth
        verify(waitForRendering(window.contentItem))
        verify(close.mapToItem(view, close.width, 0).x <= view.width)
        mouseClick(control(window, "generalSettingsPage"))
        compare(view.currentPage, 1)
        tryCompare(control(window, "visibilityMode"), "activeFocus", true)
        window.close()
    }
    function test_reorderButtonsPendingApplyAndDiscard(): void {
        const window = createTemporaryObject(populatedWindowFixture, test)
        window.open()
        verify(waitForRendering(window.contentItem))
        const view = control(window, "dockSettingsView")
        mouseClick(control(window, "itemsSettingsPage"))
        const list = control(window, "settingsDockItems")
        const up = control(window, "moveDockItemUp")
        const down = control(window, "moveDockItemDown")
        const pins = createTemporaryObject(pinsFixture, test)
        pins.pinnedIds = Qt.binding(() => window.settings.pinnedIds)
        verify(!up.enabled)
        verify(down.enabled)
        const files = control(window, "configuredItem-files")
        mouseClick(files)
        mouseClick(down)
        compare(view.settings.pinnedIds[1], "files")
        compare(list.currentIndex, 1)
        verify(files.highlighted)
        compare(pins.get(0).appId, "files")
        up.forceActiveFocus(Qt.TabFocusReason)
        keyClick(Qt.Key_Space)
        compare(view.settings.pinnedIds[0], "files")
        verify(!up.enabled)
        verify(!window.hasPendingChanges)
        list.forceActiveFocus(Qt.TabFocusReason)
        keyClick(Qt.Key_Down)
        compare(list.currentIndex, 1)
        mouseClick(up)
        compare(view.settings.pinnedIds[0], "terminal")
        mouseClick(control(window, "applyDockSettings"))
        compare(pins.get(0).appId, "terminal")
        verify(window.visible)
        verify(!window.hasPendingChanges)
        for (let step = 0; step < 7; ++step) mouseClick(down)
        compare(view.settings.pinnedIds[7], "terminal")
        compare(list.currentIndex, 7)
        verify(!down.enabled)
        mouseClick(control(window, "closeDockSettings"))
        window.open()
        verify(waitForRendering(window.contentItem))
        compare(view.settings.pinnedIds[0], "terminal")
        compare(pins.get(0).appId, "terminal")
        window.close()
    }
}
