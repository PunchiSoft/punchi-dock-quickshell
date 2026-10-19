// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtTest
import org.kde.kirigami as Kirigami
import "../../modules/dock"
import "../../services"
import "../../config"

TestCase {
    id: test
    name: "DockInteraction"
    when: windowShown
    visible: true
    width: 840
    height: 280

    Component {
        id: fixture
        DockView {
            id: dock
            entries: DockFixtureModel {}
            property alias testGeometry: geometry
            property alias testContent: content
            property ShellSettings preferences: ShellSettings {}
            property QtObject minimizeController: QtObject {
                property bool available: true
                property bool squashAvailable: true
                property bool magicLampAvailable: true
                property string effect: "squash"
            }
            DockContextAnchor { id: geometry }
            DockContextContent {
                id: content
                visible: false
                settings: dock.preferences
                dockBackground: true
                minimizeEffectController: dock.minimizeController
                onSettingsRequested: { visible = false; dock.settingsRequested() }
                onCloseRequested: visible = false
            }
            onContextMenuRequested: function(item, appId, title, position) {
                if (appId.length > 0) geometry.captureItem(item, title)
                else geometry.capturePoint(item, position)
                content.visible = true
            }
        }
    }

    Component {
        id: modelessFixture
        DockView {
            id: dock
            entries: DockFixtureModel {}
            readonly property var inputWindow: Window.window
            property alias testMenu: menu
            contextMenuOpen: menu.visible || menu.preparingToShow
            DockContextPopup {
                id: menu
                hostWindow: dock.inputWindow
            }
            onContextMenuRequested: function(item, appId, title, position) {
                menu.appId = appId
                if (appId.length > 0) menu.openForItem(item, title)
                else menu.openAt(item, position)
            }
            onItemActivated: menu.dismiss()
        }
    }

    SignalSpy { id: activation; signalName: "itemActivated" }
    SignalSpy { id: closeSpy; signalName: "closeRequested" }

    function init() {
        failOnWarning(/.*/)
    }

    function createView() {
        const view = createTemporaryObject(fixture, test)
        verify(view !== null)
        tryCompare(view, "itemCount", 8)
        verify(waitForRendering(view))
        return view
    }

    function test_openMenuAllowsHoverAndSingleClickOnAnotherLauncher() {
        const view = createTemporaryObject(modelessFixture, test)
        verify(view !== null)
        tryCompare(view, "itemCount", 8)
        verify(waitForRendering(view))
        activation.target = view
        activation.clear()
        const first = findChild(view, "launcher-systemsettings")
        const second = findChild(view, "launcher-browser")
        verify(first !== null && second !== null)
        mouseClick(first, first.width / 2, first.height / 2, Qt.RightButton)
        tryCompare(view.testMenu, "opened", true)
        compare(view.testMenu.sourceItem, first)
        verify(findChild(view.testMenu.mainItem, "configureDockAction").activeFocus)
        mouseMove(view, second.x + second.width / 2, second.y + second.height / 2)
        tryCompare(second, "targetIconScale", 2)
        tryCompare(second, "hovered", true)
        compare(view.testMenu.opened, true)
        mouseClick(second, second.width / 2, second.height / 2, Qt.LeftButton)
        compare(activation.count, 1)
        compare(activation.signalArguments[0][0], "browser")
        tryCompare(view.testMenu, "visible", false)
        const third = findChild(view, "launcher-kate")
        mouseMove(view, third.x + third.width / 2, third.y + third.height / 2)
        mouseClick(third, third.width / 2, third.height / 2, Qt.LeftButton)
        compare(activation.count, 2)
        compare(activation.signalArguments[1][0], "kate")
    }

    function test_openMenuRetargetsOnOneRightClickAndEscapeRestoresFocus() {
        const view = createTemporaryObject(modelessFixture, test)
        tryCompare(view, "itemCount", 8)
        verify(waitForRendering(view))
        const first = findChild(view, "launcher-files")
        const second = findChild(view, "launcher-browser")
        mouseClick(first, first.width / 2, first.height / 2, Qt.RightButton)
        tryCompare(view.testMenu, "opened", true)
        mouseMove(view, second.x + second.width / 2, second.y + second.height / 2)
        mouseClick(second, second.width / 2, second.height / 2, Qt.RightButton)
        tryCompare(view.testMenu, "opened", true)
        compare(view.testMenu.sourceItem, second)
        verify(findChild(view.testMenu.mainItem, "configureDockAction").activeFocus)
        keyClick(Qt.Key_Escape)
        tryCompare(view.testMenu, "visible", false)
        verify(second.activeFocus)
    }

    function test_pendingMenuDoesNotReopenAfterAnotherLauncherActivation() {
        const view = createTemporaryObject(modelessFixture, test)
        tryCompare(view, "itemCount", 8)
        const first = findChild(view, "launcher-files")
        const second = findChild(view, "launcher-browser")
        view.testMenu.openForItem(first, first.title)
        verify(view.testMenu.preparingToShow)
        second.clicked()
        compare(view.testMenu.preparingToShow, false)
        wait(50)
        compare(view.testMenu.visible, false)
    }

    function test_contextMenuRequiresConfigureAction() {
        const view = createView()
        const settingsSpy = createTemporaryQmlObject(
            'import QtTest; SignalSpy { signalName: "settingsRequested" }', test)
        settingsSpy.target = view
        activation.target = view
        activation.clear()
        const content = view.testContent
        const action = findChild(content, "configureDockAction")
        compare(action.text, "Configure Dock")
        const tile = findChild(view, "launcher-files")
        mouseClick(tile, tile.width / 2, tile.height / 2, Qt.RightButton)
        compare(view.testGeometry.sourceItem, tile)
        compare(settingsSpy.count, 0)
        compare(activation.count, 0)
        action.forceActiveFocus()
        keyClick(Qt.Key_Escape)
        compare(content.visible, false)
        compare(settingsSpy.count, 0)
        mouseClick(tile, tile.width / 2, tile.height / 2, Qt.RightButton)
        action.forceActiveFocus()
        keyClick(Qt.Key_Return)
        compare(settingsSpy.count, 1)
        compare(content.visible, false)
        compare(activation.count, 0)
        verify(view.focusItem(0))
        keyClick(Qt.Key_F10, Qt.ShiftModifier)
        compare(content.visible, false)
        compare(settingsSpy.count, 1)
    }

    function test_contextMenuExposesDockControlsAndPositionSubmenu() {
        const view = createView()
        const content = view.testContent
        content.visible = true
        const autoHide = findChild(content, "dockAutoHideAction")
        const magnification = findChild(content, "dockMagnificationAction")
        const position = findChild(content, "dockPositionSubmenu")
        verify(autoHide !== null && magnification !== null && position !== null)
        compare(autoHide.text, "Automatically Hide Dock")
        compare(autoHide.marked, false)
        compare(magnification.marked, true)
        compare(findChild(content, "dockPosition-left").visible, false)
        const edgeSpy = createTemporaryQmlObject(
            'import QtTest; SignalSpy { signalName: "dockEdgeRequested" }', test)
        edgeSpy.target = content
        position.clicked()
        compare(content.openDockSubmenu, "position")
        compare(findChild(content, "dockPosition-left").visible, true)
        findChild(content, "dockPosition-left").clicked()
        compare(edgeSpy.count, 1)
        compare(edgeSpy.signalArguments[0][0], "left")
    }

    function test_unpinnedRunningApplicationOffersPinToDock() {
        const view = createView()
        const content = view.testContent
        content.visible = true
        content.dockBackground = false
        content.canPin = true
        content.pinned = false
        const action = findChild(content, "pinDockAction")
        verify(action !== null)
        compare(action.text, "Pin to Dock")
        compare(action.visible, true)
        const pinSpy = createTemporaryQmlObject(
            'import QtTest; SignalSpy { signalName: "pinRequested" }', test)
        pinSpy.target = content
        action.clicked()
        compare(pinSpy.count, 1)
        content.pinned = true
        compare(action.visible, false)
        content.pinned = false
        content.canPin = false
        compare(action.visible, false)
        content.dockBackground = true
        content.canPin = true
        compare(action.visible, false)
    }

    function test_nativeWindowActionsFollowTaskCapabilitiesAndDesktopCount() {
        const view = createView()
        const content = view.testContent
        content.visible = true
        content.dockBackground = false
        content.windowActions = {available: true, desktopChangeable: true, virtualDesktops: ["desktop-1"],
            onAllDesktops: false, movable: true, resizable: false, maximizable: true, maximized: false,
            minimizable: true, minimized: false, keepAbove: false, keepBelow: false,
            fullscreenable: true, fullscreen: false, canSetNoBorder: false, noBorder: false,
            canHideFromCapture: true, excludedFromCapture: false, closable: true}
        content.virtualDesktops = [
            {id: "desktop-1", name: "Desktop 1", current: true},
            {id: "desktop-2", name: "Desktop 2", current: false}
        ]
        const actions = findChild(content, "dockWindowActions")
        const moveDesktop = findChild(content, "moveToDesktopSubmenu")
        const more = findChild(content, "moreWindowActionsSubmenu")
        const spy = createTemporaryQmlObject(
            'import QtTest; SignalSpy { signalName: "windowActionRequested" }', test)
        spy.target = content
        verify(actions !== null && moveDesktop !== null && more !== null)
        verify(moveDesktop.visible && more.visible)
        compare(findChild(content, "windowAction-resize").visible, false)
        moveDesktop.clicked()
        compare(actions.openSubmenu, "desktops")
        compare(findChild(content, "virtualDesktop-desktop-2").visible, true)
        findChild(content, "virtualDesktop-desktop-2").clicked()
        compare(spy.signalArguments[0][0], "desktop")
        compare(spy.signalArguments[0][1], "desktop-2")
        more.clicked()
        compare(actions.openSubmenu, "window")
        verify(findChild(content, "windowAction-move").enabled)
        compare(findChild(content, "windowAction-resize").enabled, false)
        verify(findChild(content, "windowAction-hide-capture").visible)
        const keepAbove = findChild(content, "windowAction-keep-above")
        keepAbove.clicked()
        compare(spy.signalArguments[1][0], "keep-above")
        compare(findChild(content, "closeWindowAction").enabled, true)
        // KDE can publish desktop names one snapshot late; show a positional fallback.
        content.virtualDesktops = [
            {id: "desktop-1", name: "", current: true},
            {id: "desktop-2", name: "", current: false}
        ]
        compare(findChild(content, "virtualDesktop-desktop-2").text, "Desktop 2")
        content.virtualDesktops = [{id: "desktop-1", name: "Desktop 1", current: true}]
        tryCompare(moveDesktop, "visible", false)
    }

    function test_globalDockControlsNeverAppearInItemContextMenus() {
        const view = createView()
        const content = view.testContent
        content.visible = true
        content.dockBackground = false
        for (const objectName of ["dockAutoHideAction", "dockMagnificationAction", "dockPositionSubmenu", "minimizeEffectSubmenu"])
            compare(findChild(content, objectName).visible, false)
        compare(findChild(content, "configureDockAction").visible, true)
    }

    function test_contextMenuReflectsAndRequestsGlobalMinimizeEffect() {
        const view = createView()
        const content = view.testContent
        content.visible = true
        const submenu = findChild(content, "minimizeEffectSubmenu")
        verify(submenu !== null)
        compare(submenu.visible, true)
        const effectSpy = createTemporaryQmlObject(
            'import QtTest; SignalSpy { signalName: "minimizeEffectRequested" }', test)
        effectSpy.target = content
        submenu.clicked()
        compare(content.openDockSubmenu, "minimize")
        compare(findChild(content, "minimizeEffect-squash").marked, true)
        findChild(content, "minimizeEffect-magiclamp").clicked()
        compare(effectSpy.count, 1)
        compare(effectSpy.signalArguments[0][0], "magiclamp")
    }

    function test_contextMenuUsesNativeCapturedAnchor() {
        const view = createView()
        const tile = findChild(view, "launcher-kate")
        mouseMove(tile)
        tryCompare(tile, "targetIconScale", 2)
        mouseClick(tile, tile.width / 2, tile.height / 2, Qt.RightButton)
        const geometry = view.testGeometry
        compare(geometry.sourceItem, tile)
        compare(geometry.itemName, tile.title)
        const captured = geometry.capturedGeometry
        fuzzyCompare(captured.width, tile.iconSize * tile.visualIconScale, 0.01)
        const expected = tile.parent.mapToItem(tile.Window.contentItem, tile.iconTopCenter.x, tile.iconTopCenter.y)
        fuzzyCompare(captured.x + captured.width / 2, expected.x, 0.01)
        fuzzyCompare(captured.y, expected.y, 0.01)
        view.itemSize += view.metrics.spacing
        view.iconSize += view.metrics.spacing
        compare(geometry.capturedGeometry, captured)
        view.testContent.visible = false
        mouseClick(view, view.width / 2, 0, Qt.RightButton)
        compare(geometry.sourceItem, view)
        compare(geometry.itemName, "")
    }

    function test_nativeDesktopActionIntent() {
        const view = createView()
        const content = view.testContent
        content.actions = [{actionId: "new-window", name: "New Window", icon: "window-new"}]
        const spy = createTemporaryQmlObject(
            'import QtTest; SignalSpy { signalName: "actionRequested" }', test)
        spy.target = content
        const tile = findChild(view, "launcher-browser")
        mouseClick(tile, tile.width / 2, tile.height / 2, Qt.RightButton)
        tryVerify(function() { return findChild(content, "desktopAction-new-window") !== null })
        const action = findChild(content, "desktopAction-new-window")
        verify(action.height < Kirigami.Units.gridUnit * 2)
        verify(findChild(content, "closeDockContextAction") === null)
        action.forceActiveFocus()
        keyClick(Qt.Key_Return)
        compare(spy.count, 1)
        compare(spy.signalArguments[0][0], "new-window")
    }

    function test_menuKeepsMagnification() {
        const view = createView()
        const tile = findChild(view, "launcher-browser")
        mouseMove(tile)
        tryCompare(tile, "targetIconScale", 2)
        view.contextMenuOpen = true
        compare(tile.tooltipsEnabled, false)
        compare(findChild(tile, "launcher-tooltip").visible, false)
        mouseMove(test, test.width - 1, 0)
        tryVerify(function() { return !tile.hovered })
        compare(tile.targetIconScale, 2)
        view.contextMenuOpen = false
        tryCompare(tile, "targetIconScale", 1)
    }

    function test_contextRecentFilesAndLauncherIntents() {
        const view = createView()
        const content = view.testContent
        const documents = createTemporaryQmlObject('import QtQml.Models; ListModel {}', test)
        documents.append({resource: "/owned/picture with spaces.png", name: "Picture with spaces.png", iconName: "image-x-generic"})
        content.recentDocuments = documents
        content.canLaunchNewWindow = true
        content.pinned = true
        content.visible = true
        const spy = createTemporaryQmlObject('import QtTest; SignalSpy { signalName: "recentRequested" }', test)
        spy.target = content
        tryVerify(function() { return findChild(content, "recentDocument-/owned/picture with spaces.png") !== null })
        const recent = findChild(content, "recentDocument-/owned/picture with spaces.png")
        recent.forceActiveFocus()
        keyClick(Qt.Key_Return)
        compare(spy.signalArguments[0][0], "/owned/picture with spaces.png")
        for (const entry of [
            ["forgetRecentAction", "forgetRecentRequested"],
            ["openNewWindowAction", "newWindowRequested"],
            ["unpinDockAction", "unpinRequested"]]) {
            spy.signalName = entry[1]
            spy.clear()
            const action = findChild(content, entry[0])
            verify(action.visible)
            action.forceActiveFocus()
            keyClick(Qt.Key_Return)
            compare(spy.count, 1)
        }
        verify(waitForRendering(content))
        const populatedHeight = content.implicitHeight
        documents.clear()
        tryVerify(function() { return content.implicitHeight < populatedHeight })
        verify(!findChild(content, "forgetRecentAction").visible)
        const row = findChild(content, "configureDockAction")
        const before = row.implicitHeight
        const font = row.font
        font.pointSize *= 2
        row.font = font
        tryVerify(function() { return row.implicitHeight > before })
    }

    function test_contextPointerTracksPlacement() {
        const view = createView()
        const body = view.testContent
        const surface = findChild(body, "dockContextSurface")
        verify(surface.tailHeight > 0)
        compare(surface.cornerRadius, Kirigami.Units.cornerRadius)
        body.pointerX = body.width / 3
        fuzzyCompare(surface.pointerCenter, body.width / 3, 0.01)
        body.pointerX = -body.width
        verify(surface.pointerCenter >= surface.radius + surface.tailHeight)
        body.pointerX = body.width * 2
        verify(surface.pointerCenter <= body.width - surface.radius - surface.tailHeight)
        compare(surface.height - surface.bodyHeight, body.pointerHeight)
    }

    function test_fixtureAndGeometry() {
        const view = createView()
        compare(view.currentIndex, -1)
        verify(view.implicitWidth > view.itemSize * 8)
        compare(view.implicitHeight, view.itemSize + view.padding + view.bottomContentPadding + view.waveTopReserve + view.waveBottomReserve)
    }

    function test_clickEmitsIntent() {
        const view = createView()
        activation.target = view
        activation.clear()
        const tile = findChild(view, "launcher-terminal")
        verify(tile !== null)
        mouseClick(tile)
        compare(activation.count, 1)
        compare(activation.signalArguments[0][0], "terminal")
        compare(view.currentIndex, 1)
    }

    function test_hoverDoesNotStealFocus() {
        const view = createView()
        verify(view.focusItem(0))
        const files = findChild(view, "launcher-files")
        const browser = findChild(view, "launcher-browser")
        tryVerify(function() { return files.activeFocus })
        mouseMove(browser)
        tryCompare(browser, "hovered", true)
        verify(files.activeFocus)
        compare(view.currentIndex, 0)
    }

    function test_keyboardAndEscape() {
        const view = createView()
        activation.target = view
        closeSpy.target = view
        activation.clear()
        closeSpy.clear()
        verify(view.focusItem(0))
        keyClick(Qt.Key_Right)
        compare(view.currentIndex, 1)
        keyClick(Qt.Key_Return)
        compare(activation.count, 1)
        compare(activation.signalArguments[0][0], "terminal")
        keyClick(Qt.Key_Left)
        compare(view.currentIndex, 0)
        keyClick(Qt.Key_Left)
        compare(view.currentIndex, 7)
        keyClick(Qt.Key_Escape)
        compare(closeSpy.count, 1)
    }

    function test_liveSettings() {
        const view = createView()
        const previousWidth = view.implicitWidth
        view.itemSize = 80
        view.iconSize = 48
        const tile = findChild(view, "launcher-files")
        compare(tile.itemSize, 80)
        compare(tile.iconSize, 48)
        tryVerify(function() { return view.implicitWidth > previousWidth })
    }

    function test_modelRemovalAndRecreation() {
        const view = createView()
        verify(view.focusItem(7))
        view.entries.remove(7)
        tryCompare(view, "itemCount", 7)
        compare(view.currentIndex, 6)
        view.entries.clear()
        tryCompare(view, "itemCount", 0)
        compare(view.currentIndex, -1)
        verify(!view.focusItem(0))
        view.destroy()
        const next = createView()
        compare(next.currentIndex, -1)
    }
}
