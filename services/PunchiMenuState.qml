// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQml
import "PunchiMenuCategories.js" as PunchiMenuCategories

// Presentation state of one fullscreen menu surface. The window, the sections
// view and the header read it; nothing here reaches an adapter, so the whole
// listing is testable without a compositor.
QtObject {
    id: root

    // Catalogue rows arrive from the shared catalog; the menu never resolves a
    // desktop entry by itself.
    required property var applications
    property string searchText: ""
    // The order a person chose for the listing. `categories` paints one section
    // per family; `alphabetical`, the default, and `manual` paint a single flat
    // list.
    property string applicationOrder: "alphabetical"
    property int currentIndex: -1
    property int columns: 4
    // Visible rows. Paging by keyboard moves this many rows at once.
    property int rows: 3
    // Bounded so a crafted or mistaken value can never allocate an unbounded
    // delegate set.
    readonly property int maximumEntries: 1024
    readonly property string safeSearch: root.searchText.trim().slice(0, 256)

    onApplicationOrderChanged: {
        if (["categories", "alphabetical", "manual"].indexOf(root.applicationOrder) < 0)
            root.applicationOrder = "alphabetical"
        else
            root.resetPosition()
    }

    // The catalogue is a QAbstractListModel, which publishes `count` and `get()`
    // and no indexable length. An array stays supported so a fixture can drive
    // the same listing without a model.
    function applicationAt(index: int): var {
        const source = root.applications
        if (!source) return null
        if (typeof source.get === "function") return source.get(index)
        return source[index]
    }
    function applicationCount(): int {
        const source = root.applications
        if (!source) return 0
        if (typeof source.count === "number") return source.count
        if (typeof source.length === "number") return source.length
        return 0
    }
    // Reading the model revision keeps this binding alive when the catalogue
    // changes at runtime.
    readonly property int catalogueRevision: {
        const source = root.applications
        return source && typeof source.revision === "number" ? source.revision : 0
    }

    // The catalogue is prepared once per revision instead of once per keystroke:
    // typing lowercases the query and compares against text that already is
    // lowercased. A row exposes the desktop entry's name, the item's own title
    // and the entry's comment, and the query matches any of them, so an
    // application the user recognizes by its description is found too.
    readonly property var searchIndex: {
        root.catalogueRevision
        const rows = []
        const count = Math.min(root.applicationCount(), root.maximumEntries)
        for (let index = 0; index < count; index++) {
            const application = root.applicationAt(index)
            if (!application) continue
            const fields = []
            for (const field of [application.name, application.title,
                    application.description]) {
                if (typeof field === "string" && field.length > 0) fields.push(field)
            }
            rows.push({
                application: application,
                haystack: fields.join(" ").toLocaleLowerCase()
            })
        }
        return rows
    }
    readonly property var matchedRows: {
        const query = root.safeSearch.toLocaleLowerCase()
        if (query.length === 0) return root.searchIndex
        return root.searchIndex.filter(row => row.haystack.indexOf(query) >= 0)
    }
    // A search always paints one flat list: the user asked for a match, not for
    // the section the match would otherwise sit in.
    readonly property bool grouped: root.applicationOrder === "categories"
        && root.safeSearch.length === 0

    // Sections in display order. Each one carries the flat start index of its
    // first member, so the view can reveal a keyboard selection without walking
    // the whole listing and the state keeps one index for the current cell.
    readonly property var sections: {
        const rows = root.matchedRows
        const applications = rows.map(row => row.application)
        let list
        if (!root.grouped)
            list = PunchiMenuCategories.flatSection(root.applicationOrder === "alphabetical"
                ? PunchiMenuCategories.sortedByName(applications) : applications)
        else
            list = PunchiMenuCategories.sections(applications)
        const result = []
        let start = 0
        for (const section of list) {
            const members = section.members
            result.push({categoryId: section.categoryId, members: members, start: start})
            start += members.length
        }
        return result
    }
    readonly property var filtered: {
        const result = []
        for (const section of root.sections)
            for (const application of section.members)
                result.push(application)
        return result
    }
    // Rows the view virtualizes: one heading row per named section and one row
    // of at most `columns` applications. The delegate count therefore follows
    // the viewport, not the catalogue, and a section of 500 applications never
    // becomes 500 delegates. `index` is the flat index into `filtered`.
    readonly property var displayRows: {
        const result = []
        const columns = Math.max(1, root.columns)
        for (let sectionIndex = 0; sectionIndex < root.sections.length; ++sectionIndex) {
            const section = root.sections[sectionIndex]
            if (String(section.categoryId || "").length > 0)
                result.push({kind: "header", categoryId: section.categoryId,
                    sectionIndex: sectionIndex, start: section.start})
            for (let offset = 0; offset < section.members.length; offset += columns) {
                const members = []
                const end = Math.min(section.members.length, offset + columns)
                for (let member = offset; member < end; ++member)
                    members.push({application: section.members[member],
                        index: section.start + member})
                result.push({kind: "row", sectionIndex: sectionIndex,
                    rowIndex: offset / columns, start: section.start + offset,
                    members: members})
            }
        }
        return result
    }
    readonly property int sectionCount: root.sections.length
    readonly property int currentSectionIndex: {
        const position = root.sectionPosition(root.currentIndex)
        return position.section
    }
    readonly property var currentApplication: root.currentIndex >= 0
        && root.currentIndex < root.filtered.length
        ? root.filtered[root.currentIndex] : null

    // Any change to the query, the grid or the order invalidates the selection,
    // so the keyboard never points at a row that left the list.
    onFilteredChanged: root.resetPosition()
    onColumnsChanged: root.resetPosition()

    // The display row that contains a flat application index, used by the view
    // to reveal the keyboard selection without measuring the content.
    function displayRowFor(index: int): int {
        const columns = Math.max(1, root.columns)
        let row = 0
        for (let sectionIndex = 0; sectionIndex < root.sections.length; ++sectionIndex) {
            const section = root.sections[sectionIndex]
            if (String(section.categoryId || "").length > 0) ++row
            const sectionRows = Math.ceil(section.members.length / columns)
            const offset = index - section.start
            if (offset >= 0 && offset < section.members.length)
                return row + Math.min(sectionRows - 1, Math.floor(offset / columns))
            row += sectionRows
        }
        return Math.max(0, row - 1)
    }
    // Where a flat index sits in the sectioned listing.
    function sectionPosition(index: int): var {
        const list = root.sections
        for (let section = 0; section < list.length; section++) {
            if (index < list[section].start + list[section].members.length)
                return {section: section, offset: Math.max(0, index - list[section].start),
                    start: list[section].start}
        }
        return {section: Math.max(0, list.length - 1), offset: 0,
            start: list.length > 0 ? list[list.length - 1].start : 0}
    }
    function resetPosition(): void {
        root.currentIndex = root.filtered.length > 0 ? 0 : -1
    }
    function clearSearch(): void {
        root.searchText = ""
    }
    function moveBy(step: int): void {
        if (root.filtered.length === 0) return
        const next = Math.max(0, Math.min(root.filtered.length - 1,
            root.currentIndex + step))
        if (next === root.currentIndex) return
        root.currentIndex = next
    }
    // Left/right stays inside the current section and continues at the edge of
    // the neighbouring one, so the grid never skips a row.
    function moveHorizontal(step: int): void {
        if (root.filtered.length === 0) return
        const position = root.sectionPosition(root.currentIndex)
        const section = root.sections[position.section]
        if (!section) return
        const target = position.offset + step
        if (target >= 0 && target < section.members.length) {
            root.currentIndex = section.start + target
            return
        }
        const neighbour = position.section + (step > 0 ? 1 : -1)
        if (neighbour < 0 || neighbour >= root.sections.length) return
        const next = root.sections[neighbour]
        root.currentIndex = step > 0
            ? next.start : next.start + next.members.length - 1
    }
    // Up/down keeps the column. Leaving a section lands on the same column in
    // the next one, clamped to its last row, or on the first/last cell at the
    // ends of the listing.
    function moveVertical(step: int): void {
        if (root.filtered.length === 0) return
        const columns = Math.max(1, root.columns)
        const position = root.sectionPosition(root.currentIndex)
        const section = root.sections[position.section]
        if (!section || step === 0) return
        const target = position.offset + columns * step
        if (target >= 0 && target < section.members.length) {
            root.currentIndex = section.start + target
            return
        }
        const column = position.offset % columns
        if (step > 0) {
            for (let index = position.section + 1; index < root.sections.length; ++index) {
                const members = root.sections[index].members
                root.currentIndex = root.sections[index].start
                    + Math.min(column, members.length - 1)
                return
            }
            root.currentIndex = root.filtered.length - 1
            return
        }
        for (let index = position.section - 1; index >= 0; --index) {
            const members = root.sections[index].members
            const lastRow = (Math.ceil(members.length / columns) - 1) * columns
            root.currentIndex = root.sections[index].start
                + Math.min(lastRow + column, members.length - 1)
            return
        }
        root.currentIndex = 0
    }
    function selectFirst(): void {
        root.currentIndex = root.filtered.length > 0 ? 0 : -1
    }
    function selectLast(): void {
        root.currentIndex = root.filtered.length > 0 ? root.filtered.length - 1 : -1
    }
    // A page advances by the number of display rows in the viewport. Category
    // headings consume a row slot, so page movement must not count them as apps.
    function selectPage(step: int): void {
        if (root.filtered.length === 0 || step === 0) return
        const rows = root.displayRows
        if (rows.length === 0) return
        const direction = step < 0 ? -1 : 1
        const currentRow = root.displayRowFor(root.currentIndex)
        const pageRows = Math.max(1, Math.abs(step) * Math.max(1, root.rows))
        const targetRow = Math.max(0, Math.min(rows.length - 1,
            currentRow + direction * pageRows))
        let row = targetRow
        while (row >= 0 && row < rows.length && rows[row].kind !== "row")
            row += direction
        if (row < 0 || row >= rows.length) {
            row = targetRow - direction
            while (row >= 0 && row < rows.length && rows[row].kind !== "row")
                row -= direction
        }
        if (row < 0 || row >= rows.length) return
        const members = rows[row].members
        if (!members || members.length === 0) return
        const position = root.sectionPosition(root.currentIndex)
        const column = position.offset % Math.max(1, root.columns)
        root.currentIndex = members[Math.min(column, members.length - 1)].index
    }
    function reset(): void {
        root.searchText = ""
        root.currentIndex = root.filtered.length > 0 ? 0 : -1
    }
}
