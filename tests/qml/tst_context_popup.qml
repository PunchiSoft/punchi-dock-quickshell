// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtTest
import org.kde.kirigami as Kirigami
import "../../modules/dock"
import "../../services"

TestCase {
    id: test
    name: "DockContextAllocation"
    when: windowShown
    Component {
        id: fixture
        Window {
            id: viewport
            visible: true
            width: 600
            property real baseHeight: 160
            height: baseHeight + Math.ceil(menu.topOverflow)
            property alias testView: dock
            property alias testMenu: menu
            DockView {
                id: dock
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                height: implicitHeight
                entries: DockFixtureModel {}
                magnificationEnabled: false
                onItemActivated: menu.dismiss()
                contextMenuOpen: menu.visible || menu.preparingToShow
            }
            DockContextPopup {
                id: menu
                hostWindow: viewport
                hostBaseHeight: viewport.baseHeight
                canLaunchNewWindow: true
                pinned: true
                actions: [
                    {actionId: "first", name: "First", icon: "window-new"},
                    {actionId: "second", name: "Second", icon: "window-new"},
                    {actionId: "third", name: "Third", icon: "window-new"},
                    {actionId: "fourth", name: "Fourth", icon: "window-new"},
                    {actionId: "fifth", name: "Fifth", icon: "window-new"}]
            }
        }
    }
    Component {
        id: stableFixture
        Window {
            id: viewport
            visible: true
            width: 600
            height: geometry.windowHeight
            property alias testGeometry: geometry
            property alias testView: dock
            property alias testMenu: menu
            DockWindowGeometry {
                id: geometry
                baseHeight: dock.implicitHeight
                screenHeight: 700
            }
            DockView {
                id: dock
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                height: implicitHeight
                entries: DockFixtureModel {}
                contextMenuOpen: menu.visible || menu.preparingToShow
                onItemActivated: menu.dismiss()
            }
            DockContextPopup {
                id: menu
                hostWindow: viewport
                hostBaseHeight: geometry.baseHeight
                pinned: true
            }
        }
    }
    SignalSpy { id: activation; signalName: "itemActivated" }
    function init() { failOnWarning(/.*/) }
    function test_repeatedMenusKeepWindowAndHoverStable() {
        const viewport = createTemporaryObject(stableFixture, test)
        const dock = viewport.testView
        const menu = viewport.testMenu
        tryCompare(dock, "itemCount", 8)
        verify(waitForRendering(dock))
        tryCompare(dock, "y", viewport.height - dock.height)
        const browser = findChild(dock, "launcher-browser")
        const kate = findChild(dock, "launcher-kate")
        const height = viewport.height
        const baseline = dock.y
        const resize = createTemporaryQmlObject('import QtTest; SignalSpy { signalName: "heightChanged" }', test)
        resize.target = viewport
        activation.target = dock
        activation.clear()
        for (let i = 0; i < 4; ++i) {
            mouseMove(dock, browser.x + browser.width / 2, browser.y + browser.height / 2)
            tryCompare(browser, "targetIconScale", 2)
            menu.actions = i % 2 === 0 ? [
                {actionId: "first", name: "First", icon: "window-new"},
                {actionId: "second", name: "Second", icon: "window-new"},
                {actionId: "third", name: "Third", icon: "window-new"},
                {actionId: "fourth", name: "Fourth", icon: "window-new"},
                {actionId: "fifth", name: "Fifth", icon: "window-new"}] : []
            menu.openForItem(browser, browser.title)
            tryCompare(menu, "opened", true)
            compare(viewport.height, height)
            compare(dock.y, baseline)
            verify(menu.y >= 0)
            mouseMove(dock, kate.x + kate.width / 2, kate.y + kate.height / 2)
            tryCompare(kate, "targetIconScale", 2)
            tryCompare(kate, "hovered", true)
            mouseClick(kate, kate.width / 2, kate.height / 2, Qt.LeftButton)
            tryCompare(menu, "visible", false)
            compare(activation.count, i + 1)
            compare(activation.signalArguments[i][0], "kate")
            // No subsequent mouse move may be required to recover magnification.
            wait(dock.waveLeaveDuration + 30)
            compare(kate.targetIconScale, 2)
            compare(viewport.height, height)
            compare(dock.y, baseline)
            compare(resize.count, 0)
        }
        viewport.testGeometry.surfaceVisible = false
        tryCompare(viewport, "height", 1)
        viewport.testGeometry.surfaceVisible = true
        tryCompare(viewport, "height", height)
        viewport.testGeometry.screenHeight = 600
        tryCompare(viewport, "height", 600)
    }

    function test_tallMenuAllocationRetargetsWithoutMovingDockBaseline() {
        const viewport = createTemporaryObject(fixture, test)
        verify(viewport !== null)
        const dock = viewport.testView
        const menu = viewport.testMenu
        tryCompare(dock, "itemCount", 8)
        const first = findChild(dock, "launcher-systemsettings")
        const second = findChild(dock, "launcher-browser")
        verify(waitForRendering(dock))
        tryCompare(dock, "y", viewport.height - dock.height)
        const initialHeight = viewport.height
        const initialBaseline = viewport.height - dock.y
        const initialSurfaceHeight = dock.surfaceBounds.height
        menu.openForItem(first, first.title)
        tryCompare(menu, "opened", true)
        verify(menu.topOverflow > 0)
        tryCompare(viewport, "height", initialHeight + Math.ceil(menu.topOverflow))
        tryCompare(dock, "y", viewport.height - dock.height)
        verify(menu.y >= 0)
        compare(viewport.height - dock.y, initialBaseline)
        compare(dock.surfaceBounds.height, initialSurfaceHeight)
        const top = first.parent.mapToItem(viewport.contentItem, first.iconTopCenter.x, first.iconTopCenter.y)
        fuzzyCompare(menu.y + menu.height + Kirigami.Units.smallSpacing, top.y, 1)
        const expandedHeight = viewport.height
        menu.openForItem(second, second.title)
        tryCompare(menu, "sourceItem", second)
        tryCompare(menu, "preparingToShow", false)
        compare(viewport.height, expandedHeight)
        const nextTop = second.parent.mapToItem(viewport.contentItem, second.iconTopCenter.x, second.iconTopCenter.y)
        fuzzyCompare(menu.y + menu.height + Kirigami.Units.smallSpacing, nextTop.y, 1)
        fuzzyCompare(menu.x + menu.mainItem.pointerX, nextTop.x, 1)
        activation.target = dock
        activation.clear()
        const third = findChild(dock, "launcher-kate")
        mouseMove(third, third.width / 2, third.height / 2)
        tryCompare(third, "hovered", true)
        mouseClick(third, third.width / 2, third.height / 2, Qt.LeftButton)
        compare(activation.count, 1)
        compare(activation.signalArguments[0][0], "kate")
        tryCompare(viewport, "height", initialHeight)
        tryCompare(dock, "y", viewport.height - dock.height)
        compare(menu.topOverflow, 0)
        compare(viewport.height - dock.y, initialBaseline)
    }
    function test_rowsOwnThePointingHandCursor() {
        const viewport = createTemporaryObject(fixture, test)
        verify(viewport !== null)
        const dock = viewport.testView
        const menu = viewport.testMenu
        tryCompare(dock, "itemCount", 8)
        const first = findChild(dock, "launcher-systemsettings")
        verify(waitForRendering(dock))
        menu.openForItem(first, first.title)
        tryCompare(menu, "opened", true)
        // The shared popup row declares the family hand, so every row of the
        // context menu inherits it without repeating the declaration.
        for (const name of ["openNewWindowAction", "configureDockAction"]) {
            const candidate = findChild(menu.mainItem, name)
            verify(candidate !== null, name)
            const handler = findChild(candidate, "popupRowCursor")
            verify(handler !== null, name)
            compare(handler.cursorShape, Qt.PointingHandCursor, name)
            compare(handler.enabled, candidate.enabled, name)
        }
        const row = findChild(menu.mainItem, "openNewWindowAction")
        const cursor = findChild(row, "popupRowCursor")
        mouseMove(row, row.width / 2, row.height / 2)
        tryCompare(row, "hovered", true)
        tryCompare(cursor, "hovered", true)
        // A row that cannot act stops asking for the hand: its handler is
        // disabled with the row, so it also stops reporting hover.
        row.enabled = false
        tryCompare(cursor, "enabled", false)
        tryCompare(cursor, "hovered", false)
        menu.dismiss()
    }
}
