// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Two presentations for the KDE history: the applications join the dock row as
// their own launchers, or one fixed item opens a container with the same
// entries. The container views are the folder container views, so a stored fan
// keeps its meaning when the dock returns to a horizontal edge.
const presentations = ["icons", "container"]
const containerLayouts = ["grid", "list", "detail", "fan"]
// The plasmoid's glyph, borrowed so the item reads the same to someone coming
// from Punchi Dock Remastered.
const containerIcon = "folder-temp"

function validPresentation(value) {
    return typeof value === "string" && presentations.indexOf(value) >= 0
}

function validContainerLayout(value) {
    return typeof value === "string" && containerLayouts.indexOf(value) >= 0
}

function normalizePresentation(value) {
    return validPresentation(value) ? value : "container"
}

function normalizeContainerLayout(value) {
    return validContainerLayout(value) ? value : "list"
}
