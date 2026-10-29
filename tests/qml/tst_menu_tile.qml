// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../../modules/menu"

TestCase {
    id: test
    name: "PunchiMenuTile"
    when: windowShown
    visible: true
    width: 400
    height: 300

    Component {
        id: fixture
        PunchiMenuTile {
            x: 20; y: 20; width: 120; height: 120
            title: "Files"
            iconName: "system-file-manager"
            motionEnabled: false
        }
    }

    function init() {
        failOnWarning(/.*/)
        mouseMove(test, 390, 290)
    }

    function test_oneBandOnly() {
        const tile = createTemporaryObject(fixture, test)
        verify(tile !== null)
        const highlight = tile.children[0]
        // The keyboard owns the band: only the selection paints.
        tile.pointerEmphasis = false
        tile.selected = true
        compare(highlight.selected, true)
        compare(highlight.hovered, false)
        // The pointer owns it: only the hover paints, and selection stays quiet.
        tile.pointerEmphasis = true
        mouseMove(tile, 10, 10)
        tryCompare(tile, "hovered", true)
        compare(highlight.hovered, true)
        compare(highlight.selected, false)
    }

    function test_hoverNeverPaintsOverTheKeyboardBand() {
        const tile = createTemporaryObject(fixture, test)
        verify(tile !== null)
        const highlight = tile.children[0]
        tile.pointerEmphasis = false
        tile.selected = true
        mouseMove(tile, 10, 10)
        compare(tile.hovered, false)
        compare(highlight.hovered, false)
        compare(highlight.selected, true)
    }

    function test_pointerShowsAHand() {
        const tile = createTemporaryObject(fixture, test)
        verify(tile !== null)
        const pointer = findChild(tile, "menuTilePointer")
        verify(pointer !== null)
        compare(pointer.cursorShape, Qt.PointingHandCursor)
        verify(pointer.hoverEnabled)
    }

    function test_reducedMotionKeepsTheBandStill() {
        const tile = createTemporaryObject(fixture, test)
        verify(tile !== null)
        const highlight = tile.children[0]
        tile.motionEnabled = false
        tile.pointerEmphasis = true
        mouseMove(tile, 10, 10)
        tryCompare(highlight, "hovered", true)
        compare(highlight.scale, 1.0)
    }
}
