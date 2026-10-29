// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../modules/dock"

TestCase {
    id: test
    name: "EdgePointerHandoff"
    Component {
        id: fixture
        PunchiDockVisibilityController {
            property bool nativePointerInside: false
            property bool dockPointerInside: false
            pointerInside: nativePointerInside || dockPointerInside
            hideDelay: 40
            transitionDuration: 150
        }
    }
    function init() { failOnWarning(/.*/) }
    function test_holdAndTransfer_data() {
        return [{tag: "auto", dodge: false}, {tag: "dodge", dodge: true}]
    }
    function test_holdAndTransfer(data) {
        const state = createTemporaryObject(fixture, test)
        state.autoHide = !data.dodge
        state.dodgeWindows = data.dodge
        state.overlapAvailable = true
        state.overlapping = true
        tryCompare(state, "surfaceVisible", false)
        state.nativePointerInside = true
        tryCompare(state, "slideProgress", 1)
        wait(180)
        verify(state.revealed)
        // Native leave and Qt enter arrive separately; grace covers the handoff.
        state.nativePointerInside = false
        wait(10)
        state.dockPointerInside = true
        wait(180)
        verify(state.revealed)
        state.dockPointerInside = false
        tryVerify(() => state.slideProgress < 1 && state.slideProgress > 0)
        state.nativePointerInside = true
        tryCompare(state, "slideProgress", 1)
        wait(100)
        verify(state.surfaceVisible)
        state.nativePointerInside = false
        tryCompare(state, "surfaceVisible", false)
    }
}
