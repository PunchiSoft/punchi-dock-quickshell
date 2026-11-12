// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../config/PunchiScreenSelection.js" as ScreenSelection

TestCase {
    name: "PunchiMenuShortcutPolicy"

    readonly property var twoScreens: [{name: "DP-1"}, {name: "HDMI-A-1"}]

    function test_singleAllowedScreenIsDefault() {
        const screen = ScreenSelection.preferredScreenKey(
            [{name: "eDP-1"}], "selected", ["eDP-1"], "eDP-1", "", "")
        compare(screen, "eDP-1")
    }

    function test_pointerScreenWinsWhenAllowed() {
        const screen = ScreenSelection.preferredScreenKey(
            twoScreens, "all", [], "HDMI-A-1", "DP-1", "HDMI-A-1")
        compare(screen, "DP-1")
    }

    function test_pointerScreenOutsideTheSelectionIsIgnored() {
        const screen = ScreenSelection.preferredScreenKey(
            twoScreens, "selected", ["DP-1"], "HDMI-A-1", "HDMI-A-1", "")
        compare(screen, "DP-1")
    }

    function test_lastUsedScreenFollowsThePointer() {
        const screen = ScreenSelection.preferredScreenKey(
            twoScreens, "all", [], "HDMI-A-1", "", "DP-1")
        compare(screen, "DP-1")
    }

    function test_disconnectedLastScreenFallsBackToPrimary() {
        const screen = ScreenSelection.preferredScreenKey(
            [{name: "DP-1"}], "all", [], "DP-1", "", "HDMI-A-1")
        compare(screen, "DP-1")
    }

    function test_selectedOrderIsTheLastFallback() {
        const screen = ScreenSelection.preferredScreenKey(
            twoScreens, "selected", ["HDMI-A-1", "DP-1"], "HDMI-A-1", "", "")
        compare(screen, "HDMI-A-1")
    }

    function test_primaryIsUsedWhenNoHistoryExists() {
        const screen = ScreenSelection.preferredScreenKey(
            twoScreens, "all", [], "HDMI-A-1", "", "")
        compare(screen, "HDMI-A-1")
    }

    function test_noAllowedScreenReturnsEmpty() {
        compare(ScreenSelection.preferredScreenKey([], "all", [], "DP-1", "", ""), "")
        compare(ScreenSelection.preferredScreenKey(
            [], "selected", ["DP-1"], "HDMI-A-1", "DP-1", "DP-1"), "")
    }
}
