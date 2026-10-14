// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtTest
import "../../modules/dock"
import "../../modules/settings"
import "../../services"
import "../../config"

TestCase {
    id: test
    name: "VerticalDock"
    when: windowShown
    visible: true
    width: 1000
    height: 1000
    Component { id: viewFixture; DockView { entries: DockFixtureModel {} waveEnterDuration: 0; waveLeaveDuration: 0 } }
    Component { id: areaFixture; DockInputArea { hostWidth: 1000; hostHeight: 1000; contentBounds: Qt.rect(100, 200, 300, 400) } }
    Component { id: regionFixture; DockRestingGeometry { screenX: -800; screenY: 50; screenWidth: 800; screenHeight: 600; bodyWidth: 60; bodyHeight: 300; edgeMargin: 5; bottomClearance: 3 } }
    Component { id: settingsFixture; ShellSettings {} }
    Component { id: editorFixture; SettingsEditService {} }
    Component { id: windowFixture; SettingsWindow { settings: ShellSettings {} } }
    Component {
        id: menuFixture
        Window {
            id: host
            visible: true
            width: 900; height: 900
            property string edge: "left"
            property real slideOffset: 0
            property alias view: dock
            property alias menu: popup
            DockView {
                id: dock
                entries: DockFixtureModel {}
                dockEdge: host.edge
                transform: Translate { id: slide; x: host.slideOffset }
                sceneTranslation: Qt.point(slide.x, slide.y)
                y: (host.height - height) / 2 + dock.contentCenterOffset
                x: host.edge === "right" ? host.width - width : 0
                contextMenuOpen: popup.visible || popup.preparingToShow
                onItemActivated: popup.dismiss()
            }
            DockContextPopup {
                id: popup
                dockEdge: host.edge
                hostWindow: host
                hostBaseHeight: host.height
                pinned: true
            }
        }
    }
    function init(): void { failOnWarning(/^(?!This plugin does not support raise\(\)$).*/); mouseMove(test, 900, 900) }
    function test_sideWaveAndKeyboard_data(): var { return [{tag:"left",edge:"left"},{tag:"right",edge:"right"}] }
    function test_sideWaveAndKeyboard(data: var): void {
        const view = createTemporaryObject(viewFixture, test, {dockEdge:data.edge, reducedMotion:false})
        verify(waitForRendering(view))
        const first = findChild(view, "launcher-files")
        const second = findChild(view, "launcher-terminal")
        const third = findChild(view, "launcher-browser")
        verify(first.y < second.y && second.y < third.y)
        compare(first.x, second.x)
        mouseMove(third)
        tryVerify(function() { return third.visualIconScale > 1.5 })
        verify(second.visualIconScale > 1)
        verify(first.iconOffsetY < second.iconOffsetY)
        verify(data.edge === "left" ? third.iconOffsetX > 0 : third.iconOffsetX < 0)
        third.running = true
        const dot = findChild(view, "launcher-running-marker-browser")
        verify(dot.visible)
        fuzzyCompare(dot.x + dot.width / 2, third.iconTopCenter.x, 0.1)
        verify(dot.y >= third.iconTopCenter.y + third.iconSize * third.visualIconScale)
        const tip = findChild(third, "launcher-tooltip") || findChild(view, "launcher-tooltip")
        verify(tip !== null)
        compare(tip.tailEdge, data.edge)
        verify(view.focusItem(0))
        keyClick(Qt.Key_Down)
        compare(view.currentIndex, 1)
        keyClick(Qt.Key_Up)
        compare(view.currentIndex, 0)
        view.dockEdge = "bottom"
        tryVerify(function() { return first.x < second.x })
        compare(first.y, second.y)
        keyClick(Qt.Key_Right)
        compare(view.currentIndex, 1)
    }
    function test_scrollingKeepsAllItemsReachable(): void {
        const view = createTemporaryObject(viewFixture, test, {dockEdge:"left", availableLength:300, reducedMotion:true})
        verify(waitForRendering(view))
        verify(view.maximumScroll > 0)
        compare(view.height, 300)
        fuzzyCompare(view.topPadding + view.itemLength / 2 - view.scrollOffset, view.height / 2, 0.5)
        verify(view.focusItem(view.itemCount - 1))
        const last = findChild(view, "launcher-okular")
        verify(last.y >= 0 && last.y + last.height <= view.height)
        verify(view.scrollOffset > 0)
        verify(view.focusItem(0))
        const first = findChild(view, "launcher-files")
        verify(first.y >= 0 && first.y + first.height <= view.height)
        const previous = view.scrollOffset
        mouseWheel(view, view.leftPadding + view.itemSize / 2, view.height / 2, 0, -120)
        tryVerify(function() { return view.scrollOffset > previous })
    }
    function test_shortVerticalDockCentersLauncherRun_data(): var { return [{tag:"left",edge:"left"},{tag:"right",edge:"right"}] }
    function test_shortVerticalDockCentersLauncherRun(data: var): void {
        const host = createTemporaryObject(menuFixture, test, {edge:data.edge})
        verify(waitForRendering(host.view))
        compare(host.view.maximumScroll, 0)
        fuzzyCompare(host.view.y + host.view.topPadding + host.view.itemLength / 2,
            host.height / 2, 0.5)
        host.close()
    }
    function test_sidePopupFollowsIconAndOtherClick_data(): var { return [{tag:"left",edge:"left"},{tag:"right",edge:"right"}] }
    function test_sidePopupFollowsIconAndOtherClick(data: var): void {
        const host = createTemporaryObject(menuFixture, test, {edge:data.edge})
        verify(waitForRendering(host.view))
        const browser = findChild(host.view, "launcher-browser")
        const kate = findChild(host.view, "launcher-kate")
        mouseMove(browser)
        host.menu.openForItem(browser, browser.title)
        tryCompare(host.menu, "opened", true)
        compare(host.menu.mainItem.tailEdge, data.edge)
        tryVerify(function() { return browser.visualIconScale === 2 })
        const top = browser.parent.mapToItem(host.contentItem, browser.iconTopCenter.x, browser.iconTopCenter.y)
        const size = browser.iconSize * browser.visualIconScale
        const rect = Qt.rect(top.x - size / 2, top.y, size, size)
        if (data.edge === "left") verify(host.menu.x >= rect.x + rect.width)
        else verify(host.menu.x + host.menu.width <= rect.x)
        verify(host.menu.y >= 0)
        verify(host.menu.y + host.menu.height <= host.height)
        fuzzyCompare(host.menu.y + host.menu.mainItem.pointerCenter, rect.y + rect.height / 2, 1)
        const height = host.height
        const originalX = host.menu.x
        host.slideOffset = 10
        tryCompare(host.menu, "x", originalX + 10)
        host.slideOffset = 0
        tryCompare(host.menu, "x", originalX)
        mouseMove(kate)
        tryCompare(kate, "hovered", true)
        mouseClick(kate)
        tryCompare(host.menu, "visible", false)
        compare(host.height, height)
        compare(host.view.currentIndex, 3)
        host.close()
    }
    function test_pointerClearanceAndRestingGeometry(): void {
        const area = createTemporaryObject(areaFixture, test)
        area.dockEdge = "left"
        compare(area.x, 0); compare(area.width, 400)
        compare(area.y, 200); compare(area.height, 400)
        mouseMove(test, 2, 350)
        tryCompare(area, "hovered", true)
        mouseMove(test, 450, 350)
        tryCompare(area, "hovered", false)
        area.dockEdge = "right"
        compare(area.x, 100); compare(area.width, 900)
        mouseMove(test, 998, 350)
        tryCompare(area, "hovered", true)
        area.surfaceVisible = false; area.nativeEdgeAvailable = true
        compare(area.width, 0)
        area.nativeEdgeAvailable = false
        area.edgeLength = 400
        compare(area.y, 300); compare(area.height, 400)
        const region = createTemporaryObject(regionFixture, test)
        region.dockEdge = "left"
        compare(region.region, Qt.rect(-792, 200, 60, 300))
        region.dockEdge = "right"
        compare(region.region, Qt.rect(-68, 200, 60, 300))
    }
    function test_positionControlDraftApplyAndLegacyRestore(): void {
        const window = createTemporaryObject(windowFixture, test)
        window.open(); verify(waitForRendering(window.contentItem))
        const view = findChild(window.contentItem, "dockSettingsView")
        const combo = findChild(window.contentItem, "dockPosition")
        combo.forceActiveFocus(Qt.TabFocusReason)
        keyClick(Qt.Key_End)
        keyClick(Qt.Key_Return)
        tryCompare(view.settings, "dockEdge", "right")
        compare(window.settings.dockEdge, "bottom")
        mouseClick(findChild(window.contentItem, "applyDockSettings"))
        compare(window.settings.dockEdge, "right")
        window.settings.dockEdge = "left"
        compare(view.settings.dockEdge, "left")
        compare(combo.currentIndex, 1)
        combo.forceActiveFocus(Qt.TabFocusReason)
        keyClick(Qt.Key_Home)
        keyClick(Qt.Key_Return)
        tryCompare(view.settings, "dockEdge", "bottom")
        compare(window.settings.dockEdge, "left")
        window.close()
        window.open()
        compare(view.settings.dockEdge, "left")
        const saved = window.settings.snapshot()
        const restored = createTemporaryObject(settingsFixture, test)
        verify(restored.restore(JSON.parse(JSON.stringify(saved))))
        compare(restored.dockEdge, "left")
        saved.dockEdge = "invalid"; restored.restore(saved)
        compare(restored.dockEdge, "left")
        delete saved.dockEdge; restored.restore(saved)
        compare(restored.dockEdge, "bottom")
        window.close()
    }
}
