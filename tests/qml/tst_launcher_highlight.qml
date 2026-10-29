// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../../modules/dock"
import "../../services"

TestCase {
    id: test
    name: "PunchiDockHighlight"
    when: windowShown
    visible: true
    width: 840
    height: 320
    Component { id: fixture; PunchiDockView { entries: PunchiDockFixtureModel {} clickDuration: 0 } }
    function init() { failOnWarning(/.*/); mouseMove(test, 830, 310) }
    function test_pointerHoverAndClickNeverLeaveAKeyboardOutline() {
        const view = createTemporaryObject(fixture, test)
        verify(waitForRendering(view))
        const tile = findChild(view, "launcher-browser")
        const fill = findChild(tile, "launcher-highlight")
        const outline = findChild(tile, "launcher-focus-outline")
        mouseMove(tile)
        tryCompare(tile, "hovered", true)
        compare(fill.color.a, 0.2)
        compare(fill.border.width, 0)
        verify(!outline.visible)
        mouseClick(tile)
        verify(!tile.visualFocus)
        verify(!outline.visible)
        mouseMove(test, 830, 310)
        tryCompare(tile, "hovered", false)
        compare(fill.color.a, 0)
        verify(!outline.visible)
    }
    function test_keyboardOutlineIsAboveIconAndFollowsItsGeometry() {
        const view = createTemporaryObject(fixture, test)
        verify(waitForRendering(view))
        const first = findChild(view, "launcher-files")
        const second = findChild(view, "launcher-terminal")
        const outline = findChild(first, "launcher-focus-outline")
        const border = findChild(first, "launcher-focus-border")
        verify(view.focusItem(0))
        verify(first.visualFocus)
        verify(outline.visible)
        verify(outline.z > first.contentItem.z)
        verify(border.border.width > 0)
        verify(outline.width > first.iconSize)
        mouseMove(second)
        tryCompare(second, "targetIconScale", 2)
        verify(first.visualFocus) // Hover must not move keyboard focus.
        const firstRight = outline.mapToItem(view, outline.width, outline.height / 2)
        const secondLeft = second.background.mapToItem(view, 0, second.background.height / 2)
        verify(firstRight.x <= secondLeft.x, "Neighbor highlight bounds overlap")
        const frameCenter = outline.mapToItem(view, outline.width / 2, outline.height / 2)
        const iconCenter = first.contentItem.mapToItem(view, first.contentItem.width / 2, first.contentItem.height / 2)
        fuzzyCompare(frameCenter.x, iconCenter.x, 0.001)
        fuzzyCompare(frameCenter.y, iconCenter.y, 0.001)
        keyClick(Qt.Key_Right)
        verify(second.visualFocus)
        verify(!outline.visible)
        mouseClick(first)
        verify(!findChild(second, "launcher-focus-outline").visible)
        verify(!outline.visible)
    }
}
