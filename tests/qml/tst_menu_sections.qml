// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import QtTest
import "../../modules/menu"
import "../../services"

TestCase {
    id: test
    name: "PunchiMenuSections"
    when: windowShown
    visible: true
    width: 900
    height: 600

    readonly property var catalogue: [
        {appId: "kate", name: "Kate", categories: ["Development", "TextEditor"]},
        {appId: "konsole", name: "Konsole", categories: ["System", "TerminalEmulator"]},
        {appId: "gwenview", name: "Gwenview", categories: ["Graphics", "Viewer"]},
        {appId: "krita", name: "Krita", categories: ["Graphics", "RasterGraphics"]},
        {appId: "dolphin", name: "Dolphin", categories: ["System", "FileTools"]},
        {appId: "firefox", name: "Firefox", categories: ["Network", "WebBrowser"]},
        {appId: "okular", name: "Okular", categories: ["Office", "Viewer"]},
        {appId: "haruna", name: "Haruna", categories: ["AudioVideo", "Player"]},
        {appId: "elisa", name: "Elisa", categories: ["AudioVideo", "Player"]},
        {appId: "kcalc", name: "Kcalc", categories: ["Utility", "Calculator"]},
        {appId: "unknown", name: "Zzz", categories: []}
    ]

    Component {
        id: fixture
        PunchiMenuSections {
            width: 900
            height: 240
            active: true
            motionEnabled: false
            menuState: PunchiMenuState {
                applications: test.catalogue
                columns: 3
                rows: 2
                applicationOrder: "categories"
            }
        }
    }

    // The product default: one flat alphabetical list without headings.
    Component {
        id: defaultFixture
        PunchiMenuSections {
            width: 900
            height: 240
            active: true
            motionEnabled: false
            menuState: PunchiMenuState {
                applications: test.catalogue
                columns: 3
                rows: 2
            }
        }
    }

    function init(): void {
        failOnWarning(/.*/)
    }

    function sectionsView(view): var {
        return findChild(view, "menuSectionsView")
    }

    function test_listingPaintsTheCategorySections() {
        const view = createTemporaryObject(fixture, test)
        verify(view !== null)
        const list = sectionsView(view)
        verify(list !== null)
        compare(list.count, view.menuState.sectionCount)
        compare(view.menuState.sectionCount, 8)
        // The first section is the reference's first group, and its first cell
        // is the alphabetically first member.
        compare(view.menuState.sections[0].categoryId, "Network")
        const tile = findChild(view, "menuTile")
        verify(tile !== null)
        compare(tile.title, "Firefox")
        // A category heading is a source string the surface resolves.
        compare(view.categoryTitle("Network"), "Internet")
        compare(view.categoryTitle("Utility"), "Utilities")
        compare(view.categoryTitle(""), "")
    }

    function test_defaultListingIsAlphabeticalWithoutHeadings() {
        const view = createTemporaryObject(defaultFixture, test)
        verify(view !== null)
        compare(view.menuState.applicationOrder, "alphabetical")
        compare(view.menuState.sectionCount, 1)
        compare(view.menuState.sections[0].categoryId, "")
        const tile = findChild(view, "menuTile")
        verify(tile !== null)
        // Dolphin is the alphabetically first application in the fixture.
        compare(tile.title, "Dolphin")
    }

    function test_scrollBarFollowsTheStoredPreference() {
        const view = createTemporaryObject(fixture, test)
        verify(view !== null)
        const list = sectionsView(view)
        verify(list !== null)
        const bar = findChild(view, "menuScrollBar")
        verify(bar !== null)
        // The product default leaves the surface clean: no bar and no reserved
        // gutter, so the columns use the full width.
        compare(bar.policy, Controls.ScrollBar.AlwaysOff)
        compare(view.availableWidth, list.width)
        view.showScrollBar = true
        compare(bar.policy, Controls.ScrollBar.AsNeeded)
        verify(view.availableWidth < list.width)
        view.showScrollBar = false
        compare(bar.policy, Controls.ScrollBar.AlwaysOff)
        compare(view.availableWidth, list.width)
    }

    function test_wheelScrollsContinuouslyInsteadOfPaging() {
        const view = createTemporaryObject(fixture, test)
        verify(view !== null)
        const list = sectionsView(view)
        verify(list !== null)
        // The listing is taller than the surface, so there is somewhere to go.
        verify(list.contentHeight > list.height)
        compare(list.contentY, 0)
        mouseWheel(view, view.width / 2, view.height / 2, 0, -120)
        // The selection does not move with the wheel; the content does, and it
        // settles wherever the system's scroll amount leaves it.
        tryVerify(function() { return list.contentY > 0.5 }, 2000)
        compare(view.menuState.currentIndex, 0)
    }

    function test_wheelBelongsToTheSystemHandler() {
        const view = createTemporaryObject(fixture, test)
        verify(view !== null)
        const wheel = findChild(view, "menuScrollWheel")
        verify(wheel !== null)
        // Intercepting the wheel in this surface would bypass the KDE scroll
        // setting; the handler scrolls the view instead.
        compare(wheel.target, sectionsView(view))
    }

    function test_keyboardSelectionScrollsIntoView() {
        const view = createTemporaryObject(fixture, test)
        verify(view !== null)
        const list = sectionsView(view)
        verify(list !== null)
        view.menuState.selectLast()
        view.takeKeyboardEmphasis()
        tryVerify(function() { return list.contentY > 0.5 }, 2000)
    }

    function test_flatOrderPaintsNoHeading() {
        const view = createTemporaryObject(fixture, test)
        verify(view !== null)
        view.menuState.applicationOrder = "manual"
        compare(view.menuState.sectionCount, 1)
        compare(view.sectionHeading(view.menuState.sections[0]), "")
    }

    function test_cellsExposeAnAccessibleButton() {
        const view = createTemporaryObject(fixture, test)
        verify(view !== null)
        const tile = findChild(view, "menuTile")
        verify(tile !== null)
        compare(tile.Accessible.role, Accessible.Button)
        compare(tile.Accessible.name, "Firefox")
        compare(tile.Accessible.description, "Open Firefox")
    }

    function test_keyboardEmphasisReachesTheTiles() {
        const view = createTemporaryObject(fixture, test)
        verify(view !== null)
        const tile = findChild(view, "menuTile")
        verify(tile !== null)
        compare(tile.pointerEmphasis, true)
        view.takeKeyboardEmphasis()
        compare(tile.pointerEmphasis, false)
        compare(tile.selected, true)
        const highlight = tile.children[0]
        compare(highlight.selected, true)
        compare(highlight.hovered, false)
    }

    function test_hoverRetargetsTheKeyboardCursor() {
        const view = createTemporaryObject(fixture, test)
        verify(view !== null)
        const state = view.menuState
        const tile = findChild(view, "menuTile")
        verify(tile !== null)
        state.currentIndex = 2
        compare(tile.selected, false)
        tile.pointerEntered()
        tryCompare(tile, "selected", true)
        compare(state.currentIndex, 0)
    }
}
