// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../../services"

TestCase {
    id: test
    name: "PunchiMenuState"

    readonly property var catalogue: [
        {appId: "a", name: "Aardvark"},
        {appId: "b", name: "Browser"},
        {appId: "c", name: "Calculator"},
        {appId: "d", name: "Dolphin"},
        {appId: "e", name: "Editor"},
        {appId: "f", name: "Files"},
        {appId: "g", name: "Gwenview"}
    ]

    Component {
        id: fixture
        PunchiMenuState { applications: test.catalogue; columns: 2; rows: 2 }
    }

    // The real catalogue is a QAbstractListModel: it publishes count/get and no
    // indexable length, so the listing must not depend on array indexing.
    ListModel {
        id: modelCatalogue
        ListElement { name: "Aardvark"; iconName: "application-x-executable" }
        ListElement { name: "Browser"; iconName: "internet-web-browser" }
        ListElement { name: "Calculator"; iconName: "accessories-calculator" }
    }
    Component {
        id: modelFixture
        PunchiMenuState {
            applications: modelCatalogue
            columns: 2
            rows: 2
            applicationOrder: "manual"
        }
    }

    // A desktop entry carries its localized title and comment separately from
    // the short name, so the query has to reach all three.
    readonly property var descriptiveCatalogue: [
        {appId: "x", name: "Dolphin", title: "Dolphin", description: "File manager"},
        {appId: "y", name: "Kate", title: "Kate", description: "Advanced text editor"},
        {appId: "z", title: "Terminal", description: "Run commands"}
    ]
    Component {
        id: descriptiveFixture
        PunchiMenuState { applications: test.descriptiveCatalogue; columns: 2; rows: 2 }
    }

    // The categories come from the desktop entry, which is why the fixture hands
    // over the same role the native catalogue publishes.
    readonly property var categorisedCatalogue: [
        {appId: "kate", name: "Kate", categories: ["Development", "TextEditor"]},
        {appId: "konsole", name: "Konsole", categories: ["System", "TerminalEmulator"]},
        {appId: "kde4", name: "KDE 4 Tool", categories: ["Graphics"]},
        {appId: "kde10", name: "KDE 10 Tool", categories: ["Graphics"]},
        {appId: "gimp", name: "GNU Image", categories: ["Graphics", "RasterGraphics"]},
        {appId: "firefox", name: "Firefox", categories: ["Network", "WebBrowser"]},
        {appId: "unknown", name: "Zzz", categories: []}
    ]
    Component {
        id: categorisedFixture
        PunchiMenuState {
            applications: test.categorisedCatalogue
            columns: 2
            rows: 2
            applicationOrder: "categories"
        }
    }
    Component {
        id: defaultOrderFixture
        PunchiMenuState { applications: test.categorisedCatalogue; columns: 2; rows: 2 }
    }

    function init(): void {
        failOnWarning(/.*/)
    }

    function sectionIds(state): var {
        return state.sections.map(section => section.categoryId)
    }

    function test_searchMatchesTheLocalizedTitleAndDescription() {
        const state = createTemporaryObject(descriptiveFixture, test)
        verify(state !== null)
        compare(state.filtered.length, 3)
        // The name still matches, and the comparison ignores case.
        state.searchText = "DOLPH"
        compare(state.filtered.length, 1)
        compare(state.filtered[0].appId, "x")
        // A localized title without a separate name is found.
        state.searchText = "terminal"
        compare(state.filtered.length, 1)
        compare(state.filtered[0].appId, "z")
        // So is a comment, which is what the user often remembers.
        state.searchText = "editor"
        compare(state.filtered.length, 1)
        compare(state.filtered[0].appId, "y")
        state.searchText = "commands"
        compare(state.filtered.length, 1)
        compare(state.filtered[0].appId, "z")
    }

    function test_searchIndexFollowsTheCatalogueRevision() {
        const state = createTemporaryObject(modelFixture, test)
        verify(state !== null)
        compare(state.filtered.length, 3)
        try {
            modelCatalogue.append({name: "Kolourpaint", iconName: "krita"})
            tryVerify(function() { return state.filtered.length === 4 })
            state.searchText = "kolour"
            compare(state.filtered.length, 1)
        } finally {
            modelCatalogue.remove(3)
        }
        tryVerify(function() { return state.filtered.length === 0 })
        state.clearSearch()
        tryVerify(function() { return state.filtered.length === 3 })
    }

    function test_listingReadsAModelWithoutIndexAccess() {
        const state = createTemporaryObject(modelFixture, test)
        compare(state.applicationCount(), 3)
        compare(state.filtered.length, 3)
        compare(state.filtered[1].name, "Browser")
        state.searchText = "calc"
        compare(state.filtered.length, 1)
        compare(state.filtered[0].name, "Calculator")
    }

    function test_searchFiltersAndResetsTheSelection() {
        const state = createTemporaryObject(fixture, test)
        compare(state.filtered.length, 7)
        compare(state.currentIndex, 0)
        state.searchText = "  brow  "
        compare(state.safeSearch, "brow")
        compare(state.filtered.length, 1)
        compare(state.filtered[0].appId, "b")
        compare(state.currentIndex, 0)
        state.clearSearch()
        compare(state.searchText, "")
        compare(state.filtered.length, 7)
    }

    function test_categoriesFollowTheReferenceOrder() {
        const state = createTemporaryObject(categorisedFixture, test)
        verify(state !== null)
        compare(state.grouped, true)
        // Network, Graphics, Development, System, then the entries without a
        // family. Empty groups are not painted.
        compare(sectionIds(state).join(","),
            "Network,Graphics,Development,System,Other")
        const graphics = state.sections[1].members
        // Members of a group are alphabetical, and digits read as numbers.
        compare(graphics.map(entry => entry.name).join(","),
            "GNU Image,KDE 4 Tool,KDE 10 Tool")
        // The flat listing is the concatenation of the sections.
        compare(state.filtered.length, test.categorisedCatalogue.length)
        compare(state.filtered[0].appId, "firefox")
        compare(state.sections[1].start, 1)
    }

    function test_alphabeticalOrderIsOneNaturalSortedSection() {
        const state = createTemporaryObject(categorisedFixture, test)
        state.applicationOrder = "alphabetical"
        compare(state.grouped, false)
        compare(state.sectionCount, 1)
        compare(state.sections[0].categoryId, "")
        compare(state.sections[0].members.map(entry => entry.name).join(","),
            "Firefox,GNU Image,Kate,KDE 4 Tool,KDE 10 Tool,Konsole,Zzz")
    }

    function test_manualOrderKeepsTheCatalogueSequence() {
        const state = createTemporaryObject(categorisedFixture, test)
        state.applicationOrder = "manual"
        compare(state.sectionCount, 1)
        compare(state.filtered.map(entry => entry.appId).join(","),
            "kate,konsole,kde4,kde10,gimp,firefox,unknown")
    }

    function test_searchPaintsOneFlatSection() {
        const state = createTemporaryObject(categorisedFixture, test)
        state.searchText = "kde"
        compare(state.grouped, false)
        compare(state.sectionCount, 1)
        compare(state.sections[0].categoryId, "")
        compare(state.filtered.length, 2)
    }

    function test_pageMoveAdvancesOneViewportOfRows() {
        const state = createTemporaryObject(fixture, test)
        // Two columns and two visible rows make a page four cells long.
        state.selectPage(1)
        compare(state.currentIndex, 4)
        state.selectPage(-1)
        compare(state.currentIndex, 0)
        state.selectPage(1)
        state.selectPage(1)
        compare(state.currentIndex, 6)
    }

    function test_selectionStaysInsideTheListing() {
        const state = createTemporaryObject(fixture, test)
        compare(state.currentIndex, 0)
        state.moveVertical(1)
        compare(state.currentIndex, 2)
        state.moveBy(100)
        compare(state.currentIndex, 6)
        state.moveBy(10)
        compare(state.currentIndex, 6)
        state.selectLast()
        compare(state.currentIndex, 6)
        state.selectFirst()
        compare(state.currentIndex, 0)
        state.searchText = "nothing"
        compare(state.filtered.length, 0)
        compare(state.currentIndex, -1)
        compare(state.sectionCount, 0)
    }

    function test_displayRowsCarryHeadingsAndBoundedRows() {
        const state = createTemporaryObject(categorisedFixture, test)
        const rows = state.displayRows
        // Five headings and six application rows at two columns.
        compare(rows.length, 11)
        compare(rows[0].kind, "header")
        compare(rows[0].categoryId, "Network")
        compare(rows[1].kind, "row")
        compare(rows[1].members.length, 1)
        // Graphics has three members in two rows; the flat indices survive.
        compare(rows[3].members.length, 2)
        compare(rows[3].members[0].index, 1)
        compare(rows[4].members.length, 1)
        compare(rows[4].members[0].index, 3)
        // Mapping a flat index to the row that contains it skips headings.
        compare(state.displayRowFor(0), 1)
        compare(state.displayRowFor(1), 3)
        compare(state.displayRowFor(3), 4)
        compare(state.displayRowFor(4), 6)
        compare(state.displayRowFor(6), 10)
    }

    function test_flatDisplayRowsHaveNoHeadings() {
        const state = createTemporaryObject(defaultOrderFixture, test)
        compare(state.displayRows.length, 4)
        for (const row of state.displayRows)
            compare(row.kind, "row")
        compare(state.displayRowFor(6), 3)
        state.searchText = "kde"
        compare(state.displayRows.length, 1)
        compare(state.displayRows[0].members.length, 2)
    }

    function test_verticalNavigationCrossesSectionsKeepingTheColumn() {
        const state = createTemporaryObject(categorisedFixture, test)
        // Network has one member, Graphics starts at index 1.
        compare(state.currentIndex, 0)
        state.moveVertical(1)
        compare(state.currentIndex, 1)
        // Within Graphics, a row down stays in the third cell.
        state.moveVertical(1)
        compare(state.currentIndex, 3)
        // Up from the first Graphics row returns to Network.
        state.moveHorizontal(-1)
        compare(state.currentIndex, 2)
        state.moveVertical(-1)
        compare(state.currentIndex, 0)
        // Horizontal movement continues in the neighbouring section.
        state.moveHorizontal(1)
        compare(state.currentIndex, 1)
        state.selectLast()
        state.moveHorizontal(1)
        compare(state.currentIndex, 6)
    }

    function test_gridChangesRepositionTheKeyboardCursor() {
        const state = createTemporaryObject(fixture, test)
        state.moveBy(5)
        compare(state.currentIndex, 5)
        state.columns = 3
        compare(state.currentIndex, 0)
    }

    function test_defaultOrderIsAlphabetical() {
        const state = createTemporaryObject(defaultOrderFixture, test)
        compare(state.applicationOrder, "alphabetical")
        compare(state.grouped, false)
        compare(state.sectionCount, 1)
        compare(state.filtered.map(entry => entry.name).join(","),
            "Firefox,GNU Image,Kate,KDE 4 Tool,KDE 10 Tool,Konsole,Zzz")
    }

    function test_invalidOrderFallsBackToAlphabetical() {
        const state = createTemporaryObject(categorisedFixture, test)
        state.applicationOrder = "unsorted"
        compare(state.applicationOrder, "alphabetical")
        compare(state.grouped, false)
        compare(state.sectionCount, 1)
    }

    function test_resetClearsTheQueryAndRestoresTheFirstRow() {
        const state = createTemporaryObject(fixture, test)
        state.searchText = "dol"
        state.moveBy(0)
        state.reset()
        compare(state.searchText, "")
        compare(state.currentIndex, 0)
    }
}
