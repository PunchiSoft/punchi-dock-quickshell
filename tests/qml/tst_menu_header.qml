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
