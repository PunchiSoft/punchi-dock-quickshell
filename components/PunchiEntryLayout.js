// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Arrangement law of a folder container, ported from the reference popup. The
// columns are chosen by a cost, not by a fixed formula, so scrolling is the last
// resort: one overflowing row is worth much more than any amount of empty cells,
// and a lone cell on the last line is worth a step. The law lives here without
// Qt objects, which lets the view reserve exactly the room its rows need and the
// tests check the result without a scene.

// Shape the automatic arrangement aims at, as columns divided by rows.
const targetRatio = 1.5
// Cost of one application left alone on the last line.
const orphanPenalty = 1
// Cost of one row that would not fit the height the popup offers. It stays far
// above the other terms, so scrolling is always the last resort.
const overflowWeight = 10

function safeCount(value) {
    const number = Math.floor(Number(value))
    return Number.isFinite(number) ? Math.max(0, number) : 0
}

function safeLines(value) {
    const number = Math.floor(Number(value))
    return Number.isFinite(number) ? Math.max(1, number) : 1
}

// Cost of arranging `cellTotal` cells in `columns` columns. The holes are the
// sum, row by row, of the cells a row does not use, so `holes / columns` is the
// relative slack of the last row. The location action takes the first free seat
// of that row, so a last row holding one entry plus the action reads as complete
// and never counts as ragged.
function gridCost(cellTotal, applicationTotal, hasLocationAction, columns, rowLimit) {
    const total = safeCount(cellTotal)
    const applications = safeCount(applicationTotal)
    const safeColumns = safeLines(columns)
    const rows = Math.ceil(total / safeColumns)
    const holes = safeColumns * rows - total
    const overflow = Math.max(0, rows - safeLines(rowLimit))
    const shapeDelta = Math.log(safeColumns / rows) - Math.log(targetRatio)
    const lastApplicationRow = applications <= 0
        ? 0 : ((applications - 1) % safeColumns) + 1
    const ragged = lastApplicationRow === 1
        && applications > safeColumns
        && (!hasLocationAction || lastApplicationRow + 1 > safeColumns)
    return overflowWeight * overflow
        + holes / safeColumns
        + shapeDelta * shapeDelta
        + (ragged ? orphanPenalty : 0)
}

// Column count of an automatic grid. One line wins whenever its cells fit,
// because it is the shortest arrangement and can never leave a ragged row.
// Otherwise the candidates run from two columns up to the ceiling the width and
// the row limit allow, and the cheapest one wins with ties resolved towards the
// widest grid, which is how the reference distribution reads.
function gridColumnCount(cellTotal, applicationTotal, hasLocationAction, maximumColumns,
        rowLimit) {
    const total = safeCount(cellTotal)
    const ceiling = safeLines(maximumColumns)
    if (total <= 0) return 1
    if (total <= ceiling) return total
    if (ceiling < 2) return ceiling
    let selectedColumns = 2
    let selectedCost = Number.POSITIVE_INFINITY
    for (let columns = 2; columns <= ceiling; columns++) {
        const cost = Math.round(gridCost(total, applicationTotal, hasLocationAction,
            columns, rowLimit) * 1e9) / 1e9
        if (cost < selectedCost || (cost === selectedCost && columns > selectedColumns)) {
            selectedColumns = columns
            selectedCost = cost
        }
    }
    return selectedColumns
}

// Columns the width of the surface can hold, before the arrangement starts.
function columnCeiling(availableWidth, cellWidth) {
    const width = Number(availableWidth)
    const cell = Number(cellWidth)
    if (!Number.isFinite(width) || !Number.isFinite(cell) || cell <= 0) return 1
    return Math.max(1, Math.floor(width / cell))
}

// Rows the height of the surface can hold.
function rowCeiling(availableHeight, cellHeight) {
    const height = Number(availableHeight)
    const cell = Number(cellHeight)
    if (!Number.isFinite(height) || !Number.isFinite(cell) || cell <= 0) return 1
    return Math.max(1, Math.floor(height / cell))
}

// Complete arrangement of a container. A folder container ends with its
// location action, so its cell total is one more than its entries; a container
// whose entries all launch an application passes `hasLocationAction` false.
// `visibleRows` is what the surface shows without scrolling, so the caller can
// size itself to whole rows instead of clipping the last one.
function arrangement(entryCount, maximumColumns, rowLimit, hasLocationAction) {
    const extra = hasLocationAction === false ? 0 : 1
    const entries = safeCount(entryCount)
    const lines = safeLines(rowLimit)
    const columns = gridColumnCount(entries + extra, entries, extra === 1, maximumColumns, lines)
    const rows = Math.ceil((entries + extra) / columns)
    return {
        "columns": columns,
        "rows": rows,
        "visibleRows": Math.min(rows, lines),
        "scrollRequired": rows > lines
    }
}

// Complete arrangement of a single-column presentation (list or detail).
function singleColumnArrangement(entryCount, rowLimit, hasLocationAction) {
    const extra = hasLocationAction === false ? 0 : 1
    const lines = safeLines(rowLimit)
    const rows = safeCount(entryCount) + extra
    return {
        "columns": 1,
        "rows": rows,
        "visibleRows": Math.min(rows, lines),
        "scrollRequired": rows > lines
    }
}
