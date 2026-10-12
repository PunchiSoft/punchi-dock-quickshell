// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Order matches Plasma's visibility selector. Labels belong to the view.
const modes = ["reserve", "autohide", "dodge-windows", "overlay"]

function normalize(mode) {
    // The retired bottom-layer mode becomes genuine window dodging.
    return mode === "desktop" ? "dodge-windows" : mode
}

function accepts(mode) {
    return modes.indexOf(normalize(mode)) >= 0
}

function effective(mode) {
    return accepts(mode) ? normalize(mode) : "overlay"
}
