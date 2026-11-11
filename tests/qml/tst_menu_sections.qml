// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
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
        {appId: "a", name: "Aardvark", iconName: "application-x-executable"},
        {appId: "b", name: "Browser", iconName: "internet-web-browser"},
        {appId: "c", name: "Calculator", iconName: "accessories-calculator"},
        {appId: "d", name: "Dolphin", iconName: "system-file-manager"},
        {appId: "e", name: "Editor", iconName: "accessories-text-editor"},
        {appId: "f", name: "Files", iconName: "system-file-manager"},
        {appId: "g", name: "Gwenview", iconName: "image-viewer"},
        {appId: "h", name: "Haruna", iconName: "video-player"},
        {appId: "i", name: "Index", iconName: "application-x-executable"},
        {appId: "j", name: "Juk", iconName: "audio-player"},
        {appId: "k", name: "Kate", iconName: "accessories-text-editor"},
        {appId: "l", name: "Kcalc", iconName: "accessories-calculator"},
        {appId: "m", name: "Konsole", iconName: "utilities-terminal"},
        {appId: "n", name: "Krita", iconName: "image-viewer"},
        {appId: "o", name: "Okular", iconName: "application-pdf"},
        {appId: "p", name: "Spectral", iconName: "image-viewer"}
    ]

    Component {
        id: fixture
        PunchiMenuSections {
            width: 900
            height: 600
            active: true
            motionEnabled: false
            menuState: PunchiMenuState {
                applications: test.catalogue
                columns: 3
                rows: 2
            }
        }
    }

    // The same grid with motion, so the page transition is observable.
    Component {
        id: motionFixture
        PunchiMenuSections {
            width: 900
            height: 600
            active: true
            motionEnabled: true
            menuState: PunchiMenuState {
                applications: test.catalogue
                columns: 3
                rows: 2
            }
        }
    }

    function init() {
        failOnWarning(/.*/)
    }

    function wheel(grid, delta) {
        mouseWheel(grid, grid.width / 2, grid.height / 2, 0, delta)
        wait(20)
    }

    function test_wheelPagesTheGrid() {
        const grid = createTemporaryObject(fixture, test)
        verify(grid !== null)
        const state = grid.menuState
        compare(state.pageCount, 3)
        compare(state.currentPage, 0)
        // Scrolling down leaves the first page for the second.
        wheel(grid, -120)
        compare(state.currentPage, 1)
        wheel(grid, -120)
        compare(state.currentPage, 2)
        // The last page is the bound, so a further notch keeps it.
        wheel(grid, -120)
        compare(state.currentPage, 2)
        // Scrolling up returns, and the first page is the other bound.
        wheel(grid, 120)
        compare(state.currentPage, 1)
        wheel(grid, 120)
        compare(state.currentPage, 0)
        wheel(grid, 120)
        compare(state.currentPage, 0)
    }

    function test_wheelOverACellStillPages() {
        const grid = createTemporaryObject(fixture, test)
        verify(grid !== null)
        const state = grid.menuState
        const tile = findChild(grid, "menuTile")
        verify(tile !== null)
        mouseWheel(tile, tile.width / 2, tile.height / 2, 0, -120)
        wait(20)
        compare(state.currentPage, 1)
    }

    function test_wheelAccumulatesATouchpadGesture() {
        const grid = createTemporaryObject(fixture, test)
        verify(grid !== null)
        const state = grid.menuState
        // Two partial deltas belong to one gesture and step one page once.
        wheel(grid, -60)
        compare(state.currentPage, 0)
        wheel(grid, -60)
        compare(state.currentPage, 1)
        // A reversal does not carry the previous direction's remainder: two
        // half-notches in opposite directions never add up to a page.
        wheel(grid, -60)
        wheel(grid, 60)
        compare(state.currentPage, 1)
        // A full notch in the new direction still pages.
        wheel(grid, 120)
        compare(state.currentPage, 0)
    }

    function test_wheelDoesNothingWithASinglePage() {
        const grid = createTemporaryObject(fixture, test)
        verify(grid !== null)
        const state = grid.menuState
        state.searchText = "kate"
        compare(state.pageCount, 1)
        wheel(grid, -240)
        compare(state.currentPage, 0)
        compare(state.currentIndex, 0)
    }

    function test_wheelTransitionIsAnimated() {
        const grid = createTemporaryObject(motionFixture, test)
        verify(grid !== null)
        const pages = findChild(grid, "menuPagesView")
        verify(pages !== null)
        compare(grid.menuState.currentPage, 0)
        compare(pages.contentX, 0)
        wheel(grid, -120)
        // The page changes at once; the view takes `highlightMoveDuration` to
        // reach it instead of teleporting and cancelling the transition.
        compare(grid.menuState.currentPage, 1)
        // An intermediate position proves the content moved instead of jumping.
        // Waiting for the observation keeps the assertion independent of how
        // quickly the first frame arrives.
        tryVerify(function() {
            return pages.contentX > 0.5 && pages.contentX < pages.width
        }, 1000)
        tryCompare(pages, "contentX", pages.width, 2000)
    }

    function test_secondNotchRetargetsTheTransition() {
        const grid = createTemporaryObject(motionFixture, test)
        verify(grid !== null)
        const pages = findChild(grid, "menuPagesView")
        verify(pages !== null)
        wheel(grid, -120)
        tryVerify(function() {
            return pages.contentX > 0.5 && pages.contentX < pages.width
        }, 1000)
        const before = pages.contentX
        // A second notch while the first transition runs continues from the
        // position the view reached instead of restarting at the old page.
        wheel(grid, -120)
        compare(grid.menuState.currentPage, 2)
        verify(pages.contentX >= before - 1)
        tryCompare(pages, "contentX", pages.width * 2, 2000)
    }

    function test_reducedMotionPagesWithoutAMove() {
        const grid = createTemporaryObject(fixture, test)
        verify(grid !== null)
        const pages = findChild(grid, "menuPagesView")
        verify(pages !== null)
        compare(pages.highlightMoveDuration, 0)
        wheel(grid, -120)
        compare(grid.menuState.currentPage, 1)
        // Reduced motion still settles on the target; only the move is skipped,
        // so the position is observed instead of assumed to be synchronous.
        tryCompare(pages, "contentX", pages.width, 1000)
    }

    function test_pageFooterFollowsTheStoredPreference() {
        const grid = createTemporaryObject(fixture, test)
        verify(grid !== null)
        const footer = findChild(grid, "menuPageFooter")
        verify(footer !== null)
        // The default profile starts hidden; the stored preference still turns
        // the arrows and the page count back on.
        grid.showPageArrows = false
        compare(footer.visible, false)
        grid.showPageArrows = true
        compare(footer.visible, true)
    }

    function test_cellsExposeAnAccessibleButton() {
        const grid = createTemporaryObject(fixture, test)
        verify(grid !== null)
        const tile = findChild(grid, "menuTile")
        verify(tile !== null)
        compare(tile.Accessible.role, Accessible.Button)
        compare(tile.Accessible.name, "Aardvark")
        compare(tile.Accessible.description, "Open Aardvark")
    }

    function test_keyboardEmphasisReachesTheTiles() {
        const grid = createTemporaryObject(fixture, test)
        verify(grid !== null)
        const tile = findChild(grid, "menuTile")
        verify(tile !== null)
        // The surface publishes the modality, so the tile never keeps its
        // pointer default and the keyboard band can paint.
        compare(tile.pointerEmphasis, true)
        grid.takeKeyboardEmphasis()
        compare(tile.pointerEmphasis, false)
        compare(tile.selected, true)
        const highlight = tile.children[0]
        compare(highlight.selected, true)
        compare(highlight.hovered, false)
    }

    function test_hoverRetargetsTheKeyboardCursor() {
        const grid = createTemporaryObject(fixture, test)
        verify(grid !== null)
        const state = grid.menuState
        const tile = findChild(grid, "menuTile")
        verify(tile !== null)
        // The first cell is not the current row, so returning to it proves the
        // pointer retargeted the keyboard cursor instead of only painting hover.
        state.currentIndex = 2
        compare(tile.selected, false)
        // The cell emits the intent; a selection that lands on it proves the
        // surface retargeted the keyboard cursor instead of only painting hover.
        tile.pointerEntered()
        tryCompare(tile, "selected", true)
    }
}
