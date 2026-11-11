// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Application grouping for the fullscreen menu. The catalogue adapter supplies
// the desktop entry's own `categories`; this module turns that vocabulary into
// the ordered sections the menu paints, so the grouping policy stays in the
// service layer and the view only resolves a label per group.

// A desktop entry names one or more XDG categories; a group covers the family
// KDE ships for the same kind of application, exactly as the original menu's
// classifier did.
const families = {
    AudioVideo: ["AudioVideo", "Audio", "Video", "Player", "Music", "Recorder",
        "TV", "AudioVideoEditing"],
    Network: ["Network", "WebBrowser", "Email", "IRCClient", "Feed",
        "FileTransfer", "RemoteAccess", "Internet"],
    Development: ["Development", "IDE", "Building", "Debugger", "TextEditor",
        "RevisionControl", "WebDevelopment"],
    Graphics: ["Graphics", "VectorGraphics", "RasterGraphics", "3DGraphics",
        "Photography", "Viewer", "Paint"],
    Office: ["Office", "WordProcessor", "Spreadsheet", "Presentation",
        "Publishing", "Finance", "Calendar", "Calculator"],
    System: ["System", "Monitor", "Security", "Settings", "PackageManager",
        "TerminalEmulator"],
    Utility: ["Utility", "Utilities", "FileTools", "Archiving", "Clock",
        "TextEditor"],
    Game: ["Game", "ActionGame", "AdventureGame", "ArcadeGame", "BoardGame",
        "CardGame", "BlocksGame", "Emulator"],
    Education: ["Education", "Science", "Math", "History", "Geography"]
}

// The order the sections appear in, from the most used family to the least.
const groupOrder = ["Network", "Graphics", "AudioVideo", "Office",
    "Development", "System", "Utility", "Game", "Education"]

function orderedGroups() {
    return groupOrder.slice()
}

// A catalogue row may leave `categories` absent; a QML string list arrives as
// a JavaScript array, and a fixture may hand over an array directly.
function categoriesOf(application) {
    const value = application ? application.categories : null
    if (!value) return []
    if (Array.isArray(value)) return value.map(entry => String(entry))
    if (typeof value.length === "number")
        return Array.prototype.slice.call(value).map(entry => String(entry))
    return []
}

function matches(categories, requestedGroup) {
    const requested = String(requestedGroup || "").trim()
    if (requested.length === 0 || requested.toLocaleLowerCase() === "all")
        return true
    const targets = families[requested] || [requested]
    const values = categories.map(entry => String(entry).toLocaleLowerCase())
    for (const target of targets)
        if (values.indexOf(target.toLocaleLowerCase()) >= 0) return true
    return false
}

// An exact group wins over a family match, so an entry that names Graphics and
// Viewer is not pulled out of Graphics by whichever family is checked first.
function primaryGroup(categories) {
    const values = categories.map(entry => String(entry).toLocaleLowerCase())
    for (const group of groupOrder)
        if (values.indexOf(group.toLocaleLowerCase()) >= 0) return group
    for (const group of groupOrder)
        if (matches(categories, group)) return group
    return "Other"
}

// Qt's QML engine ignores the numeric option of `localeCompare`, so the
// comparison counts digit runs itself: "KDE 4" precedes "KDE 10".
function compareNames(left, right) {
    const a = String(left || "").toLocaleLowerCase()
    const b = String(right || "").toLocaleLowerCase()
    if (a === b) return 0
    const aParts = a.match(/(\d+|\D+)/g) || []
    const bParts = b.match(/(\d+|\D+)/g) || []
    const shared = Math.min(aParts.length, bParts.length)
    for (let index = 0; index < shared; ++index) {
        const aPart = aParts[index]
        const bPart = bParts[index]
        const aNumber = /^\d/.test(aPart)
        const bNumber = /^\d/.test(bPart)
        if (aNumber && bNumber) {
            const difference = Number(aPart) - Number(bPart)
            if (difference !== 0) return difference
            if (aPart.length !== bPart.length) return aPart.length - bPart.length
        } else if (aPart !== bPart) {
            return aPart < bPart ? -1 : 1
        }
    }
    if (aParts.length !== bParts.length) return aParts.length - bParts.length
    return a < b ? -1 : 1
}

function applicationName(application) {
    if (!application) return ""
    for (const field of [application.name, application.title]) {
        const text = String(field || "").trim()
        if (text.length > 0) return text
    }
    return String(application.appId || "")
}

function sortedByName(applications) {
    const result = applications.slice()
    result.sort((left, right) => {
        const order = compareNames(applicationName(left), applicationName(right))
        if (order !== 0) return order
        return compareNames(String(left.appId || ""), String(right.appId || ""))
    })
    return result
}

// Grouping reads the desktop-entry categories of every visible application and
// keeps the groups that have members, in the reference order with `Other`
// last. Members are alphabetical inside their group.
function sections(applications) {
    const buckets = {}
    for (const application of applications) {
        const group = primaryGroup(categoriesOf(application))
        if (!buckets[group]) buckets[group] = []
        buckets[group].push(application)
    }
    const result = []
    for (const group of groupOrder.concat(["Other"])) {
        const members = buckets[group]
        if (!members || members.length === 0) continue
        result.push({categoryId: group, members: sortedByName(members)})
    }
    return result
}

// A flat listing is one section without a heading: search results, the manual
// order and the alphabetical order all use it.
function flatSection(applications) {
    if (applications.length === 0) return []
    return [{categoryId: "", members: applications.slice()}]
}
