// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../config/PunchiScreenSelection.js" as PunchiScreenSelection

TestCase {
    name: "PunchiScreenSelection"

    readonly property var screenLeft: ({name: "DP-1", x: 0, y: 0, width: 1920, height: 1080})
    readonly property var screenRight: ({name: "HDMI-A-1", x: 1920, y: 0, width: 2560, height: 1440})
    readonly property var screenStacked: ({name: "DP-2", x: 0, y: 1080, width: 1920, height: 1080})
    readonly property var allScreens: [screenLeft, screenRight]

    function test_allModeAllowsEveryConnectedScreen() {
        compare(PunchiScreenSelection.resolveScreens(allScreens, "all", [], "HDMI-A-1").length, 2)
        verify(PunchiScreenSelection.allows(screenLeft, allScreens, "all", [], "HDMI-A-1"))
        verify(PunchiScreenSelection.allows(screenRight, allScreens, "all", [], "HDMI-A-1"))
    }

    function test_selectedModeUsesOnlyConfiguredScreens() {
        const configured = PunchiScreenSelection.resolveScreens(allScreens, "selected", ["DP-1"], "HDMI-A-1")
        compare(configured.length, 1)
        compare(configured[0].name, "DP-1")
        verify(PunchiScreenSelection.allows(screenLeft, allScreens, "selected", ["DP-1"], "HDMI-A-1"))
        verify(!PunchiScreenSelection.allows(screenRight, allScreens, "selected", ["DP-1"], "HDMI-A-1"))
    }

    function test_missingSelectionFallsBackToPrimary() {
        const primary = PunchiScreenSelection.resolveScreens(allScreens, "selected", ["DP-9"], "HDMI-A-1")
        compare(primary.length, 1)
        compare(primary[0].name, "HDMI-A-1")
        const first = PunchiScreenSelection.resolveScreens(allScreens, "selected", ["DP-9"], "DP-9")
        compare(first.length, 1)
        compare(first[0].name, "DP-1")
        compare(PunchiScreenSelection.resolveScreens([], "selected", ["DP-1"], "DP-1").length, 0)
    }

    function test_reconnectedScreenIsSelectedAgain() {
        const disconnected = [screenLeft]
        const fallback = PunchiScreenSelection.resolveScreens(disconnected, "selected", ["HDMI-A-1"], "DP-1")
        compare(fallback.length, 1)
        compare(fallback[0].name, "DP-1")
        const reconnected = PunchiScreenSelection.resolveScreens(allScreens, "selected", ["HDMI-A-1"], "DP-1")
        compare(reconnected.length, 1)
        compare(reconnected[0].name, "HDMI-A-1")
    }

    function test_disconnectedSelectionsReportFallback() {
        compare(PunchiScreenSelection.fallbackKey(allScreens, "selected", ["HDMI-A-1"], "DP-1"), "")
        compare(PunchiScreenSelection.fallbackKey([screenLeft], "selected", ["HDMI-A-1"], "DP-1"), "DP-1")
        compare(PunchiScreenSelection.fallbackKey(allScreens, "all", ["HDMI-A-1"], "DP-1"), "")
        compare(PunchiScreenSelection.fallbackKey([], "selected", ["HDMI-A-1"], "DP-1"), "")
        compare(PunchiScreenSelection.fallbackKey([screenLeft], "selected", [], "DP-1"), "DP-1")
        compare(PunchiScreenSelection.disconnectedKeys([screenLeft], ["HDMI-A-1", "DP-1"]).join(","),
            "HDMI-A-1")
        compare(PunchiScreenSelection.disconnectedKeys(allScreens, ["HDMI-A-1"]).length, 0)
    }

    function test_selectionValidation() {
        verify(PunchiScreenSelection.validSelection([]))
        verify(PunchiScreenSelection.validSelection(["DP-1", "HDMI-A-1"]))
        verify(PunchiScreenSelection.validSelection([1, 2]))
        verify(!PunchiScreenSelection.validSelection(undefined))
        verify(!PunchiScreenSelection.validSelection("DP-1"))
        verify(!PunchiScreenSelection.validSelection([""]))
        verify(!PunchiScreenSelection.validSelection([{}]))
        verify(!PunchiScreenSelection.validSelection(new Array(17).fill("DP-1")))
        const normalized = PunchiScreenSelection.normalizeSelection(["DP-1", "DP-1", 2])
        compare(normalized.length, 2)
        compare(normalized[0], "DP-1")
        compare(normalized[1], "2")
    }

    function test_sharedEdgesBetweenScreens() {
        verify(PunchiScreenSelection.edgeIsShared(screenLeft, allScreens, "right"))
        verify(PunchiScreenSelection.edgeIsShared(screenRight, allScreens, "left"))
        verify(!PunchiScreenSelection.edgeIsShared(screenLeft, allScreens, "bottom"))
        verify(!PunchiScreenSelection.edgeIsShared(screenRight, allScreens, "right"))
        verify(PunchiScreenSelection.edgeIsShared(screenLeft, [screenLeft, screenStacked], "bottom"))
        verify(!PunchiScreenSelection.edgeIsShared(screenLeft, [screenLeft], "right"))
    }

    function test_screenPlacementVisibility() {
        const one = [screenLeft]
        // One screen and no fallback has no alternative to choose.
        verify(!PunchiScreenSelection.showsScreenPlacement(one, "all", [], "DP-1"))
        verify(!PunchiScreenSelection.showsScreenPlacement(one, "all", ["HDMI-A-1"], "DP-1"))
        verify(!PunchiScreenSelection.showsScreenPlacement(one, "selected", ["DP-1"], "DP-1"))
        // A disconnected selection, an empty selected mode or a real choice
        // must keep the explanation/selector visible.
        verify(PunchiScreenSelection.showsScreenPlacement(one, "selected", ["HDMI-A-1"], "DP-1"))
        verify(PunchiScreenSelection.showsScreenPlacement(one, "selected", [], "DP-1"))
        verify(PunchiScreenSelection.showsScreenPlacement(one, "selected", ["DP-1", "HDMI-A-1"], "DP-1"))
        verify(PunchiScreenSelection.showsScreenPlacement(allScreens, "all", [], "DP-1"))
        verify(PunchiScreenSelection.showsScreenPlacement(allScreens, "selected", ["DP-1"], "DP-1"))
        verify(PunchiScreenSelection.showsScreenPlacement([], "selected", ["DP-1"], "DP-1"))
        verify(!PunchiScreenSelection.showsScreenPlacement([], "all", [], "DP-1"))
    }

    function test_invalidModes() {
        verify(PunchiScreenSelection.acceptsMode("all"))
        verify(PunchiScreenSelection.acceptsMode("selected"))
        verify(!PunchiScreenSelection.acceptsMode("primary"))
        verify(!PunchiScreenSelection.acceptsTargetMode("current"))
    }
}
