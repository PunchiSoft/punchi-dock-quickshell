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
    Component {
        id: fixture
        SettingsWindow {
            settings: ShellSettings {}
            autostart: QtObject {
                objectName: "autostartService"
                property bool active: false
                property bool draftEnabled: false
                property bool enabled: false
                property bool available: true
                readonly property bool dirty: active && draftEnabled !== enabled
                function begin(): void { active = true; draftEnabled = enabled }
                function cancel(): void { active = false; draftEnabled = enabled }
                function apply(): bool { enabled = draftEnabled; return true }
            }
        }
    }
    Component {
        id: populatedWindowFixture
        // This fixture covers the original eight application rows. Special-item
        // ordering and the new defaults have their own explicit regressions.
        SettingsWindow {
            settings: ShellSettings { pinnedIds: ["files", "terminal", "browser", "kate", "systemsettings", "discover", "gwenview", "okular"] }
            applicationCatalog: DockFixtureModel {}
        }
    }
    Component {
        id: emptyItemsWindowFixture
        SettingsWindow {
            settings: ShellSettings { pinnedIds: [] }
            applicationCatalog: DockFixtureModel {}
        }
    }
    Component {
        id: itemManagementWindowFixture
        SettingsWindow {
            settings: ShellSettings {}
            applicationCatalog: ListModel {
                ListElement { appId: "files"; desktopId: "org.kde.dolphin"; title: "Files"; iconName: "folder" }
                ListElement { appId: "terminal"; desktopId: "org.kde.konsole"; title: "Terminal"; iconName: "utilities-terminal" }
                ListElement { appId: "browser"; desktopId: "org.mozilla.firefox"; title: "Browser"; iconName: "internet-web-browser" }
                ListElement { appId: "kate"; desktopId: "org.kde.kate"; title: "Kate"; iconName: "accessories-text-editor" }
                ListElement { appId: "systemsettings"; desktopId: "org.kde.systemsettings"; title: "System Settings"; iconName: "preferences-system" }
                ListElement { appId: "discover"; desktopId: "org.kde.discover"; title: "Discover"; iconName: "system-software-install" }
                ListElement { appId: "gwenview"; desktopId: "org.kde.gwenview"; title: "Gwenview"; iconName: "gwenview" }
                ListElement { appId: "okular"; desktopId: "org.kde.okular"; title: "Okular"; iconName: "okular" }
                ListElement { appId: "item:downloads"; desktopId: ""; title: "Downloads"; iconName: "folder-downloads" }
                ListElement { appId: "item:trash"; desktopId: ""; title: "Trash"; iconName: "user-trash" }
            }
        }
    }
    Component { id: serviceFixture; SettingsEditService { settings: ShellSettings {} } }
    Component { id: pinsFixture; PinnedApplications { catalog: DockFixtureModel {} pinnedIds: [] } }
    Component { id: applicationRowFixture; ApplicationListRow {} }
    Component {
        id: untrackedRecentFixture
        SettingsWindow {
            id: untrackedRecentWindow
            property int trackingCalls: 0
            settings: ShellSettings {}
            recentApplications: QtObject {
                property bool available: true
                property bool trackingEnabled: false
                function openTrackingSettings(): bool { untrackedRecentWindow.trackingCalls += 1; return true }
            }
        }
    }
    // Mirrors the adapter whenever the dock list is hidden: the history service
    // is not queried, so `available` reports false.
    Component {
        id: hiddenRecentFixture
        SettingsWindow {
            settings: ShellSettings { recentApplicationsEnabled: false }
            recentApplications: QtObject {
                property bool available: false
                property bool trackingEnabled: true
                function setTrackingEnabled(enabled: bool): bool { trackingEnabled = enabled; return true }
                function openTrackingSettings(): bool { return true }
            }
        }
    }
    Component {
        id: trackedRecentFixture
        SettingsWindow {
            settings: ShellSettings {}
            recentApplications: QtObject {
                property bool available: true
                property bool trackingEnabled: true
                property var trackingRequests: []
                function setTrackingEnabled(enabled: bool): bool {
                    trackingEnabled = enabled
                    trackingRequests = trackingRequests.concat([enabled])
                    return true
                }
                function openTrackingSettings(): bool { return true }
            }
        }
    }

    function init(): void {
        // Offscreen QPA cannot raise a real window; keep its diagnostic visible.
        // Qt 6.11 additionally reports "DelegateModel::cancel: index out range"
        // while a settings window that holds the item editor is destroyed. The
        // editor behavior is asserted by these tests and the notice has no
        // observable effect, so it is listed explicitly instead of hidden.
        failOnWarning(/^(?!This plugin does not support raise\(\)$|DelegateModel::cancel: index out range)/)
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
        const toggle = control(window, "zoomScale")
        verify(!apply.enabled)
        toggle.forceActiveFocus(Qt.TabFocusReason)
        keyClick(Qt.Key_Home)
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
        keyClick(Qt.Key_Right)
        compare(window.settings.magnificationEnabled, false)
        const accept = control(window, "acceptDockSettings")
        accept.forceActiveFocus(Qt.TabFocusReason)
        keyClick(Qt.Key_Space)
        tryCompare(window, "visible", false)
        compare(window.settings.magnificationEnabled, true)
        window.open()
        verify(waitForRendering(window.contentItem))
        toggle.forceActiveFocus(Qt.TabFocusReason)
        keyClick(Qt.Key_Home)
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
        compare(view.settings.pinnedIds.length, 10)
        compare(view.settings.pinnedIds[8], "item:downloads")
        compare(view.settings.pinnedIds[9], "item:trash")
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
        compare(window.settings.pinnedIds.length, 10)
        compare(window.settings.pinnedIds[8], "item:downloads")
        compare(window.settings.pinnedIds[9], "item:trash")
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
    function test_autostartToggleDraftApplyAndClose(): void {
        const window = openWindow()
        const service = findChild(window, "autostartService")
        verify(service !== null)
        const toggle = control(window, "startWithPlasma")
        verify(toggle.enabled)
        verify(!toggle.checked)
        mouseClick(toggle)
        verify(toggle.checked)
        verify(service.dirty)
        verify(window.hasPendingChanges)
        // Close must discard the draft without changing the committed state.
        mouseClick(control(window, "closeDockSettings"))
        tryCompare(window, "visible", false)
        window.open()
        verify(waitForRendering(window.contentItem))
        verify(!toggle.checked)
        verify(!window.hasPendingChanges)
        verify(!service.enabled)
        mouseClick(toggle)
        mouseClick(control(window, "applyDockSettings"))
        verify(service.enabled)
        verify(!window.hasPendingChanges)
        mouseClick(toggle)
        mouseClick(control(window, "applyDockSettings"))
        verify(!service.enabled)
        verify(!window.hasPendingChanges)
        window.close()
    }
    function test_recentApplicationsSettings(): void {
        const window = openWindow()
        const view = control(window, "dockSettingsView")
        const toggle = control(window, "recentApplicationsEnabled")
        const count = control(window, "recentApplicationsCount")
        verify(toggle.checked)
        compare(count.value, 5)
        verify(count.enabled)
        count.forceActiveFocus(Qt.TabFocusReason)
        keyClick(Qt.Key_Up)
        compare(view.settings.recentApplicationsCount, 6)
        mouseClick(toggle)
        verify(!toggle.checked)
        verify(!view.settings.recentApplicationsEnabled)
        verify(!count.enabled)
        verify(window.hasPendingChanges)
        mouseClick(control(window, "applyDockSettings"))
        verify(!window.settings.recentApplicationsEnabled)
        verify(!window.hasPendingChanges)
        window.close()
    }
    function test_hiddenRecentApplicationsCanBeShownAgain(): void {
        const window = createTemporaryObject(hiddenRecentFixture, test)
        window.open()
        tryCompare(window, "visible", true)
        verify(waitForRendering(window.contentItem))
        const view = control(window, "dockSettingsView")
        const toggle = control(window, "recentApplicationsEnabled")
        const count = control(window, "recentApplicationsCount")
        const note = control(window, "recentApplicationsUnavailableNote")
        // Hiding the list must never disable its own switch.
        verify(toggle.enabled)
        verify(!toggle.checked)
        verify(!count.enabled)
        // KDE still records history, so its note stays hidden.
        verify(!note.visible)
        mouseClick(toggle)
        verify(toggle.checked)
        verify(view.settings.recentApplicationsEnabled)
        verify(count.enabled)
        mouseClick(toggle)
        verify(!toggle.checked)
        verify(toggle.enabled)
        window.close()
    }
    function test_recentApplicationsWithoutKdeTracking(): void {
        const window = createTemporaryObject(untrackedRecentFixture, test)
        window.open()
        tryCompare(window, "visible", true)
        verify(waitForRendering(window.contentItem))
        const toggle = control(window, "recentApplicationsEnabled")
        const count = control(window, "recentApplicationsCount")
        const note = control(window, "recentApplicationsUnavailableNote")
        // KDE's own preference never disables the dock's switches; it only
        // explains why the list stays empty.
        verify(toggle.enabled)
        verify(toggle.checked)
        verify(count.enabled)
        verify(note.visible)
        verify(note.text.length > 0)
        const kdeRow = control(window, "recentApplicationsKdeRow")
        const kdeButton = control(window, "recentApplicationsKdeSettings")
        verify(kdeRow.visible)
        verify(kdeButton.enabled)
        mouseClick(kdeButton)
        compare(window.trackingCalls, 1)
        window.close()
    }
    function test_recentApplicationsWithKdeTracking(): void {
        const window = createTemporaryObject(trackedRecentFixture, test)
        window.open()
        tryCompare(window, "visible", true)
        verify(waitForRendering(window.contentItem))
        const toggle = control(window, "recentApplicationsEnabled")
        const count = control(window, "recentApplicationsCount")
        const note = control(window, "recentApplicationsUnavailableNote")
        verify(toggle.enabled)
        verify(count.enabled)
        verify(!note.visible)
        const tracking = control(window, "recentApplicationsTracking")
        verify(tracking.checked)
        const service = window.recentApplications
        mouseClick(tracking)
        compare(service.trackingRequests.length, 1)
        compare(service.trackingRequests[0], false)
        verify(!tracking.checked)
        service.trackingEnabled = true
        tryCompare(tracking, "checked", true)
        window.close()
    }
    function test_sidebarAndFooterGeometry(): void {
        const window = openWindow()
        const view = control(window, "dockSettingsView")
        const sidebar = control(window, "settingsSidebar")
        const divider = control(window, "settingsSidebarDivider")
        const main = control(window, "settingsMainContent")
        compare(sidebar.width, Kirigami.Units.gridUnit * 12)
        verify(sidebar.background.radius > 0,
            "the sidebar panel keeps the rounded settings surface")
        verify(sidebar.x + sidebar.width <= divider.x)
        verify(divider.x + divider.width <= main.x)
        verify(sidebar.x + sidebar.width <= main.x)
        verify(main.width > sidebar.width * 2)
        mouseClick(control(window, "itemsSettingsPage"))
        compare(view.currentPage, 0)
        const add = control(window, "addDockItem")
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
    function test_applicationRowSuppressesHoverWhenSelectionIsActive(): void {
        const row = createTemporaryObject(applicationRowFixture, test)
        verify(row !== null)
        verify(row.hoverEnabled)
        row.selectionActive = true
        verify(!row.hoverEnabled)
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
        verify(!down.enabled)
        compare(list.currentIndex, -1)
        const files = control(window, "configuredItem-files")
        mouseClick(files)
        verify(down.enabled)
        verify(!control(window, "configuredItem-terminal").hoverEnabled)
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
    function test_removeDockItemIsPendingUntilApplyAndRestoresOnClose(): void {
        const window = createTemporaryObject(itemManagementWindowFixture, test)
        window.open()
        verify(waitForRendering(window.contentItem))
        mouseClick(control(window, "itemsSettingsPage"))
        const view = control(window, "dockSettingsView")
        const list = control(window, "settingsDockItems")
        list.positionViewAtIndex(list.count - 1, ListView.Contain)
        verify(waitForRendering(list))
        mouseClick(control(window, "configuredItem-item:trash"))
        compare(list.currentIndex, list.count - 1)
        mouseClick(control(window, "removeDockItem"))
        compare(view.settings.pinnedIds.indexOf("item:trash"), -1)
        verify(window.settings.pinnedIds.indexOf("item:trash") >= 0)
        verify(window.hasPendingChanges)
        mouseClick(control(window, "closeDockSettings"))
        window.open()
        verify(waitForRendering(window.contentItem))
        verify(view.settings.pinnedIds.indexOf("item:trash") >= 0)
        verify(!window.hasPendingChanges)
        mouseClick(control(window, "itemsSettingsPage"))
        list.positionViewAtIndex(list.count - 1, ListView.Contain)
        verify(waitForRendering(list))
        mouseClick(control(window, "configuredItem-item:trash"))
        mouseClick(control(window, "removeDockItem"))
        mouseClick(control(window, "applyDockSettings"))
        compare(window.settings.pinnedIds.indexOf("item:trash"), -1)

        mouseClick(control(window, "addDockItem"))
        let page = findChild(view, "addDockItemPage")
        verify(page !== null)
        tryCompare(view, "addingItem", true)
        page.itemType = "container"
        page.containerPath = "/tmp/punchi-pending-container"
        page.containerLayout = "detail"
        // The type switch re-lays out the editor; render it before clicking the
        // header action so the control positions are current.
        grabImage(page)
        mouseClick(findChild(page, "confirmAddItem"))
        tryCompare(view, "addingItem", false)
        const addedContainer = view.settings.pinnedIds.find(id => id.indexOf("item:folder:") === 0)
        verify(addedContainer.length > 0)
        compare(view.settings.container(addedContainer).layout, "detail")
        compare(window.settings.containers.length, 1,
            "the container remains in the settings draft until Apply")
        mouseClick(control(window, "closeDockSettings"))
        window.open()
        verify(waitForRendering(window.contentItem))
        verify(!view.settings.pinnedIds.some(id => id.indexOf("item:folder:") === 0))

        mouseClick(control(window, "itemsSettingsPage"))
        mouseClick(control(window, "addDockItem"))
        page = findChild(view, "addDockItemPage")
        verify(page !== null)
        tryCompare(view, "addingItem", true)
        page.itemType = "trash"
        verify(findChild(page, "confirmAddItem").enabled)
        mouseClick(findChild(page, "confirmAddItem"))
        tryCompare(view, "addingItem", false)
        verify(view.settings.pinnedIds.indexOf("item:trash") >= 0)
        compare(window.settings.pinnedIds.indexOf("item:trash"), -1)
        mouseClick(control(window, "applyDockSettings"))
        verify(window.settings.pinnedIds.indexOf("item:trash") >= 0)
        window.close()
    }
    function test_itemDetailsFollowSelectionAndReflow(): void {
        const window = createTemporaryObject(itemManagementWindowFixture, test)
        window.open()
        verify(waitForRendering(window.contentItem))
        const view = control(window, "dockSettingsView")
        mouseClick(control(window, "itemsSettingsPage"))
        const panel = control(window, "dockItemDetails")
        const list = control(window, "settingsDockItems")
        const title = control(window, "itemDetailsTitle")
        const type = control(window, "itemDetailsType")
        // The default window is capped by the test screen width; request the
        // wide layout explicitly before checking the side-by-side composition.
        window.width = Kirigami.Units.gridUnit * 54
        verify(waitForRendering(window.contentItem))
        verify(control(window, "itemDetailsNote").visible)
        verify(!title.visible)
        verify(!type.visible)
        compare(list.currentIndex, -1)
        verify(panel.mapToItem(view, 0, 0).x > list.mapToItem(view, 0, 0).x)
        verify(panel.width > list.width)

        mouseClick(control(window, "configuredItem-files"))
        tryCompare(title, "text", "Files")
        compare(type.text, "Application")
        verify(!control(window, "itemDetailsNote").visible)

        list.positionViewAtIndex(list.count - 1, ListView.Contain)
        verify(waitForRendering(list))
        mouseClick(control(window, "configuredItem-item:trash"))
        tryCompare(title, "text", "Trash")
        compare(type.text, "Trash")
        verify(!control(window, "containerFolderPath").visible)

        list.positionViewAtIndex(list.count - 2, ListView.Contain)
        verify(waitForRendering(list))
        mouseClick(control(window, "configuredItem-item:downloads"))
        tryCompare(title, "text", "Downloads")
        compare(type.text, "Folder")
        verify(control(window, "containerFolderPath").visible)
        verify(control(window, "folderViewSetting").visible)
        verify(control(window, "containerFolderPath").mapToItem(panel, 0, 0).x >= 0)
        const chooseFolder = control(window, "containerChooseFolder")
        const folderView = control(window, "folderViewSetting")
        compare(chooseFolder.width, folderView.width)
        verify(Math.abs(chooseFolder.mapToItem(panel, 0, 0).x
            - folderView.mapToItem(panel, 0, 0).x) <= 1)
        mouseClick(control(window, "configureDockItem"))
        tryCompare(control(window, "folderViewSetting"), "activeFocus", true)

        window.width = window.minimumWidth
        tryVerify(function() {
            return panel.mapToItem(view, 0, 0).y > list.mapToItem(view, 0, 0).y
        })
        window.close()
    }
    function test_sidebarCategoriesPlaceIconBeforeLabel(): void {
        const window = openWindow()
        for (const name of ["itemsSettingsPage", "generalSettingsPage", "aboutSettingsPage"]) {
            const button = control(window, name)
            const icon = findChild(button, "categoryIcon")
            const label = findChild(button, "categoryLabel")
            verify(icon !== null && label !== null, name)
            verify(!button.hoverEnabled, name)
            const cursor = findChild(button, "categoryCursor")
            verify(cursor !== null, name)
            compare(cursor.cursorShape, Qt.PointingHandCursor)
            mouseMove(button)
            tryCompare(cursor, "hovered", true)
            verify(icon.width >= Kirigami.Units.iconSizes.smallMedium)
            verify(icon.mapToItem(button, icon.width, 0).x
                <= label.mapToItem(button, 0, 0).x)
            compare(label.text, button.text)
            compare(label.horizontalAlignment, Text.AlignLeft)
        }
        window.close()
    }
    function collect(item: var, name: string, found: var): void {
        if (item.objectName === name) found.push(item)
        const children = item.data || item.children
        if (!children) return
        for (let index = 0; index < children.length; ++index)
            collect(children[index], name, found)
    }
    function test_generalPageGroupsRowsIntoCards(): void {
        const window = openWindow()
        const view = control(window, "dockSettingsView")
        mouseClick(control(window, "generalSettingsPage"))
        compare(view.currentPage, 1)
        const frames = []
        collect(view, "settingsCardFrame", frames)
        const rows = []
        collect(view, "settingsRow", rows)
        const blockSeparators = []
        collect(view, "settingsSeparator", blockSeparators)
        verify(frames.length >= 4, "every group owns one card frame")
        verify(rows.length >= 6, "every preference row is a settings row")
        verify(blockSeparators.length >= 1)
        for (const frame of frames) {
            verify(frame.radius > 0)
            compare(frame.border.width, 1)
            // The fill must not vanish into the page background, which is what
            // happens when a card only paints the theme background color.
            verify(!Qt.colorEqual(frame.color, view.palette.window),
                "the card fill stays visible against the page background")
        }
        const row = rows[0]
        const separator = findChild(row, "settingsRowSeparator")
        verify(separator !== null)
        verify(separator.x >= row.leftPadding, "the separator is inset to the row text")
        fuzzyCompare(separator.y + separator.height, row.height, 1)
        // The last row of a group closes the card without a trailing line.
        verify(rows.some(candidate => !candidate.showSeparator))
        window.close()
    }
    function test_addItemEditorGroupsFieldsIntoOneCard(): void {
        const window = openWindow()
        const view = control(window, "dockSettingsView")
        mouseClick(control(window, "itemsSettingsPage"))
        mouseClick(control(window, "addDockItem"))
        const page = control(window, "addDockItemPage")
        tryCompare(page, "visible", true)
        grabImage(page)
        const card = findChild(page, "addItemFormCard")
        verify(card !== null)
        const frames = []
        collect(card, "settingsCardFrame", frames)
        compare(frames.length, 1, "the editor owns one grouped surface")
        const frame = frames[0]
        verify(frame.radius > 0)
        compare(frame.border.width, 1)
        verify(!Qt.colorEqual(frame.color, view.palette.window),
            "the card fill stays visible against the page background")
        verify(findChild(frame, "addItemType") !== null)
        verify(findChild(frame, "applicationSearch") !== null)
        // The result list overlays the form, so it cannot push the remaining
        // fields past the card.
        const height = page.implicitHeight
        page.browsing = true
        grabImage(page)
        fuzzyCompare(page.implicitHeight, height, 1)
        page.browsing = false
        window.close()
    }
    function test_emptyItemsShowsDetailsNote(): void {
        const window = createTemporaryObject(emptyItemsWindowFixture, test)
        window.open()
        verify(waitForRendering(window.contentItem))
        mouseClick(control(window, "itemsSettingsPage"))
        verify(control(window, "itemDetailsNote").visible)
        verify(!control(window, "itemDetailsTitle").visible)
        window.close()
    }
}
