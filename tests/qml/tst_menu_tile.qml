// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import org.kde.kirigami as Kirigami
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

    function test_iconKeepsItsRequestedSizeBeforeTheCellIsLaidOut() {
        const tile = createTemporaryObject(fixture, test)
        verify(tile !== null)
        // A cell without a width must not collapse the icon to one pixel: Qt's
        // SVG renderer reports that raster as an oversized buffer.
        tile.width = 0
        tryCompare(tile, "availableWidth", 0)
        compare(tile.iconPixels, tile.iconSize)
        // Once the cell has a width the icon never exceeds it.
        tile.width = 120
        tryCompare(tile, "availableWidth", 120 - Kirigami.Units.gridUnit)
        verify(tile.iconPixels <= tile.availableWidth)
        compare(tile.contentWidth, tile.availableWidth)
    }
}
