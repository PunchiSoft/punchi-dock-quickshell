// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import org.kde.kirigami as Kirigami
import "../../../config"
import "../../../services"
import "../../../modules/settings"

TestCase {
    id: test
    name: "ApplicationSettingsWindow"
    when: windowShown
    Component {
        id: settingsWindowFixture
        SettingsWindow {
            id: window
            settings: ShellSettings {}
            applicationCatalog: ApplicationCatalog {}
            readonly property PinnedApplications livePins: PinnedApplications {
                catalog: window.applicationCatalog
                pinnedIds: window.settings.pinnedIds
            }
        }
    }
    function init(): void {
        // Offscreen QPA cannot raise a real window; keep its diagnostic visible.
        failOnWarning(/^(?!This plugin does not support raise\(\)$).*/)
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
    function test_windowDraftAdditionApplyAcceptAndClose() {
        const window = createTemporaryObject(settingsWindowFixture, test)
        window.open()
        const view = findChild(window.contentItem, "dockSettingsView")
        view.currentPage = 0
        tryVerify(function() { return window.applicationCatalog.application("desktop:punchi-add-sentinel.desktop").installed === true })
        let dialog = openEditor(view)
        selectOwned(dialog)
        mouseClick(findChild(dialog, "confirmAddApplication"))
        tryCompare(dialog, "visible", false)
        compare(view.settings.pinnedIds.length, 9)
        compare(window.livePins.count, 8)
        verify(window.hasPendingChanges)
        mouseClick(findChild(view, "closeDockSettings"))
        tryCompare(window, "visible", false)
        compare(window.settings.pinnedIds.length, 8)
        window.open()
        verify(waitForRendering(window.contentItem))
        compare(view.settings.pinnedIds.length, 8)
        dialog = openEditor(view)
        selectOwned(dialog)
        mouseClick(findChild(dialog, "confirmAddApplication"))
        tryCompare(dialog, "visible", false)
        mouseClick(findChild(view, "applyDockSettings"))
        compare(window.livePins.count, 9)
        compare(window.settings.pinnedIds[8], "desktop:punchi-add-sentinel.desktop")
        verify(window.visible)
        verify(!window.hasPendingChanges)
        mouseClick(findChild(view, "resetDockSettings"))
        compare(window.livePins.count, 9)
        mouseClick(findChild(view, "acceptDockSettings"))
        tryCompare(window, "visible", false)
        compare(window.livePins.count, 8)
        window.open()
        dialog = openEditor(view)
        selectOwned(dialog)
        window.close()
        compare(window.settings.pinnedIds.length, 8)
        compare(dialog.controller.selectedAppId, "")
        window.open()
        verify(waitForRendering(window.contentItem))
        verify(!window.hasPendingChanges)
        verify(!view.addingApplication)
        window.close()
    }
    function test_pickerMetadataAndVerticalLayout() {
        const window = createTemporaryObject(settingsWindowFixture, test)
        window.open()
        const view = findChild(window.contentItem, "dockSettingsView")
        view.currentPage = 0
        tryVerify(function() { return window.applicationCatalog.application("desktop:punchi-add-sentinel.desktop").installed === true })
        const dialog = openEditor(view)
        verify(waitForRendering(dialog.contentItem))
        const search = findChild(dialog, "applicationSearch")
        const results = findChild(dialog, "applicationResultsScroll")
        const nameLabel = findChild(dialog, "applicationNameLabel")
        const iconLabel = findChild(dialog, "applicationIconLabel")
        const descriptionLabel = findChild(dialog, "applicationDescriptionLabel")
        const name = findChild(dialog, "applicationNameValue")
        const icon = findChild(dialog, "applicationPreviewIcon")
        const description = findChild(dialog, "applicationDescriptionValue")
        function position(item) { return item.mapToItem(dialog.contentItem, 0, 0) }
        verify(results.height >= Kirigami.Units.gridUnit * 12)
        verify(Math.abs(position(nameLabel).x - position(search).x) <= 1)
        compare(position(nameLabel).x, position(iconLabel).x)
        compare(position(nameLabel).x, position(descriptionLabel).x)
        compare(position(name).x, position(icon).x)
        compare(position(name).x, position(description).x)
        verify(position(nameLabel).y > results.y + results.height)
        const add = findChild(dialog, "confirmAddApplication")
        const discard = findChild(dialog, "discardAddApplication")
        verify(position(add).y > position(description).y + description.height)
        verify(position(discard).x > position(add).x)
        compare(name.text, "")
        selectOwned(dialog)
        compare(name.text, "Punchi owned sentinel")
        compare(description.text, "Owned application fixture")
        compare(icon.source.toString(), "utilities-terminal")
        compare(position(nameLabel).x, position(search).x)
        compare(position(name).x, position(icon).x)
        mouseClick(discard)
        tryCompare(dialog, "visible", false)
        window.close()
    }
}
