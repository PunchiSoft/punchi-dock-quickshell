// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../../modules/menu"
import "../../services"

TestCase {
    id: test
    name: "PunchiMenuGrid"
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
        PunchiMenuGrid {
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
}
