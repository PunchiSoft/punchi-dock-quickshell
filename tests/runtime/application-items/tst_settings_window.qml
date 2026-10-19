// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Punchi.Kde as Native
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
            applicationCatalog: Native.DockItemCatalog { applications: ApplicationCatalog {} trashTitle: "Owned Trash" }
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
        mouseClick(findChild(dialog, "confirmAddItem"))
        tryCompare(dialog, "visible", false)
        compare(view.settings.pinnedIds.length, 11)
        compare(window.livePins.count, 10)
        verify(window.hasPendingChanges)
        mouseClick(findChild(view, "closeDockSettings"))
        tryCompare(window, "visible", false)
        compare(window.settings.pinnedIds.length, 10)
        window.open()
        verify(waitForRendering(window.contentItem))
        compare(view.settings.pinnedIds.length, 10)
        dialog = openEditor(view)
        selectOwned(dialog)
        mouseClick(findChild(dialog, "confirmAddItem"))
        tryCompare(dialog, "visible", false)
        mouseClick(findChild(view, "applyDockSettings"))
        compare(window.livePins.count, 11)
        compare(window.settings.pinnedIds[9], "desktop:punchi-add-sentinel.desktop")
        compare(window.settings.pinnedIds[10], "item:trash")
        verify(window.visible)
        verify(!window.hasPendingChanges)
        mouseClick(findChild(view, "resetDockSettings"))
        compare(window.livePins.count, 11)
        mouseClick(findChild(view, "acceptDockSettings"))
        tryCompare(window, "visible", false)
        compare(window.livePins.count, 10)
        window.open()
        dialog = openEditor(view)
        selectOwned(dialog)
        window.close()
        compare(window.settings.pinnedIds.length, 10)
        compare(dialog.controller.selectedAppId, "")
        window.open()
        verify(waitForRendering(window.contentItem))
        verify(!window.hasPendingChanges)
        verify(!view.addingItem)
        window.close()
    }
    function test_pickerMetadataAndVerticalLayout() {
        const window = createTemporaryObject(settingsWindowFixture, test)
        window.open()
        const view = findChild(window.contentItem, "dockSettingsView")
        view.currentPage = 0
        tryVerify(function() { return window.applicationCatalog.application("desktop:punchi-add-sentinel.desktop").installed === true })
        const dialog = openEditor(view)
        verify(waitForRendering(dialog))
        const search = findChild(dialog, "applicationSearch")
        const results = findChild(dialog, "applicationResultsScroll")
        const nameLabel = findChild(dialog, "applicationNameLabel")
        const iconLabel = findChild(dialog, "applicationIconLabel")
        const descriptionLabel = findChild(dialog, "applicationDescriptionLabel")
        const name = findChild(dialog, "applicationNameValue")
        const icon = findChild(dialog, "applicationPreviewIcon")
        const description = findChild(dialog, "applicationDescriptionValue")
        function position(item) { return item.mapToItem(dialog, 0, 0) }
        verify(results.height >= Kirigami.Units.gridUnit * 6)
        verify(Math.abs(position(nameLabel).x - position(search).x) <= 1)
        compare(position(nameLabel).x, position(iconLabel).x)
        compare(position(nameLabel).x, position(descriptionLabel).x)
        compare(position(name).x, position(icon).x)
        compare(position(name).x, position(description).x)
        verify(position(nameLabel).y > results.y + results.height)
        const add = findChild(dialog, "confirmAddItem")
        const discard = findChild(dialog, "cancelAddItem")
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

    function test_pickerReplacesOnlyItemsContentArea() {
        const window = createTemporaryObject(settingsWindowFixture, test)
        window.open()
        const view = findChild(window.contentItem, "dockSettingsView")
        view.currentPage = 0
        const page = openEditor(view)
        verify(findChild(view, "settingsSidebar").visible)
        verify(findChild(view, "itemsSettingsPage").visible)
        verify(findChild(view, "generalSettingsPage").visible)
        verify(findChild(view, "dockItemToolbar").visible)
        verify(findChild(view, "applyDockSettings").visible)
        verify(!findChild(view, "settingsDockItems").visible)
        verify(page.Window.window === window)
        mouseClick(findChild(page, "cancelAddItem"))
        tryCompare(view, "addingItem", false)
        verify(findChild(view, "settingsDockItems").visible)
        window.close()
    }

    function test_aboutPageNavigationAndProjectMetadata() {
        const window = createTemporaryObject(settingsWindowFixture, test)
        window.open()
        const view = findChild(window.contentItem, "dockSettingsView")
        const aboutNavigation = findChild(view, "aboutSettingsPage")
        mouseClick(aboutNavigation)
        tryCompare(view, "currentPage", 2)
        const aboutPage = findChild(view, "settingsAboutPage")
        verify(waitForRendering(aboutPage))
        const name = findChild(aboutPage, "aboutProjectName")
        const logo = findChild(aboutPage, "aboutProjectLogo")
        const repository = findChild(aboutPage, "aboutRepositoryLink")
        const help = findChild(aboutPage, "aboutHelpLink")
        const authors = findChild(aboutPage, "aboutAuthors")
        compare(name.text, "Punchi Dock Quickshell 0.1.21")
        compare(logo.status, Image.Ready)
        compare(repository.url, "https://github.com/PunchiSoft/punchi-dock-quickshell")
        compare(repository.horizontalAlignment, Text.AlignLeft)
        compare(help.url, "https://github.com/PunchiSoft/punchi-dock-quickshell/issues")
        compare(help.horizontalAlignment, Text.AlignLeft)
        compare(help.text, "Report an issue")
        compare(authors.text, "PunchiSoft")
        verify(!window.hasPendingChanges)
        window.close()
    }
}
