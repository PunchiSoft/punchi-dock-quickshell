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
    Component {
        id: longFixture
        PunchiMenuTile {
            x: 20; y: 20; width: 120; height: 120
            title: "A deliberately long application name that overflows"
            iconName: "system-file-manager"
            motionEnabled: true
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

    function test_longLabelRevealsTheFullNameOnKeyboardFocus() {
        const tile = createTemporaryObject(longFixture, test)
        verify(tile !== null)
        const marquee = findChild(tile, "folderMarqueeLabel")
        verify(marquee !== null)
        verify(marquee.overflowing)
        compare(marquee.revealFullText, false)
        const resting = findChild(tile, "folderMarqueeRestingText")
        verify(resting !== null)
        // The menu uses the popup's 0.25 text shadow.
        compare(resting.shadowEnabled, true)
        tile.pointerEmphasis = false
        tile.selected = true
        tryCompare(marquee, "revealFullText", true)
        const moving = findChild(tile, "folderMarqueeMovingText")
        verify(moving !== null)
        tryCompare(moving, "opacity", 1)
    }

    function test_parentClampBeforeLayoutDoesNotRequestADegenerateRaster() {
        const tile = createTemporaryObject(fixture, test)
        verify(tile !== null)
        // The section list passes 1 while its row height is still zero. The tile
        // must treat that as "not laid out", not as a one-pixel icon request.
        tile.iconSize = 1
        tile.width = 0
        tile.height = 0
        tryCompare(tile, "availableWidth", 0)
        verify(tile.iconPixels > 1)
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
