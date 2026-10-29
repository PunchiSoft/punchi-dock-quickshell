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
        PunchiSettingsWindow {
            id: window
            settings: PunchiShellSettings {}
            applicationCatalog: Native.DockItemCatalog {
                applications: PunchiApplicationCatalog {}
                containers: window.settings.containers
                trashTitle: "Owned Trash"
            }
            license: QtObject {
                readonly property string text: "GNU GENERAL PUBLIC LICENSE\nVersion 3, 29 June 2007\n"
            }
            readonly property PunchiPinnedApplications livePins: PunchiPinnedApplications {
                catalog: window.applicationCatalog
                pinnedIds: window.settings.pinnedIds
                iconOverrides: window.settings.iconOverrides
            }
        }
    }
    function init(): void {
        // Offscreen QPA cannot raise a real window; keep its diagnostic visible.
        failOnWarning(/^(?!This plugin does not support raise\(\)$).*/)
    }
    // A hidden and shown window renders once and an idle offscreen scene then
    // produces no further frame. Wait for a frame when one is available and
    // otherwise accept a visible, laid-out view instead of hanging.
    function waitForFrame(view: Item): bool {
        const window = view.Window.window
        if (!window) return false
        if (waitForRendering(window.contentItem, 1000)) return true
        return window.visible && view.visible && view.width > 0 && view.height > 0
    }
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
    // Rendering the page settles a pending layout, so a synthetic click lands on
    // the control the user would see.
    function clickInPage(dialog: var, name: string): void {
        const control = findChild(dialog, name)
        grabImage(dialog)
        mouseClick(control)
    }
    // The harness points the Downloads location at an owned folder, so the
    // container editor has real entries to list without touching user files.
    function ownedDownloadsPath(): string {
        const probe = Qt.createQmlObject('import Punchi.Kde as Native\nNative.FolderContents {}', test)
        const path = decodeURIComponent(String(probe.downloadsUrl).replace(/^file:\/\//, ""))
        probe.destroy()
        return path
    }
    function resultsArea(dialog: var): var {
        return findChild(dialog, "applicationResultsArea")
    }
    function resultsOf(dialog: var): var {
        const area = resultsArea(dialog)
        return area.item ? findChild(area.item, "applicationSearchResults") : null
    }
    function selectOwned(dialog: var): void {
        const search = findChild(dialog, "applicationSearch")
        mouseClick(search)
        keyClick(Qt.Key_A, Qt.ControlModifier)
        for (const character of "punchi-add-sentinel") keyClick(character)
        const results = resultsOf(dialog)
        tryCompare(results, "count", 1)
        tryVerify(function() { return findChild(results, "applicationResult-desktop:punchi-add-sentinel.desktop") !== null })
        const row = findChild(results, "applicationResult-desktop:punchi-add-sentinel.desktop")
        mouseClick(row)
        tryCompare(resultsArea(dialog), "active", false)
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
        compare(view.settings.pinnedIds.length, 12)
        compare(window.livePins.count, 11)
        verify(window.hasPendingChanges)
        mouseClick(findChild(view, "closeDockSettings"))
        tryCompare(window, "visible", false)
        compare(window.settings.pinnedIds.length, 11)
        window.open()
        verify(waitForRendering(window.contentItem))
        compare(view.settings.pinnedIds.length, 11)
        dialog = openEditor(view)
        selectOwned(dialog)
        mouseClick(findChild(dialog, "confirmAddItem"))
        tryCompare(dialog, "visible", false)
        mouseClick(findChild(view, "applyDockSettings"))
        compare(window.livePins.count, 12)
        compare(window.settings.pinnedIds[10], "desktop:punchi-add-sentinel.desktop")
        compare(window.settings.pinnedIds[11], "item:trash")
        verify(window.visible)
        verify(!window.hasPendingChanges)
        mouseClick(findChild(view, "resetDockSettings"))
        compare(window.livePins.count, 12)
        mouseClick(findChild(view, "acceptDockSettings"))
        tryCompare(window, "visible", false)
        compare(window.livePins.count, 11)
        window.open()
        dialog = openEditor(view)
        selectOwned(dialog)
        window.close()
        compare(window.settings.pinnedIds.length, 11)
        compare(dialog.controller.selectedAppId, "")
        window.open()
        verify(waitForRendering(window.contentItem))
        verify(!window.hasPendingChanges)
        verify(!view.addingItem)
        window.close()
    }
    function test_pickerFormOrderAndMetadata() {
        const window = createTemporaryObject(settingsWindowFixture, test)
        window.open()
        const view = findChild(window.contentItem, "dockSettingsView")
        view.currentPage = 0
        tryVerify(function() { return window.applicationCatalog.application("desktop:punchi-add-sentinel.desktop").installed === true })
        const dialog = openEditor(view)
        verify(waitForRendering(dialog))
        const typeSelector = findChild(dialog, "addItemType")
        const nameLabel = findChild(dialog, "applicationNameFieldLabel")
        const search = findChild(dialog, "applicationSearch")
        const iconLabel = findChild(dialog, "applicationIconLabel")
        const iconButton = findChild(dialog, "applicationIconButton")
        const descriptionLabel = findChild(dialog, "applicationDescriptionLabel")
        const description = findChild(dialog, "applicationDescriptionValue")
        function position(item) { return item.mapToItem(dialog, 0, 0) }
        // One label per field, in the order Type, Name, Icon, Description.
        verify(position(typeSelector).y < position(nameLabel).y)
        verify(position(iconLabel).y > position(search).y + search.height)
        verify(position(descriptionLabel).y > position(iconButton).y + iconButton.height)
        compare(position(nameLabel).x, position(iconLabel).x)
        compare(position(nameLabel).x, position(descriptionLabel).x)
        compare(position(iconButton).x, position(search).x)
        compare(position(description).x, position(search).x)
        // Back, Add and Discard share the header row.
        const back = findChild(dialog, "cancelAddItem")
        const add = findChild(dialog, "confirmAddItem")
        const discard = findChild(dialog, "discardAddItem")
        compare(back.text, "Back")
        compare(add.text, "Add")
        compare(discard.text, "Discard")
        compare(position(back).y, position(add).y)
        compare(position(discard).y, position(add).y)
        verify(position(back).x < position(add).x && position(add).x < position(discard).x)
        verify(position(add).y < position(nameLabel).y)
        verify(findChild(dialog, "applicationNameValue") === null, "the name is not repeated as a read-only row")
        compare(description.text, "")
        selectOwned(dialog)
        compare(description.text, "Owned application fixture")
        compare(iconButton.icon.name, "utilities-terminal")
        // Discard clears the draft without leaving the editor.
        mouseClick(discard)
        tryCompare(dialog.controller, "selectedAppId", "")
        compare(dialog.visible, true)
        compare(description.text, "")
        // Back returns to the item list.
        mouseClick(back)
        tryCompare(dialog, "visible", false)
        window.close()
    }

    function test_pickerKeepsApplicationsClosedUntilAsked() {
        const window = createTemporaryObject(settingsWindowFixture, test)
        window.open()
        const view = findChild(window.contentItem, "dockSettingsView")
        view.currentPage = 0
        tryVerify(function() { return window.applicationCatalog.application("desktop:punchi-add-sentinel.desktop").installed === true })
        const dialog = openEditor(view)
        verify(waitForRendering(dialog))
        const area = resultsArea(dialog)
        compare(area.active, false, "the picker must not show the application list by default")
        // The magnifier reveals every installed application.
        mouseClick(findChild(dialog, "browseApplications"))
        tryCompare(area, "active", true)
        tryVerify(function() { return resultsOf(dialog) !== null })
        const results = resultsOf(dialog)
        tryVerify(function() { return results.count > 0 })
        compare(results.count, dialog.controller.applications.count)
        // The list hangs from the typing row: it starts at the search field
        // instead of under the label column and reaches the magnifier's edge.
        grabImage(dialog)
        const panel = findChild(area, "applicationResultsPanel")
        const searchField = findChild(dialog, "applicationSearch")
        const browseButton = findChild(dialog, "browseApplications")
        verify(panel !== null, "the results panel is missing")
        compare(Math.round(panel.mapToItem(dialog, 0, 0).x),
            Math.round(searchField.mapToItem(dialog, 0, 0).x),
            "the results list must start at the search field")
        compare(Math.round(panel.mapToItem(dialog, 0, 0).x + panel.width),
            Math.round(browseButton.mapToItem(dialog, 0, 0).x + browseButton.width),
            "the results list must reach the search button's edge")
        // Typing filters the open list and closing it keeps the query.
        selectOwned(dialog)
        tryCompare(area, "active", false)
        compare(findChild(dialog, "applicationSearch").text, "punchi-add-sentinel")
        mouseClick(findChild(dialog, "cancelAddItem"))
        tryCompare(dialog, "visible", false)
        // Leaving the page clears the query, so the next visit starts empty.
        const reopened = openEditor(view)
        compare(findChild(reopened, "applicationSearch").text, "")
        compare(resultsArea(reopened).active, false)
        mouseClick(findChild(reopened, "cancelAddItem"))
        tryCompare(reopened, "visible", false)
        window.close()
    }

    function test_pickerChoosesIconFromActiveTheme() {
        const window = createTemporaryObject(settingsWindowFixture, test)
        window.open()
        const view = findChild(window.contentItem, "dockSettingsView")
        view.currentPage = 0
        tryVerify(function() { return window.applicationCatalog.application("desktop:punchi-add-sentinel.desktop").installed === true })
        const dialog = openEditor(view)
        verify(waitForRendering(dialog))
        const iconButton = findChild(dialog, "applicationIconButton")
        verify(iconButton.enabled, "the icon can be chosen before selecting an application")
        selectOwned(dialog)
        verify(iconButton.enabled)
        compare(iconButton.icon.name, "utilities-terminal", "the application icon is the preview")
        mouseClick(iconButton)
        const popup = findChild(dialog, "iconPickerArea")
        tryCompare(popup, "active", true)
        tryVerify(function() { return popup.item !== null })
        // The chooser is its own window, as in the KDE Menu Editor.
        const pickerWindow = popup.item
        tryCompare(pickerWindow, "visible", true)
        grabImage(pickerWindow.contentItem)
        const grid = findChild(pickerWindow.contentItem, "iconGrid")
        const iconSearch = findChild(pickerWindow.contentItem, "iconSearch")
        // The theme is scanned off the GUI thread.
        tryVerify(function() { return dialog.iconModel.loaded })
        // The chooser offers the theme's categories and starts on Applications,
        // like the native dialog.
        const contexts = dialog.iconModel.contexts
        verify(contexts.length > 0, "the theme declares icon categories")
        if (contexts.indexOf("Applications") >= 0)
            compare(dialog.iconModel.context, "Applications", "the chooser opens on Applications")
        const shownIcons = grid.count
        dialog.iconModel.context = ""
        tryVerify(function() { return grid.count >= shownIcons })
        const everyIcon = grid.count
        dialog.iconModel.context = "Applications"
        verify(grid.count > 0 && grid.count <= everyIcon, "a category narrows the grid")
        // An offscreen secondary window never becomes the active window, so the
        // filter is driven through the model the field edits.
        dialog.iconModel.query = "folder"
        compare(iconSearch.text, "", "the search starts empty")
        tryVerify(function() { return grid.count > 0 })
        // The grid lays out while it fills; render it so the tile position is
        // current before the click.
        grid.positionViewAtIndex(0, GridView.Beginning)
        tryVerify(function() { return grid.itemAtIndex(0) !== null })
        // Render after scrolling so the tile position is current.
        grabImage(pickerWindow.contentItem)
        const tile = grid.itemAtIndex(0)
        verify(tile !== null)
        const chosen = String(tile.iconName)
        verify(chosen.length > 0)
        mouseClick(tile, 2, 2)
        compare(dialog.pickedIconName, chosen, "the click highlights the icon")
        compare(dialog.controller.pendingIconName, "", "nothing is applied before accepting")
        mouseClick(findChild(pickerWindow.contentItem, "applyIconChoice"))
        compare(dialog.controller.pendingIconName, chosen, "OK applies the highlighted icon")
        verify(dialog.controller.selectedAppId.length > 0, "the icon choice keeps the selected application")
        tryCompare(popup, "active", false)
        compare(iconButton.icon.name, chosen)
        const addButton = findChild(dialog, "confirmAddItem")
        verify(addButton.enabled, "add enabled: selected=" + dialog.controller.selectedAppId
            + " canAdd=" + dialog.controller.canAdd + " icon=" + dialog.controller.selectedIconName)
        clickInPage(dialog, "confirmAddItem")
        tryCompare(dialog, "visible", false)
        const appId = "desktop:punchi-add-sentinel.desktop"
        compare(view.settings.iconOverride(appId), chosen)
        mouseClick(findChild(view, "applyDockSettings"))
        compare(window.settings.iconOverride(appId), chosen)
        let liveIcon = ""
        for (let row = 0; row < window.livePins.count; ++row) {
            const entry = window.livePins.get(row)
            if (entry.appId === appId) liveIcon = String(entry.iconName)
        }
        compare(liveIcon, chosen, "the dock row uses the chosen icon")
        tryVerify(function() {
            const row = window.livePins.get(window.livePins.count - 2)
            return row !== null && row.iconName === chosen
        })
        // The stored icon survives reopening the editor.
        const reopened = openEditor(view)
        verify(waitForRendering(reopened))
        verify(findChild(reopened, "applicationIconButton").enabled)
        mouseClick(findChild(reopened, "cancelAddItem"))
        tryCompare(reopened, "visible", false)
        compare(view.settings.iconOverride(appId), chosen)
        window.close()
    }

    function test_containerIconUsesTheThemeChooser() {
        const window = createTemporaryObject(settingsWindowFixture, test)
        window.open()
        const view = findChild(window.contentItem, "dockSettingsView")
        view.currentPage = 0
        tryVerify(function() { return window.applicationCatalog.application("desktop:punchi-add-sentinel.desktop").installed === true })
        const dialog = openEditor(view)
        verify(waitForRendering(dialog))
        dialog.itemType = "container"
        dialog.containerPath = "/tmp/punchi-icon-chooser-container"
        grabImage(dialog)
        compare(dialog.containerIcon, "folder", "a container starts with the folder icon")
        const iconButton = findChild(dialog, "newContainerIconButton")
        verify(iconButton !== null, "the container icon button is missing")
        compare(iconButton.icon.name, "folder", "the container icon is the preview")
        mouseClick(iconButton)
        const area = findChild(dialog, "iconPickerArea")
        tryCompare(area, "active", true)
        tryVerify(function() { return area.item !== null })
        const pickerWindow = area.item
        tryCompare(pickerWindow, "visible", true)
        grabImage(pickerWindow.contentItem)
        const grid = findChild(pickerWindow.contentItem, "iconGrid")
        tryVerify(function() { return dialog.iconModel.loaded })
        dialog.iconModel.context = "Applications"
        dialog.iconModel.query = "folder"
        tryVerify(function() { return grid.count > 0 })
        grid.positionViewAtIndex(0, GridView.Beginning)
        tryVerify(function() { return grid.itemAtIndex(0) !== null })
        grabImage(pickerWindow.contentItem)
        const tile = grid.itemAtIndex(0)
        verify(tile !== null)
        const chosen = String(tile.iconName)
        verify(chosen.length > 0)
        mouseClick(tile, 2, 2)
        compare(dialog.pickedIconName, chosen)
        compare(dialog.containerIcon, "folder", "nothing is applied before accepting")
        mouseClick(findChild(pickerWindow.contentItem, "applyIconChoice"))
        compare(dialog.containerIcon, chosen, "OK applies the container icon")
        compare(findChild(dialog, "newContainerIcon").text, chosen,
            "the icon name field shows the chosen icon")
        compare(iconButton.icon.name, chosen, "the preview follows the choice")
        tryCompare(area, "active", false)
        // The chooser belongs to the page, not to the application draft.
        compare(dialog.controller.pendingIconName, "")
        // A chooser opened for one draft does not survive an item-type switch.
        mouseClick(iconButton)
        tryCompare(area, "active", true)
        dialog.itemType = "application"
        tryCompare(area, "active", false)
        mouseClick(findChild(dialog, "cancelAddItem"))
        tryCompare(dialog, "visible", false)
        window.close()
    }

    function test_containerSelectionKeepsEntriesOutOfThePopup() {
        const window = createTemporaryObject(settingsWindowFixture, test)
        window.open()
        const view = findChild(window.contentItem, "dockSettingsView")
        view.currentPage = 0
        tryVerify(function() { return window.applicationCatalog.application("desktop:punchi-add-sentinel.desktop").installed === true })
        const page = openEditor(view)
        verify(waitForRendering(page))
        page.itemType = "container"
        grabImage(page)

        const selection = findChild(page, "containerEntrySelection")
        verify(selection !== null, "the container editor owns the entry list")
        const list = findChild(selection, "folderEntrySelectionList")
        // Nothing is listed until the owner picks a folder.
        compare(list.count, 0, "the editor lists nothing before a folder is chosen")
        compare(findChild(selection, "folderEntrySelectionHint").text,
            "Choose a folder to list its contents.")
        verify(!findChild(selection, "folderEntrySelectionList").visible,
            "no list is offered before a folder is chosen")
        page.containerPath = ownedDownloadsPath()
        grabImage(page)
        tryVerify(function() { return list.count === 2 })
        tryVerify(function() { return findChild(selection, "folderEntry-owned-report.txt") !== null })
        const report = findChild(selection, "folderEntry-owned-report.txt")
        verify(report !== null, "the owned report is listed")
        compare(report.checked, true, "a folder shows every entry by default")
        compare(findChild(selection, "folderEntrySelectionCount").text, "All shown")

        grabImage(page)
        mouseClick(report)
        compare(page.containerHiddenEntries, ["owned-report.txt"], "unchecking keeps it out")
        compare(findChild(selection, "folderEntrySelectionCount").text, "1 of 2 hidden")

        // The choice reaches the stored container when the item is added.
        mouseClick(findChild(page, "confirmAddItem"))
        tryCompare(page, "visible", false)
        const containerId = view.settings.pinnedIds.find(id => id.indexOf("item:folder:") === 0
            && id !== "item:folder:home")
        verify(containerId.length > 0, "the container was added")
        compare(view.settings.containerHiddenEntries(containerId), ["owned-report.txt"])

        // The details pane edits the same list for an existing container.
        const details = findChild(view, "detailsEntrySelection")
        verify(details !== null, "the details pane lists the container entries")
        const detailsList = findChild(details, "folderEntrySelectionList")
        tryVerify(function() { return detailsList.count === 2 })
        tryVerify(function() { return findChild(details, "folderEntry-owned-photo.jpg") !== null })
        const photo = findChild(details, "folderEntry-owned-photo.jpg")
        verify(photo !== null)
        compare(photo.checked, true)
        grabImage(view)
        mouseClick(photo)
        compare(view.settings.containerHiddenEntries(containerId),
            ["owned-report.txt", "owned-photo.jpg"], "the details pane saves the choice")

        // Showing everything again clears the stored list.
        mouseClick(findChild(details, "folderEntrySelectionShowAll"))
        compare(view.settings.containerHiddenEntries(containerId), [])
        verify(findChild(details, "folderEntry-owned-report.txt").checked)
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
        tryCompare(view, "currentPage", 3)
        const aboutPage = findChild(view, "settingsAboutPage")
        verify(waitForRendering(aboutPage))
        const name = findChild(aboutPage, "aboutProjectName")
        const stage = findChild(aboutPage, "aboutVersionStage")
        const logo = findChild(aboutPage, "aboutProjectLogo")
        const repository = findChild(aboutPage, "aboutRepositoryLink")
        const help = findChild(aboutPage, "aboutHelpLink")
        const authors = findChild(aboutPage, "aboutAuthors")
        const dedication = findChild(aboutPage, "aboutDedication")
        const origin = findChild(aboutPage, "aboutOriginLink")
        const motto = findChild(aboutPage, "aboutDedicationMotto")
        compare(name.text, "Punchi Dock Quickshell 0.1.47")
        compare(stage.text, "Development snapshot, not published")
        compare(logo.status, Image.Ready)
        compare(repository.url, "https://github.com/PunchiSoft/punchi-dock-quickshell")
        compare(repository.horizontalAlignment, Text.AlignLeft)
        compare(help.url, "https://github.com/PunchiSoft/punchi-dock-quickshell/issues")
        compare(help.horizontalAlignment, Text.AlignLeft)
        compare(help.text, "Report an issue")
        compare(authors.text, "PunchiSoft")
        verify(dedication.text.startsWith("Made with love, for the community."))
        verify(dedication.wrapMode === Text.WordWrap)
        compare(origin.url, "https://github.com/PunchiSoft/punchi-dock-remastered")
        compare(origin.horizontalAlignment, Text.AlignLeft)
        compare(origin.text, "Punchi Dock Remastered")
        compare(motto.text, "Linux for everyone!")
        verify(!window.hasPendingChanges)
        window.close()
    }

    function test_aboutLicenseDocumentStaysInTheWindow() {
        const window = createTemporaryObject(settingsWindowFixture, test)
        window.open()
        const view = findChild(window.contentItem, "dockSettingsView")
        view.currentPage = 3
        const aboutPage = findChild(view, "settingsAboutPage")
        verify(waitForRendering(aboutPage))
        const readLicense = findChild(aboutPage, "aboutReadLicense")
        verify(readLicense.enabled)
        mouseClick(readLicense)
        const dialog = findChild(view, "aboutLicenseDialog")
        verify(dialog !== null)
        tryCompare(dialog, "visible", true)
        tryCompare(view, "aboutDialogOpen", true)
        const licenseText = findChild(dialog, "aboutLicenseText")
        verify(licenseText.text.indexOf("GNU GENERAL PUBLIC LICENSE") === 0)
        keyClick(Qt.Key_Escape)
        tryCompare(dialog, "visible", false)
        tryCompare(view, "aboutDialogOpen", false)
        verify(window.visible)
        window.close()
    }
}
