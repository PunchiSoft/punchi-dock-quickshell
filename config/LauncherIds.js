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
            && (entry.browseSubfolders === undefined || typeof entry.browseSubfolders === "boolean")))
        return false
    return new Set(containers.map(entry => entry.id)).size === containers.length
}
