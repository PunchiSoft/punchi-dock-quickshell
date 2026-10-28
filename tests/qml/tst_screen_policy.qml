// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../config"
import "../../services"

TestCase {
    name: "ScreenPolicy"

    Component {
        id: fixture
        ScreenPolicy {
            settings: ShellSettings {}
            connectedScreens: [{name: "DP-1"}, {name: "HDMI-A-1"}]
            primaryScreenName: "HDMI-A-1"
        }
    }

    function test_allScreensAllowEveryConnectedScreen() {
        const policy = createTemporaryObject(fixture, this)
        compare(policy.activeScreens.length, 2)
        verify(policy.allows(policy.connectedScreens[0]))
        verify(policy.allows(policy.connectedScreens[1]))
    }

    function test_selectedScreenAndHotPlug() {
        const policy = createTemporaryObject(fixture, this)
        policy.settings.screenMode = "selected"
        policy.settings.selectedScreens = ["DP-1"]
        verify(policy.allows(policy.connectedScreens[0]))
        verify(!policy.allows(policy.connectedScreens[1]))
        // The selected screen disappears: the primary takes over.
        policy.connectedScreens = [{name: "HDMI-A-1"}]
        compare(policy.activeScreens.length, 1)
        compare(policy.activeScreens[0].name, "HDMI-A-1")
        // Reconnecting restores the configured screen.
        policy.connectedScreens = [{name: "DP-1"}, {name: "HDMI-A-1"}]
        compare(policy.activeScreens.length, 1)
        compare(policy.activeScreens[0].name, "DP-1")
    }

    function test_sharedEdgeFollowsScreenGeometry() {
        const policy = createTemporaryObject(fixture, this)
        policy.connectedScreens = [
            {name: "DP-1", x: 0, y: 0, width: 1920, height: 1080},
            {name: "HDMI-A-1", x: 1920, y: 0, width: 2560, height: 1440}]
        verify(policy.isSharedEdge(policy.connectedScreens[0], "right"))
        verify(policy.isSharedEdge(policy.connectedScreens[1], "left"))
        verify(!policy.isSharedEdge(policy.connectedScreens[0], "bottom"))
    }
}
