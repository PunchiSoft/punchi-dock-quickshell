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
        verify(!policy.belowWindows)
        policy.mode = "reserve"
        compare(policy.exclusiveZone, 56)
        verify(!policy.belowWindows)
        policy.baseHeight = 70
        policy.bottomClearance = 3
        compare(policy.exclusiveZone, 73)
        policy.mode = "desktop"
        verify(policy.belowWindows)
        compare(policy.exclusiveZone, 0)
        policy.mode = "overlay"
        verify(!policy.belowWindows)
    }

    function test_invalidModeDoesNotReserveOrLower() {
        const policy = createTemporaryObject(fixture, this)
        for (const mode of ["", "auto-hide", "dodge", "reserve; command"]) {
            verify(!policy.accepts(mode))
            policy.mode = mode
            compare(policy.effectiveMode, "overlay")
            compare(policy.exclusiveZone, 0)
            verify(!policy.belowWindows)
        }
    }
    function test_configurationRaisesWithoutChangingModeOrReservation() {
        const policy = createTemporaryObject(fixture, this)
        for (const mode of ["overlay", "reserve", "desktop", "autohide"]) {
            policy.mode = mode
            const reserved = policy.exclusiveZone
            policy.configuring = true
            verify(!policy.belowWindows)
            compare(policy.mode, mode)
            compare(policy.effectiveMode, mode)
            compare(policy.exclusiveZone, reserved)
            policy.configuring = false
            compare(policy.belowWindows, mode === "desktop")
            compare(policy.exclusiveZone, reserved)
        }
    }
}
