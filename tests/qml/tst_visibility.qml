// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../modules/dock"
TestCase {
    name: "DockAutoHide"
    Component { id: fixture; DockVisibilityController { hideDelay: 40; transitionDuration: 40 } }
    function test_hide_then_edge_reveal_and_reversal() {
        const state = createTemporaryObject(fixture, this)
        state.autoHide = true
        tryCompare(state, "revealed", false)
        verify(state.surfaceVisible)
        tryCompare(state, "surfaceVisible", false)
        compare(state.opacity, 0)
        state.reveal()
        verify(state.surfaceVisible)
        state.pointerInside = true
        tryCompare(state, "opacity", 1)
        wait(100)
        verify(state.revealed)
        state.pointerInside = false
        tryCompare(state, "revealed", false)
        state.pointerInside = true
        tryCompare(state, "opacity", 1)
        wait(100)
        verify(state.surfaceVisible)
    }
    function test_slide_intermediate_state_and_continuous_reversal() {
        const state = createTemporaryObject(fixture, this)
        state.transitionDuration = 200
        state.pointerInside = true
        state.autoHide = true
        state.pointerInside = false
        tryVerify(() => state.slideProgress > 0 && state.slideProgress < 1)
        verify(state.surfaceVisible)
        compare(state.opacity, 1)
        const before = state.slideProgress
        state.pointerInside = true
        compare(state.slideProgress, before)
        tryCompare(state, "slideProgress", 1)
        verify(state.surfaceVisible)
        state.pointerInside = false
        tryVerify(() => state.slideProgress > 0 && state.slideProgress < 1)
        state.reducedMotion = true
        tryCompare(state, "slideProgress", 0)
        tryCompare(state, "surfaceVisible", false)
        state.pointerInside = true
        compare(state.slideProgress, 1)
    }
    function test_context_menu_keyboard_and_mode_changes() {
        const state = createTemporaryObject(fixture, this)
        state.autoHide = true
        state.menuOpen = true
        wait(100)
        verify(state.surfaceVisible)
        state.menuOpen = false
        state.keyboardFocused = true
        wait(100)
        verify(state.revealed)
        state.keyboardFocused = false
        tryCompare(state, "surfaceVisible", false)
        state.autoHide = false
        verify(state.surfaceVisible)
        tryCompare(state, "opacity", 1)
    }
    function test_reduced_motion_and_pending_close_cancel() {
        const state = createTemporaryObject(fixture, this)
        state.reducedMotion = true
        state.autoHide = true
        tryCompare(state, "surfaceVisible", false)
        compare(state.opacity, 0)
        state.pointerInside = true
        compare(state.opacity, 1)
        state.pointerInside = false
        state.autoHide = false
        wait(100)
        verify(state.surfaceVisible)
        compare(state.opacity, 1)
    }
    function test_configurationHoldsRevealAndRestoresAutoHide() {
        const state = createTemporaryObject(fixture, this)
        state.autoHide = true
        tryCompare(state, "surfaceVisible", false)
        state.configuring = true
        tryCompare(state, "boundedSlideProgress", 1)
        verify(state.surfaceVisible)
        wait(150)
        verify(state.surfaceVisible)
        verify(state.revealed)
        state.hide()
        verify(state.revealed)
        state.configuring = false
        tryCompare(state, "surfaceVisible", false)
        state.configuring = true
        state.autoHide = false
        verify(state.surfaceVisible)
        state.autoHide = true
        wait(150)
        verify(state.surfaceVisible)
        state.configuring = false
        tryCompare(state, "surfaceVisible", false)
    }
}
