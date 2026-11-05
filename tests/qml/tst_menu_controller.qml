// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../services"

TestCase {
    id: test
    name: "PunchiMenuController"

    Component {
        id: fixture
        PunchiMenuController {}
    }

    function test_oneScreenOwnsTheMenu() {
        const controller = createTemporaryObject(fixture, test)
        verify(controller !== null)
        compare(controller.isOpen("HDMI-A-1"), false)
        verify(controller.open("HDMI-A-1"))
        compare(controller.isOpen("HDMI-A-1"), true)
        compare(controller.isOpen("DP-1"), false)
        verify(controller.open("DP-1"))
        compare(controller.isOpen("HDMI-A-1"), false)
        compare(controller.isOpen("DP-1"), true)
        verify(controller.close())
        compare(controller.isOpen("DP-1"), false)
        compare(controller.open(""), false)
        compare(controller.close(), false)
    }

    function test_mappedSurfaceOutlivesTheOpenState() {
        const controller = createTemporaryObject(fixture, test)
        verify(controller !== null)
        verify(controller.open("HDMI-A-1"))
        // The surface maps with the open state and outlives it during the fade.
        controller.setMapped("HDMI-A-1", true)
        compare(controller.isMapped("HDMI-A-1"), true)
        verify(controller.close())
        compare(controller.isOpen("HDMI-A-1"), false)
        compare(controller.isMapped("HDMI-A-1"), true)
        controller.setMapped("HDMI-A-1", false)
        compare(controller.isMapped("HDMI-A-1"), false)
    }

    function test_onlyTheMappedScreenReleasesItsHold() {
        const controller = createTemporaryObject(fixture, test)
        verify(controller !== null)
        controller.setMapped("", true)
        compare(controller.mappedScreenKey, "")
        controller.setMapped("HDMI-A-1", true)
        // A closing surface on another screen must not release this one.
        controller.setMapped("DP-1", false)
        compare(controller.isMapped("HDMI-A-1"), true)
        controller.setMapped("HDMI-A-1", false)
        compare(controller.isMapped("HDMI-A-1"), false)
    }
}
