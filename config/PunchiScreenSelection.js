// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Pure placement logic shared by the settings record, the screen policy and its
// tests. Stored selections are opaque keys: changing a monitor's connector name
// asks the user to choose again rather than guessing a different screen.
const screenModes = ["all", "selected"]
const targetModes = ["all", "selected"]
const maximumSelections = 16
const maximumKeyLength = 128
const edgeTolerance = 1

function acceptsMode(mode) {
    return screenModes.indexOf(mode) >= 0
}

function acceptsTargetMode(mode) {
    return targetModes.indexOf(mode) >= 0
}

function screenKey(screen) {
    if (!screen) return ""
    const name = typeof screen.name === "string" ? screen.name : ""
    return name.slice(0, maximumKeyLength)
}

function validSelection(value) {
    if (!Array.isArray(value) || value.length > maximumSelections) return false
    for (const entry of value) {
        if (typeof entry === "number" && Number.isFinite(entry)) continue
        if (typeof entry !== "string" || entry.length === 0 || entry.length > maximumKeyLength)
            return false
    }
    return true
}

function normalizeSelection(value) {
    if (!validSelection(value)) return []
    const result = []
    for (const entry of value) {
        const key = String(entry)
        if (result.indexOf(key) < 0) result.push(key)
    }
    return result
}

function selected(screen, keys) {
    const key = screenKey(screen)
    return key.length > 0 && Array.isArray(keys) && keys.indexOf(key) >= 0
}

// Returns the screens that should show a dock. A selected mode with none of its
// screens connected falls back to the system primary screen, so a dock never
// disappears without a usable surface.
function screenList(value) {
    // Quickshell exposes screens as a QML list, which is array-like but not
    // necessarily a JavaScript Array.
    return value && typeof value.length === "number" && typeof value !== "string" ? value : []
}

function resolveScreens(connected, mode, keys, primaryName) {
    const screens = screenList(connected)
    if (mode !== "selected") return screens
    const matches = screens.filter(screen => selected(screen, keys))
    if (matches.length > 0) return matches
    const primary = screens.find(screen => screenKey(screen) === primaryName)
    if (primary) return [primary]
    return screens.length > 0 ? [screens[0]] : []
}

function allows(screen, connected, mode, keys, primaryName) {
    if (!screen) return false
    const key = screenKey(screen)
    if (key.length === 0) return false
    return resolveScreens(connected, mode, keys, primaryName)
        .some(candidate => screenKey(candidate) === key)
}

function verticalOverlap(first, second) {
    return first.y < second.y + second.height && second.y < first.y + first.height
}

function horizontalOverlap(first, second) {
    return first.x < second.x + second.width && second.x < first.x + first.width
}

// True when another connected screen touches the chosen physical edge. Such an
// internal edge cannot carry a reliable reveal trigger.
function edgeIsShared(screen, connected, edge) {
    const screens = screenList(connected)
    if (!screen) return false
    for (const other of screens) {
        if (!other || other === screen || other.width <= 0 || other.height <= 0) continue
        if (edge === "bottom") {
            if (Math.abs(other.y - (screen.y + screen.height)) <= edgeTolerance
                    && horizontalOverlap(screen, other)) return true
        } else if (edge === "top") {
            if (Math.abs((other.y + other.height) - screen.y) <= edgeTolerance
                    && horizontalOverlap(screen, other)) return true
        } else if (edge === "right") {
            if (Math.abs(other.x - (screen.x + screen.width)) <= edgeTolerance
                    && verticalOverlap(screen, other)) return true
        } else if (edge === "left") {
            if (Math.abs((other.x + other.width) - screen.x) <= edgeTolerance
                    && verticalOverlap(screen, other)) return true
        }
    }
    return false
}

function keyConnected(connected, key) {
    const screens = screenList(connected)
    for (const screen of screens) {
        if (screenKey(screen) === key) return true
    }
    return false
}

// Saved keys that no connected screen answers. They stay in the profile so the
// selection comes back when the monitor does, but the card must say so.
function disconnectedKeys(connected, keys) {
    return normalizeSelection(keys).filter(key => !keyConnected(connected, key))
}

// Empty when a saved screen is connected. Otherwise names the screen that shows
// the dock instead, so the settings card can expose the temporary fallback.
function fallbackKey(connected, mode, keys, primaryName) {
    if (mode !== "selected") return ""
    const screens = screenList(connected)
    if (screens.length === 0) return ""
    const normalized = normalizeSelection(keys)
    if (normalized.some(key => keyConnected(screens, key))) return ""
    const active = resolveScreens(screens, mode, normalized, primaryName)
    return active.length > 0 ? screenKey(active[0]) : ""
}

// A screen selector is useful only when it offers a real choice. With one
// connected screen, keep it visible only to explain a saved selection that is
// unplugged or an empty selection currently falling back to the primary screen.
function showsScreenPlacement(connected, mode, keys, primaryName) {
    const screens = screenList(connected)
    if (screens.length > 1) return true
    if (mode !== "selected") return false
    return disconnectedKeys(screens, keys).length > 0
        || fallbackKey(screens, mode, keys, primaryName).length > 0
}
