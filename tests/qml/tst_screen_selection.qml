// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../config/ScreenSelection.js" as ScreenSelection

TestCase {
    name: "ScreenSelection"

    readonly property var screenLeft: ({name: "DP-1", x: 0, y: 0, width: 1920, height: 1080})
    readonly property var screenRight: ({name: "HDMI-A-1", x: 1920, y: 0, width: 2560, height: 1440})
    readonly property var screenStacked: ({name: "DP-2", x: 0, y: 1080, width: 1920, height: 1080})
    readonly property var allScreens: [screenLeft, screenRight]

    function test_allModeAllowsEveryConnectedScreen() {
        compare(ScreenSelection.resolveScreens(allScreens, "all", [], "HDMI-A-1").length, 2)
        verify(ScreenSelection.allows(screenLeft, allScreens, "all", [], "HDMI-A-1"))
        verify(ScreenSelection.allows(screenRight, allScreens, "all", [], "HDMI-A-1"))
    }

    function test_selectedModeUsesOnlyConfiguredScreens() {
        const configured = ScreenSelection.resolveScreens(allScreens, "selected", ["DP-1"], "HDMI-A-1")
        compare(configured.length, 1)
        compare(configured[0].name, "DP-1")
        verify(ScreenSelection.allows(screenLeft, allScreens, "selected", ["DP-1"], "HDMI-A-1"))
        verify(!ScreenSelection.allows(screenRight, allScreens, "selected", ["DP-1"], "HDMI-A-1"))
    }

    function test_missingSelectionFallsBackToPrimary() {
        const primary = ScreenSelection.resolveScreens(allScreens, "selected", ["DP-9"], "HDMI-A-1")
        compare(primary.length, 1)
        compare(primary[0].name, "HDMI-A-1")
        const first = ScreenSelection.resolveScreens(allScreens, "selected", ["DP-9"], "DP-9")
        compare(first.length, 1)
        compare(first[0].name, "DP-1")
        compare(ScreenSelection.resolveScreens([], "selected", ["DP-1"], "DP-1").length, 0)
    }

    function test_reconnectedScreenIsSelectedAgain() {
        const disconnected = [screenLeft]
        const fallback = ScreenSelection.resolveScreens(disconnected, "selected", ["HDMI-A-1"], "DP-1")
        compare(fallback.length, 1)
        compare(fallback[0].name, "DP-1")
        const reconnected = ScreenSelection.resolveScreens(allScreens, "selected", ["HDMI-A-1"], "DP-1")
        compare(reconnected.length, 1)
        compare(reconnected[0].name, "HDMI-A-1")
    }

    function test_disconnectedSelectionsReportFallback() {
        compare(ScreenSelection.fallbackKey(allScreens, "selected", ["HDMI-A-1"], "DP-1"), "")
        compare(ScreenSelection.fallbackKey([screenLeft], "selected", ["HDMI-A-1"], "DP-1"), "DP-1")
        compare(ScreenSelection.fallbackKey(allScreens, "all", ["HDMI-A-1"], "DP-1"), "")
        compare(ScreenSelection.fallbackKey([], "selected", ["HDMI-A-1"], "DP-1"), "")
        compare(ScreenSelection.fallbackKey([screenLeft], "selected", [], "DP-1"), "DP-1")
        compare(ScreenSelection.disconnectedKeys([screenLeft], ["HDMI-A-1", "DP-1"]).join(","),
            "HDMI-A-1")
        compare(ScreenSelection.disconnectedKeys(allScreens, ["HDMI-A-1"]).length, 0)
    }

    function test_selectionValidation() {
        verify(ScreenSelection.validSelection([]))
        verify(ScreenSelection.validSelection(["DP-1", "HDMI-A-1"]))
        verify(ScreenSelection.validSelection([1, 2]))
        verify(!ScreenSelection.validSelection(undefined))
        verify(!ScreenSelection.validSelection("DP-1"))
        verify(!ScreenSelection.validSelection([""]))
        verify(!ScreenSelection.validSelection([{}]))
        verify(!ScreenSelection.validSelection(new Array(17).fill("DP-1")))
        const normalized = ScreenSelection.normalizeSelection(["DP-1", "DP-1", 2])
        compare(normalized.length, 2)
        compare(normalized[0], "DP-1")
        compare(normalized[1], "2")
    }

    function test_sharedEdgesBetweenScreens() {
        verify(ScreenSelection.edgeIsShared(screenLeft, allScreens, "right"))
        verify(ScreenSelection.edgeIsShared(screenRight, allScreens, "left"))
        verify(!ScreenSelection.edgeIsShared(screenLeft, allScreens, "bottom"))
        verify(!ScreenSelection.edgeIsShared(screenRight, allScreens, "right"))
        verify(ScreenSelection.edgeIsShared(screenLeft, [screenLeft, screenStacked], "bottom"))
        verify(!ScreenSelection.edgeIsShared(screenLeft, [screenLeft], "right"))
    }

    function test_screenPlacementVisibility() {
        const one = [screenLeft]
        // One screen and no fallback has no alternative to choose.
        verify(!ScreenSelection.showsScreenPlacement(one, "all", [], "DP-1"))
        verify(!ScreenSelection.showsScreenPlacement(one, "all", ["HDMI-A-1"], "DP-1"))
        verify(!ScreenSelection.showsScreenPlacement(one, "selected", ["DP-1"], "DP-1"))
        // A disconnected selection, an empty selected mode or a real choice
        // must keep the explanation/selector visible.
        verify(ScreenSelection.showsScreenPlacement(one, "selected", ["HDMI-A-1"], "DP-1"))
        verify(ScreenSelection.showsScreenPlacement(one, "selected", [], "DP-1"))
        verify(ScreenSelection.showsScreenPlacement(one, "selected", ["DP-1", "HDMI-A-1"], "DP-1"))
        verify(ScreenSelection.showsScreenPlacement(allScreens, "all", [], "DP-1"))
        verify(ScreenSelection.showsScreenPlacement(allScreens, "selected", ["DP-1"], "DP-1"))
        verify(ScreenSelection.showsScreenPlacement([], "selected", ["DP-1"], "DP-1"))
        verify(!ScreenSelection.showsScreenPlacement([], "all", [], "DP-1"))
    }

    function test_invalidModes() {
        verify(ScreenSelection.acceptsMode("all"))
        verify(ScreenSelection.acceptsMode("selected"))
        verify(!ScreenSelection.acceptsMode("primary"))
        verify(!ScreenSelection.acceptsTargetMode("current"))
    }
}
