// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Shared law of the folder fan. The rows of a container unfold as one arc whose
// lean and sag are functions of the same row distance, so the angle of a row and
// the path it travels cannot drift apart. The law lives here without Qt objects,
// which lets the view reserve exactly the room its leaned pills need and lets the
// tests check the geometry without a scene.

// Angular step of one row, in degrees, and the quadratic sag that keeps the rows
// tangent to the circle their lean describes.
const rowArcStepDegrees = 1.30
const rowSagPerPitch = 0.0258
const rowSagPerPitchSquared = 0.0109
const maximumRows = 8

function clamp(value, minimum, maximum) {
    const number = Number(value)
    if (!Number.isFinite(number)) {
        return minimum
    }
    return Math.max(minimum, Math.min(maximum, number))
}

function safeRows(rows) {
    const count = Math.floor(Number(rows))
    return Number.isFinite(count) ? Math.max(1, count) : 1
}

function safeIndex(index, rows) {
    const requested = Math.floor(Number(index))
    const number = Number.isFinite(requested) ? requested : 0
    return Math.max(0, Math.min(safeRows(rows) - 1, number))
}

// The dock edge, not a popup direction: the panel that hosts the container
// decides where the arc starts and which side carries the name.
function isHorizontal(edge) {
    return edge === "bottom" || edge === "top"
}

// Whether the icon sits on the right of its pill. A left panel opens its popup
// to the right, so the name goes on that side, away from the panel.
function iconsOnRight(edge) {
    return edge !== "left"
}

function curveDirection(edge) {
    return isHorizontal(edge) || !iconsOnRight(edge) ? 1 : -1
}

// Position of a row along the arc: 0 at the row that faces the panel and 1 at
// the far end of the sweep. A vertical panel grows from its middle, so both
// halves measure their distance from it.
function normalizedDistance(index, rows, edge) {
    const count = safeRows(rows)
    const span = Math.max(1, count - 1)
    const fromTop = clamp(safeIndex(index, count) / span, 0, 1)
    if (edge === "bottom") {
        return 1 - fromTop
    }
    if (edge === "top") {
        return fromTop
    }
    return Math.abs(fromTop - 0.5) * 2
}

function travelSign(edge, fromTop) {
    if (edge === "bottom") {
        return 1
    }
    if (edge === "top") {
        return -1
    }
    return fromTop >= 0.5 ? -1 : 1
}

// Signed lean of a row, in degrees. Every row of a horizontal panel turns the
// way the arc opens; a vertical panel turns the rows above its middle towards
// one side and the rows below towards the other.
function leanForIndex(index, rows, edge, stepDegrees) {
    const count = safeRows(rows)
    const span = Math.max(0, count - 1)
    const requestedStep = Number(stepDegrees)
    const step = Number.isFinite(requestedStep) ? requestedStep : rowArcStepDegrees
    const fromTop = span > 0 ? safeIndex(index, count) / span : 0
    return travelSign(edge, fromTop) * curveDirection(edge) * step * span
        * normalizedDistance(index, count, edge)
}

// Position of a row along the arc, measured from the straight line of the
// icon. The sag is the second order of the very angle that turns the row, so
// one law governs both and each row stays tangent to the path it travels.
function curveOffsetForDistance(distance, rows, rowHeight) {
    const span = Math.max(0, safeRows(rows) - 1)
    const row = clamp(distance, 0, 1) * span
    const pitch = Math.max(0, Number(rowHeight) || 0)
    return pitch * (rowSagPerPitch * row + rowSagPerPitchSquared * row * row)
}

function curveOffsetForIndex(index, rows, edge, rowHeight) {
    return curveOffsetForDistance(normalizedDistance(index, rows, edge),
        rows, rowHeight)
}

// Flight of one pill outside its row band for a given lean in radians. The
// pivot is the centre of the icon, which never leaves the band, and the pill
// sits beside it on the side the arc leaves free, so the rotation carries the
// pill towards one end of the band and away from the other.
//   reach = iconSize/2 + iconSpacing + reserved label width / 2
//   half extent = width/2 · |sin θ| + labelHeight/2 · cos θ
// `metrics` carries iconSize, iconSpacing, labelWidth, labelHeight, rowHeight
// and iconsOnRight.
function overhangForLean(radians, metrics) {
    const iconSize = Math.max(0, Number(metrics.iconSize) || 0)
    const iconSpacing = Math.max(0, Number(metrics.iconSpacing) || 0)
    const labelWidth = Math.max(0, Number(metrics.labelWidth) || 0)
    const labelHeight = Math.max(0, Number(metrics.labelHeight) || 0)
    const rowHeight = Math.max(1, Number(metrics.rowHeight) || 1)
    const pivotDistance = iconSize / 2 + iconSpacing + labelWidth / 2
    const halfExtent = labelWidth / 2 * Math.abs(Math.sin(radians))
        + labelHeight / 2 * Math.cos(radians)
    const pillSide = metrics.iconsOnRight ? -1 : 1
    const centreOffset = pillSide * pivotDistance * Math.sin(radians)
    return {
        "up": Math.max(0, -centreOffset + halfExtent - rowHeight / 2),
        "down": Math.max(0, centreOffset + halfExtent - rowHeight / 2)
    }
}

// Reserve the arc needs at each end of a band of `rowCount` rows. Up is the
// start of the list and down its end; the row that faces the panel stands
// upright, so it adds no reserve of its own.
function envelopeForRows(rowCount, edge, metrics) {
    const rows = safeRows(rowCount)
    if (!metrics || !metrics.labelWidth) {
        return {"leading": 0, "trailing": 0}
    }
    let leading = 0
    let trailing = 0
    for (let index = 0; index < rows; ++index) {
        const overhang = overhangForLean(leanForIndex(index, rows, edge)
            * Math.PI / 180, metrics)
        leading = Math.max(leading, overhang.up)
        trailing = Math.max(trailing, overhang.down)
    }
    return {"leading": Math.ceil(leading), "trailing": Math.ceil(trailing)}
}

// Rows the popup can show: the configured limit while the height allows it, and
// fewer when the display does not. The envelope grows with the row count, so the
// search walks down from the configured maximum and stops at the first count
// whose reserve and band fit together. One row is always kept, because a fan
// that shows nothing cannot be used.
function visibleRows(itemCount, rowLimit, maximumContentHeight, extraRows, edge,
        metrics) {
    const entries = Math.max(0, Math.floor(Number(itemCount) || 0))
    const requestedLimit = Number(rowLimit)
    const limit = clamp(Number.isFinite(requestedLimit) ? requestedLimit : 6,
        1, maximumRows)
    const configured = Math.max(1, Math.min(entries, limit))
    const extra = Math.max(0, Math.floor(Number(extraRows) || 0))
    const ceiling = Number(maximumContentHeight)
    if (!Number.isFinite(ceiling) || ceiling <= 0) {
        return configured
    }
    const pitch = Math.max(1, Number(metrics && metrics.rowHeight) || 1)
    for (let rows = configured; rows > 1; --rows) {
        const total = rows + extra
        const envelope = envelopeForRows(total, edge, metrics)
        if (envelope.leading + total * pitch + envelope.trailing <= ceiling) {
            return rows
        }
    }
    return 1
}

// Per-item opening progress. Dividing by a rate below one makes the row that
// faces the panel settle earlier, while the far end closes the sweep; no item
// waits before it starts because every rate stays above zero.
function revealProgressForDistance(distance, progress, sweepShare) {
    const requestedProgress = Number(progress)
    const safeProgress = Number.isFinite(requestedProgress)
        ? clamp(requestedProgress, 0, 1) : 1
    const requestedSweep = Number(sweepShare)
    const sweep = Number.isFinite(requestedSweep)
        ? clamp(requestedSweep, 0, 0.8) : 0
    if (sweep <= 0) {
        return safeProgress
    }
    const requestedDistance = Number(distance)
    const safeDistance = Number.isFinite(requestedDistance)
        ? clamp(requestedDistance, 0, 1) : 0
    return clamp(safeProgress / (1 - sweep + sweep * safeDistance), 0, 1)
}

// Row of the band the fan unfolds from: the one nearest the panel. A vertical
// panel unfolds from its middle row.
function anchorIndex(rows, edge) {
    const count = safeRows(rows)
    if (edge === "bottom") {
        return Math.max(0, count - 1)
    }
    if (edge === "top") {
        return 0
    }
    return (count - 1) / 2
}
