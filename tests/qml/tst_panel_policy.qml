// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../modules/dock"

TestCase {
    name: "DockPanelModes"
    Component { id: fixture; DockPanelPolicy { baseHeight: 54; bottomClearance: 2 } }

    function test_modesAndLiveReservation() {
        const policy = createTemporaryObject(fixture, this)
        verify(policy !== null)
        compare(policy.effectiveMode, "overlay")
        compare(policy.exclusiveZone, 0)
        policy.mode = "reserve"
        compare(policy.exclusiveZone, 56)
        policy.baseHeight = 70
        policy.bottomClearance = 3
        compare(policy.exclusiveZone, 73)
        policy.mode = "desktop"
        compare(policy.effectiveMode, "dodge-windows")
        compare(policy.exclusiveZone, 0)
        policy.mode = "overlay"
        compare(policy.effectiveMode, "overlay")
        compare(policy.exclusiveZone, 0)
    }

    function test_invalidModeDoesNotReserve() {
        const policy = createTemporaryObject(fixture, this)
        for (const mode of ["", "auto-hide", "dodge", "reserve; command"]) {
            verify(!policy.accepts(mode))
            policy.mode = mode
            compare(policy.effectiveMode, "overlay")
            compare(policy.exclusiveZone, 0)
        }
    }
    function test_nativeModesAndReservation() {
        const policy = createTemporaryObject(fixture, this)
        for (const mode of ["reserve", "autohide", "dodge-windows", "overlay"]) {
            verify(policy.accepts(mode))
            policy.mode = mode
            compare(policy.mode, mode)
            compare(policy.effectiveMode, mode)
            compare(policy.exclusiveZone, mode === "reserve" ? 56 : 0)
        }
    }
}
