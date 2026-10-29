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
        PunchiMenuState { applications: modelCatalogue; columns: 2; rows: 2 }
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

    function test_pagingFollowsTheGridCapacity() {
        const state = createTemporaryObject(fixture, test)
        compare(state.pageCapacity, 4)
        compare(state.pageCount, 2)
        state.moveBy(4)
        compare(state.currentIndex, 4)
        compare(state.currentPage, 1)
        state.goToPage(0)
        compare(state.currentPage, 0)
        compare(state.currentIndex, 0)
    }

    function test_selectionStaysInsideTheFilteredList() {
        const state = createTemporaryObject(fixture, test)
        state.moveVertical(1)
        compare(state.currentIndex, 2)
        state.moveBy(100)
        compare(state.currentIndex, 6)
        state.moveBy(10)
        compare(state.currentIndex, 6)
        state.selectLast()
        compare(state.currentIndex, 6)
        compare(state.currentPage, 1)
        state.selectFirst()
        compare(state.currentIndex, 0)
        compare(state.currentPage, 0)
        state.searchText = "nothing"
        compare(state.filtered.length, 0)
        compare(state.currentIndex, -1)
        compare(state.pageCount, 1)
    }

    function test_gridChangesRepositionTheKeyboardCursor() {
        const state = createTemporaryObject(fixture, test)
        state.moveBy(5)
        compare(state.currentIndex, 5)
        state.columns = 3
        compare(state.pageCapacity, 6)
        compare(state.currentIndex, 0)
        compare(state.currentPage, 0)
    }

    function test_resetClearsTheQueryAndRestoresTheFirstRow() {
        const state = createTemporaryObject(fixture, test)
        state.searchText = "dol"
        state.moveBy(0)
        state.reset()
        compare(state.searchText, "")
        compare(state.currentIndex, 0)
        compare(state.currentPage, 0)
    }
}
