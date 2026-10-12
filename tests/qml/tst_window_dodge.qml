// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../../modules/dock"
import "../../modules/settings"
import "../../services"
import "../../config"

TestCase {
    id: test
    name: "WindowDodge"
    when: windowShown
    visible: true
    width: 900
    height: 500
    Component { id: controller; DockVisibilityController { dodgeWindows: true; hideDelay: 10; transitionDuration: 30 } }
    Component { id: geometry; DockRestingGeometry { screenX: -1920; screenY: -200; screenWidth: 1920; screenHeight: 1080; bodyWidth: 480; bodyHeight: 54; bottomClearance: 2; edgeMargin: 4 } }
    Component { id: general; DockGeneralSettings { width: 700; height: 440; settings: ShellSettings {} } }
    Component { id: preferences; ShellSettings {} }
    Component { id: policy; DockPanelPolicy {} }
    function init() { failOnWarning(/.*/) }
    function test_unknownAndNonoverlappingRemainVisible() {
        const state = createTemporaryObject(controller, test)
        state.overlapping = true
        wait(100)
        verify(state.surfaceVisible)
        verify(!state.shouldHide)
        state.overlapAvailable = true
        tryCompare(state, "surfaceVisible", false)
        state.overlapping = false
        tryCompare(state, "slideProgress", 1)
        verify(state.surfaceVisible)
        wait(100)
        verify(state.revealed)
    }
    function test_showDesktopRevealsAndRestoredOverlapHides() {
        const state = createTemporaryObject(controller, test)
        state.overlapAvailable = true
        state.overlapping = true
        tryCompare(state, "surfaceVisible", false)
        state.showingDesktop = true
        tryCompare(state, "slideProgress", 1)
        verify(state.surfaceVisible)
        wait(100)
        verify(state.revealed)
        state.showingDesktop = false
        tryCompare(state, "surfaceVisible", false)
        state.overlapAvailable = false
        tryCompare(state, "slideProgress", 1)
        verify(state.surfaceVisible)
    }
    function test_autoHideKeepsItsEdgePolicyDuringShowDesktop() {
        const state = createTemporaryObject(controller, test)
        state.dodgeWindows = false
        state.autoHide = true
        state.showingDesktop = true
        tryCompare(state, "surfaceVisible", false)
        state.reveal()
        state.pointerInside = true
        tryCompare(state, "slideProgress", 1)
        wait(100)
        verify(state.surfaceVisible)
        state.pointerInside = false
        tryCompare(state, "surfaceVisible", false)
    }
    function test_menuKeyboardConfigurationAndEdgeHold() {
        const state = createTemporaryObject(controller, test)
        state.overlapAvailable = true
        state.overlapping = true
        for (const hold of ["menuOpen", "keyboardFocused", "configuring", "pointerInside"]) {
            state[hold] = true
            tryCompare(state, "slideProgress", 1)
            wait(100)
            verify(state.revealed)
            state.hide()
            verify(state.revealed)
            state[hold] = false
            tryCompare(state, "surfaceVisible", false)
        }
        state.reveal()
        verify(state.surfaceVisible)
        tryCompare(state, "surfaceVisible", false)
    }
    function test_reducedMotionAndModeRestoration() {
        const state = createTemporaryObject(controller, test)
        state.reducedMotion = true
        state.overlapAvailable = true
        state.overlapping = true
        tryCompare(state, "surfaceVisible", false)
        state.dodgeWindows = false
        compare(state.surfaceVisible, true)
        compare(state.slideProgress, 1)
        state.dodgeWindows = true
        tryCompare(state, "surfaceVisible", false)
        state.showingDesktop = true
        compare(state.slideProgress, 1)
    }
    function test_logicalRestingRectangleAndMonitorChanges() {
        const region = createTemporaryObject(geometry, test)
        compare(region.region, Qt.rect(-1200, 820, 480, 54))
        region.screenX = 1920
        region.screenWidth = 2560
        region.screenY = 0
        compare(region.region, Qt.rect(2960, 1020, 480, 54))
        region.bodyWidth = 600
        region.bodyHeight = 70
        compare(region.region, Qt.rect(2900, 1004, 600, 70))
    }
    function test_keyboardModeSelectionAndPersistence() {
        const view = createTemporaryObject(general, test)
        view.settings.panelMode = "autohide"
        const control = findChild(view, "visibilityMode")
        compare(control.count, 5)
        compare(control.currentIndex, 3)
        control.forceActiveFocus()
        keyClick(Qt.Key_Down)
        compare(view.settings.panelMode, "dodge-windows")
        compare(control.currentIndex, 4)
        const saved = view.settings.snapshot()
        const restored = createTemporaryObject(preferences, test)
        verify(restored.restore(saved))
        compare(restored.panelMode, "dodge-windows")
        const panel = createTemporaryObject(policy, test)
        panel.mode = restored.panelMode
        verify(panel.accepts("dodge-windows"))
        compare(panel.exclusiveZone, 0)
        verify(!panel.belowWindows)
        panel.mode = "desktop"
        verify(panel.belowWindows)
    }
}
