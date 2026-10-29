// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQml

// Presentation state of one fullscreen menu surface. The window, the grid and
// the header read it; nothing here reaches an adapter, so the whole listing is
// testable without a compositor.
QtObject {
    id: root

    // Catalogue rows arrive from the shared catalog; the menu never resolves a
    // desktop entry by itself.
    required property var applications
    property string searchText: ""
    property int currentIndex: -1
    property int currentPage: 0
    property int columns: 4
    property int rows: 3
    // Bounded so a crafted or mistaken value can never allocate an unbounded
    // delegate set.
    readonly property int maximumEntries: 1024
    readonly property int pageCapacity: Math.max(1, root.columns * root.rows)
    readonly property string safeSearch: root.searchText.trim().slice(0, 256)

    readonly property var filtered: {
        const result = []
        const query = root.safeSearch.toLocaleLowerCase()
        const source = root.applications || []
        const count = Math.min(source.length, root.maximumEntries)
        for (let index = 0; index < count; index++) {
            const application = source[index]
            if (!application) continue
            if (query.length > 0
                    && String(application.name || "").toLocaleLowerCase().indexOf(query) < 0)
                continue
            result.push(application)
        }
        return result
    }
    readonly property int pageCount: Math.max(1,
        Math.ceil(root.filtered.length / root.pageCapacity))
    readonly property var currentPageApplications: {
        const start = root.currentPage * root.pageCapacity
        return root.filtered.slice(start, start + root.pageCapacity)
    }
    readonly property var currentApplication: root.currentIndex >= 0
        && root.currentIndex < root.filtered.length
        ? root.filtered[root.currentIndex] : null

    // Any change to the query or to the grid invalidates the selection and the
    // page, so the keyboard never points at a row that left the list.
    onFilteredChanged: root.resetPosition()
    onPageCapacityChanged: root.resetPosition()

    function resetPosition(): void {
        root.currentIndex = root.filtered.length > 0 ? 0 : -1
        root.currentPage = 0
    }
    function clearSearch(): void {
        root.searchText = ""
    }
    function goToPage(page: int): void {
        const bounded = Math.max(0, Math.min(root.pageCount - 1, page))
        if (bounded === root.currentPage) return
        root.currentPage = bounded
        root.currentIndex = Math.min(root.filtered.length - 1,
            bounded * root.pageCapacity)
    }
    function moveBy(step: int): void {
        if (root.filtered.length === 0) return
        const next = Math.max(0, Math.min(root.filtered.length - 1,
            root.currentIndex + step))
        if (next === root.currentIndex) return
        root.currentIndex = next
        root.currentPage = Math.floor(next / root.pageCapacity)
    }
    function moveHorizontal(direction: int): void {
        root.moveBy(direction)
    }
    function moveVertical(direction: int): void {
        root.moveBy(direction * root.columns)
    }
    function selectFirst(): void {
        root.goToPage(0)
        root.currentIndex = root.filtered.length > 0 ? 0 : -1
    }
    function selectLast(): void {
        if (root.filtered.length === 0) {
            root.currentIndex = -1
            return
        }
        root.currentIndex = root.filtered.length - 1
        root.currentPage = Math.floor(root.currentIndex / root.pageCapacity)
    }
    function selectPage(step: int): void {
        root.goToPage(root.currentPage + step)
    }
    function pageFor(index: int): int {
        return Math.floor(Math.max(0, index) / root.pageCapacity)
    }
    function reset(): void {
        root.searchText = ""
        root.currentIndex = root.filtered.length > 0 ? 0 : -1
        root.currentPage = 0
    }
}
