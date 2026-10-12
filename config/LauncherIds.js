// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library
const maximumPins = 32
const presets = ["files", "terminal", "browser", "kate", "systemsettings", "discover", "gwenview", "okular"]
function valid(id) {
    return typeof id === "string" && (presets.indexOf(id) >= 0
        || /^desktop:[A-Za-z0-9_][A-Za-z0-9_.-]{0,254}$/.test(id))
}
function validList(ids) {
    return Array.isArray(ids) && ids.length <= maximumPins
        && ids.every(id => valid(id)) && new Set(ids).size === ids.length
}
