// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import QtTest
import org.kde.kirigami as Kirigami
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
            height: 900
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

    // One huge category: the row model must keep the created delegates bounded.
    function largeCatalogue(): var {
        const result = []
        for (let index = 0; index < 82; ++index)
            result.push({appId: "app" + index, name: "App " + index,
                categories: ["Graphics"]})
        return result
    }
    Component {
        id: largeFixture
        PunchiMenuSections {
            width: 900
            height: 900
            active: true
            motionEnabled: false
            menuState: PunchiMenuState {
                applications: test.largeCatalogue()
                columns: 6
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
            height: 900
            active: true
            motionEnabled: false
            menuState: PunchiMenuState {
                applications: test.catalogue
                columns: 3
                rows: 2
            }
        }
    }

    // The measured 1920x1080 menu body: 1812 px wide after the side margins.
    Component {
        id: wideFixture
        PunchiMenuSections {
            width: 1812
            height: 921
            active: true
            motionEnabled: false
            menuState: PunchiMenuState {
                applications: test.largeCatalogue()
                columns: 7
                applicationOrder: "alphabetical"
            }
        }
    }

    Component {
        id: shortFixture
        PunchiMenuSections {
            width: 200
            height: 880
            active: true
            motionEnabled: false
            menuState: PunchiMenuState {
                applications: test.catalogue
                columns: 3
                applicationOrder: "alphabetical"
            }
        }
    }
    Component {
        id: shortCategoryFixture
        PunchiMenuSections {
            width: 200
            height: 880
            active: true
            motionEnabled: false
            menuState: PunchiMenuState {
                applications: test.catalogue
                columns: 3
                applicationOrder: "categories"
            }
        }
    }

    // The real menu surface is created before the compositor has measured it.
    Component {
        id: unmeasuredFixture
        PunchiMenuSections {
            width: 1920
            height: 0
            active: true
            motionEnabled: false
            showLabels: true
            menuState: PunchiMenuState {
                applications: test.catalogue
                columns: 7
            }
        }
    }

    function init(): void {
        failOnWarning(/.*/)
    }

    function sectionsView(view): var {
        return findChild(view, "menuSectionsView")
    }

    function createdDelegates(list): int {
        let count = 0
        for (const child of list.contentItem.children)
            if (child.objectName === "menuRowDelegate") ++count
        return count
    }

    function test_referenceScaleKeepsTheCardSquareBeforeTheViewportIsLaidOut() {
        const sections = createTemporaryObject(fixture, test)
        verify(sections !== null)
        sections.height = 0
        compare(sections.gridHeight, 0)
        compare(sections.visibleRows, 5)
        verify(sections.iconSize > 1)
        compare(sections.iconSize, Math.max(1, Math.round(sections.desiredIconSize)))
        sections.height = 900
        compare(sections.cardSize, Math.min(sections.cellWidth, sections.cellHeight))
        compare(sections.cardSize, sections.cellHeight)
        verify(sections.cellHeight < sections.cellWidth)
        compare(sections.gridHeight, sections.visibleRows * sections.cellHeight)
        verify(sections.gridHeight <= sections.height + 0.5)
    }

    function test_unmeasuredViewportCreatesNoZeroSizedCells() {
        const view = createTemporaryObject(unmeasuredFixture, test)
        verify(view !== null)
        const list = sectionsView(view)
        verify(list !== null)
        wait(50)
        // A zero-sized viewport must not create delegates whose labels are
        // born with no text texture.
        compare(list.count, 0)
        compare(findChild(view, "menuTile"), null)
        view.height = 880
        tryVerify(function() { return list.count > 0 }, 1500)
        const tile = findChild(view, "menuTile")
        verify(tile !== null)
        verify(tile.height > 1)
        compare(tile.showLabel, true)
    }

    function test_listingPaintsTheCategorySections() {
        const view = createTemporaryObject(fixture, test)
        verify(view !== null)
        const list = sectionsView(view)
        verify(list !== null)
        compare(view.menuState.sectionCount, 8)
        // Eight headings and eight application rows at three columns.
        compare(view.menuState.displayRows.length, 16)
        compare(list.count, 16)
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
        // Eleven applications at three columns are four rows and no heading.
        compare(view.menuState.displayRows.length, 4)
        for (const row of view.menuState.displayRows)
            compare(row.kind, "row")
        const tile = findChild(view, "menuTile")
        verify(tile !== null)
        // Dolphin is the alphabetically first application in the fixture.
        compare(tile.title, "Dolphin")
    }

    function test_secondaryClickForwardsTheRowIndex() {
        const view = createTemporaryObject(defaultFixture, test)
        verify(view !== null)
        const tile = findChild(view, "menuTile")
        verify(tile !== null)
        let index = -1
        view.contextMenuRequested.connect(function(rowIndex, position) {
            index = rowIndex
        })
        mouseClick(tile, 10, 10, Qt.RightButton)
        verify(index >= 0)
    }

    function test_referenceRowsKeepTheLastRowWhole() {
        const view = createTemporaryObject(largeFixture, test)
        verify(view !== null)
        const list = sectionsView(view)
        verify(list !== null)
        wait(50)
        // The viewport is exactly five whole reference rows, with no partial row.
        compare(view.visibleRows, 5)
        compare(view.menuState.rows, view.visibleRows)
        compare(list.height, view.gridHeight)
        compare(list.height, view.visibleRows * view.cellHeight)
        const lastVisibleRow = Math.min(view.visibleRows,
            view.menuState.displayRows.length) - 1
        const lastRowTop = view.rowTop(lastVisibleRow)
        verify(lastRowTop + view.cellHeight <= list.height + 0.5)
        verify(list.contentHeight >= list.height)
    }

    function test_wideGridShowsWholeRowsAndKeepsTheIcon() {
        const view = createTemporaryObject(wideFixture, test)
        verify(view !== null)
        const list = sectionsView(view)
        verify(list !== null)
        wait(50)
        compare(view.columnCount, 7)
        compare(view.visibleRows, 5)
        compare(view.cardSize, Math.min(view.cellWidth, view.cellHeight))
        compare(view.cardSize, view.cellHeight)
        verify(view.cellHeight < view.cellWidth)
        compare(list.width, view.gridWidth)
        compare(list.height, view.gridHeight)
        compare(view.gridHeight, view.visibleRows * view.cellHeight)
        verify(view.gridWidth <= view.availableWidth + 0.5)
        verify(view.gridHeight <= view.height + 0.5)
        // Height-limited: the reference grid keeps side margins instead of
        // stretching the cells.
        verify(view.gridWidth < view.availableWidth)
        // The glyph keeps the reference size; the card around it shrinks.
        verify(view.iconSize >= Math.round(view.metrics.referenceIconSize))
        compare(view.iconSize, view.desiredIconSize)
    }

    function test_categoryHeadersUseTheSameRowPitch() {
        const view = createTemporaryObject(fixture, test)
        verify(view !== null)
        const list = sectionsView(view)
        verify(list !== null)
        wait(50)
        const header = view.menuState.displayRows[0]
        const appRow = view.menuState.displayRows[1]
        compare(header.kind, "header")
        compare(appRow.kind, "row")
        verify(view.cellHeight < view.cellWidth)
        // A heading consumes one whole reference row, so the viewport can
        // always end on a row boundary in category mode too.
        compare(view.rowHeight(header), view.cellHeight)
        compare(view.rowHeight(appRow), view.cellHeight)
        compare(view.rowHeight(header), view.rowHeight(appRow))
        verify(view.visibleRows >= 1)
        verify(findChild(view, "menuTile") !== null)
    }

    function test_narrowViewportHidesLabelsWhileKeepingTheIcon() {
        const view = createTemporaryObject(shortFixture, test)
        verify(view !== null)
        const list = sectionsView(view)
        const tile = findChild(view, "menuTile")
        verify(list !== null)
        verify(tile !== null)
        verify(view.cellHeight < view.cellWidth)
        compare(view.showCellLabels, false)
        compare(tile.showLabel, false)
        verify(view.visibleRows > 1)
        // The label is withheld before the glyph is allowed to shrink.
        compare(tile.iconSize, view.desiredIconSize)
        verify(tile.iconSize + Kirigami.Units.smallSpacing * 4 <= view.cellHeight)
    }

    function test_narrowCategoryViewportUsesUniformRows() {
        const view = createTemporaryObject(shortCategoryFixture, test)
        verify(view !== null)
        const list = sectionsView(view)
        const tile = findChild(view, "menuTile")
        verify(list !== null)
        verify(tile !== null)
        verify(view.cellHeight < view.cellWidth)
        compare(view.showCellLabels, false)
        compare(tile.showLabel, false)
        verify(view.visibleRows > 1)
        verify(view.menuState.displayRows[0].kind === "header")
        verify(view.menuState.displayRows[1].kind === "row")
        compare(view.rowHeight(view.menuState.displayRows[0]), view.cellHeight)
        compare(view.rowHeight(view.menuState.displayRows[1]), view.cellHeight)
    }

    function test_scrollBarFollowsTheStoredPreference() {
        const view = createTemporaryObject(fixture, test)
        verify(view !== null)
        const list = sectionsView(view)
        verify(list !== null)
        const bar = findChild(view, "menuScrollBar")
        verify(bar !== null)
        // The product default leaves the surface clean: no bar and no reserved
        // gutter, so the reference grid uses the full content width.
        compare(bar.policy, Controls.ScrollBar.AlwaysOff)
        compare(view.availableWidth, view.width)
        verify(view.gridWidth <= view.availableWidth + 0.5)
        view.showScrollBar = true
        compare(bar.policy, Controls.ScrollBar.AsNeeded)
        verify(view.availableWidth < view.width)
        verify(view.gridWidth <= view.availableWidth + 0.5)
        view.showScrollBar = false
        compare(bar.policy, Controls.ScrollBar.AlwaysOff)
        compare(view.availableWidth, view.width)
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
        // settles near the system's scroll amount.
        tryVerify(function() { return list.contentY > 0.5 }, 2000)
        compare(view.menuState.currentIndex, 0)
    }

    function test_largeSectionKeepsDelegatesBounded() {
        const view = createTemporaryObject(largeFixture, test)
        verify(view !== null)
        const list = sectionsView(view)
        verify(list !== null)
        compare(view.menuState.sections.length, 1)
        compare(view.menuState.sections[0].members.length, 82)
        // One heading plus fourteen rows of six cells.
        compare(view.menuState.displayRows.length, 15)
        compare(list.count, 15)
        // Only the rows the viewport and one row of cache need exist.
        verify(createdDelegates(list) < 10)
        // Rebuilding the listing must not grow the delegate count either.
        view.menuState.applicationOrder = "alphabetical"
        wait(150)
        compare(view.menuState.displayRows.length, 14)
        verify(createdDelegates(list) < 10)
        view.menuState.applicationOrder = "categories"
        wait(150)
        verify(createdDelegates(list) < 10)
    }

    function test_snapMovesTheRestingViewToARowBoundary() {
        const view = createTemporaryObject(largeFixture, test)
        verify(view !== null)
        const list = sectionsView(view)
        verify(list !== null)
        wait(100)
        const start = view.rowTop(2)
        list.contentY = start + view.cellHeight / 2
        wait(20)
        view.snapToRow()
        // The settle uses the theme duration, so wait for the boundary instead
        // of assuming a fixed 120 ms.
        tryVerify(function() { return isRowBoundary(view, list.contentY) }, 1500)
        verify(list.contentY > 0)
    }

    function test_newGestureTakesControlFromAnActiveSnap() {
        const view = createTemporaryObject(largeFixture, test)
        verify(view !== null)
        const list = sectionsView(view)
        const snap = findChild(view, "menuSnapAnimation")
        verify(list !== null)
        verify(snap !== null)
        wait(50)
        list.contentY = view.rowTop(2) + view.cellHeight / 3
        // The fixture starts with motion disabled for deterministic layout.
        view.motionEnabled = true
        view.snapToRow()
        tryVerify(function() { return snap.running }, 300)
        view.scheduleSnap()
        compare(snap.running, false)
        const gesturePosition = list.contentY + 12
        list.contentY = gesturePosition
        wait(40)
        compare(list.contentY, gesturePosition)
        view.active = false
    }

    function test_snapAtTheEndKeepsWholeRowsVisible() {
        const view = createTemporaryObject(fixture, test)
        verify(view !== null)
        const list = sectionsView(view)
        verify(list !== null)
        wait(50)
        list.contentY = list.contentHeight - list.height
        view.snapToRow()
        tryVerify(function() { return isRowBoundary(view, list.contentY) }, 1500)
        verify(list.contentY + list.height <= list.contentHeight + 0.5)
    }

    function test_snapUsesTheThemeDuration() {
        const view = createTemporaryObject(defaultFixture, test)
        verify(view !== null)
        const snap = findChild(view, "menuSnapAnimation")
        verify(snap !== null)
        // The fixture starts with motion disabled for determinism.
        view.motionEnabled = true
        compare(snap.duration, Kirigami.Units.longDuration)
        view.motionEnabled = false
        compare(snap.duration, 0)
    }

    function test_reducedMotionAppliesTheSnapTargetImmediately() {
        const view = createTemporaryObject(largeFixture, test)
        verify(view !== null)
        const list = sectionsView(view)
        verify(list !== null)
        wait(50)
        const target = view.rowTop(2)
        list.contentY = target + view.cellHeight / 2
        view.motionEnabled = false
        view.snapToRow()
        // A half-cell offset can settle on either neighbouring row; the
        // reduced-motion path must reach a boundary synchronously.
        verify(isRowBoundary(view, list.contentY))
    }

    function test_reopenStartsAtTheTop() {
        const view = createTemporaryObject(fixture, test)
        verify(view !== null)
        const list = sectionsView(view)
        verify(list !== null)
        wait(100)
        // The pointer owns the band and the selection is mid-list; opening the
        // surface must not reveal it.
        view.menuState.currentIndex = 5
        compare(view.pointerEmphasis, true)
        view.active = false
        wait(40)
        view.active = true
        wait(40)
        view.menuState.reset()
        wait(60)
        compare(view.menuState.currentIndex, 0)
        compare(list.contentY, 0)
    }

    function isRowBoundary(view, value): bool {
        for (let row = 0; row < view.menuState.displayRows.length; ++row)
            if (Math.abs(value - view.rowTop(row)) < 0.6) return true
        return false
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
        compare(view.menuState.sections[0].categoryId, "")
        for (const row of view.menuState.displayRows)
            compare(row.kind, "row")
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
