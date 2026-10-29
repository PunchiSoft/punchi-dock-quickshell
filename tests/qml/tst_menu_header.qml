// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../../modules/menu"

TestCase {
    id: test
    name: "PunchiMenuHeader"
    when: windowShown
    visible: true
    width: 800
    height: 240

    Component {
        id: fixture
        PunchiMenuHeader { width: 760; height: 200; distributionName: "Test" }
    }

    function test_closeButtonKeepsItsConfiguredCorner() {
        const header = createTemporaryObject(fixture, test)
        verify(header !== null)
        const button = findChild(header, "menuCloseButton")
        verify(button !== null)
        compare(button.width, header.controlSize)
        compare(button.height, header.controlSize)
        // The control is never invisible: it draws the decoration button or
        // the theme icon fallback.
        verify(button.visible)
        // Right is the default, so the button ends at the header's right edge.
        fuzzyCompare(button.x + button.width, header.width, 0.5)
        fuzzyCompare(button.y, 0, 0.5)
        header.closeButtonPosition = "left"
        tryCompare(button, "x", 0)
        fuzzyCompare(button.y, 0, 0.5)
    }

    function test_searchStaysCentredWhileTheCornerHoldsTheCloseButton() {
        const header = createTemporaryObject(fixture, test)
        verify(header !== null)
        const search = findChild(header, "menuSearchField")
        verify(search !== null)
        const centre = search.mapToItem(header, search.width / 2, 0).x
        fuzzyCompare(centre, header.width / 2, 1)
    }

    function test_closeButtonUsesTheDecorationWithAFallback() {
        const header = createTemporaryObject(fixture, test)
        verify(header !== null)
        const button = findChild(header, "menuCloseButton")
        verify(button !== null)
        compare(button.role, "close")
        compare(button.fallbackIconName, "window-close")
        // A decoration path either resolves to the user's theme or stays empty and
        // the fallback icon paints; both keep the control visible.
        if (button.decorationImagePath.length > 0) {
            verify(button.decorationImagePath.endsWith(".svg"))
            verify(button.decorationButtonSize.width >= 8)
        }
        verify(button.implicitWidth >= button.fallbackIconSize)
    }

    function test_closeRequestIsEmittedOnce() {
        const header = createTemporaryObject(fixture, test)
        verify(header !== null)
        const button = findChild(header, "menuCloseButton")
        let closed = 0
        header.closeRequested.connect(function() { closed++ })
        mouseClick(button)
        compare(closed, 1)
    }
}
