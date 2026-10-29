// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library
const maximumPins = 32
const presets = ["files", "terminal", "browser", "kate", "systemsettings", "discover", "gwenview", "okular"]
// Folder containers carry a stable slug so changing the folder they point at
// never changes the item's identity, order or open popup. `item:downloads` is
// the retired pre-container id and only stays valid so old profiles load.
const containerPrefix = "item:folder:"
const containerIdPattern = /^[A-Za-z0-9_][A-Za-z0-9_-]{0,31}$/
// Presentations a container can use. `fan` unfolds its entries as an arc; the
// other three keep the flat layouts of the popup.
const layouts = ["grid", "list", "detail", "fan"]
function validLayout(layout) {
    return typeof layout === "string" && layouts.indexOf(layout) >= 0
}
function containerId(id) {
    return typeof id === "string" && id.indexOf(containerPrefix) === 0
        ? id.slice(containerPrefix.length) : ""
}
function isContainer(id) {
    return containerIdPattern.test(containerId(id))
}
function valid(id) {
    return typeof id === "string" && (id === "item:trash" || id === "item:downloads"
        || isContainer(id) || presets.indexOf(id) >= 0
        || /^desktop:[A-Za-z0-9_][A-Za-z0-9_.-]{0,254}$/.test(id))
}
function validList(ids) {
    return Array.isArray(ids) && ids.length <= maximumPins
        && ids.every(id => valid(id)) && new Set(ids).size === ids.length
}
// Icon names come from a theme, so they never carry a path separator, a space
// or a traversal sequence; an empty name means "use the application icon".
function validIconName(name) {
    return typeof name === "string" && name.length <= 200
        && (name.length === 0 || (/^[A-Za-z0-9_][A-Za-z0-9_.+-]*$/.test(name) && name.indexOf("..") < 0))
}
function validIconOverrides(overrides) {
    if (!overrides || typeof overrides !== "object" || Array.isArray(overrides)) return false
    const entries = Object.entries(overrides)
    return entries.length <= maximumPins
        && entries.every(entry => valid(entry[0]) && validIconName(entry[1]) && entry[1].length > 0)
}
// Entries a container popup skips, identified by file name inside its folder.
// A name never carries a separator, so a stored list cannot point outside.
var maximumHiddenEntries = 2000
function validHiddenEntry(name) {
    return typeof name === "string" && name.length > 0 && name.length <= 200
        && name !== "." && name !== ".." && name.indexOf("/") < 0 && name.indexOf("\\") < 0
}
function validHiddenEntries(names) {
    return Array.isArray(names) && names.length <= maximumHiddenEntries
        && names.every(validHiddenEntry)
}
function normalizeHiddenEntries(names) {
    const next = []
    if (!Array.isArray(names)) return next
    for (const name of names) {
        if (!validHiddenEntry(name) || next.indexOf(name) >= 0) continue
        next.push(name)
        if (next.length >= maximumHiddenEntries) break
    }
    return next
}
function validContainerPath(path) {
    return typeof path === "string" && (path.length === 0 || path.charAt(0) === "/")
}
function validContainers(containers) {
    if (!Array.isArray(containers) || containers.length === 0 || containers.length > maximumPins) return false
    if (!containers.every(entry => entry && typeof entry === "object"
            && containerIdPattern.test(entry.id || "")
            && validContainerPath(entry.path)
            && typeof entry.title === "string" && typeof entry.icon === "string"
            && (entry.layout === undefined || validLayout(entry.layout))
            && (entry.sortMode === undefined || ["name", "size", "modified", "created", "kind"].indexOf(entry.sortMode) >= 0)
            && (entry.browseSubfolders === undefined || typeof entry.browseSubfolders === "boolean")
            && (entry.hiddenEntries === undefined || validHiddenEntries(entry.hiddenEntries))))
        return false
    return new Set(containers.map(entry => entry.id)).size === containers.length
}
