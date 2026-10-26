// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import org.kde.kirigami as Kirigami
import "LauncherIds.js" as LauncherIds
import "PanelModes.js" as PanelModes
import "../adapters/kde"

QtObject {
    readonly property DockMetrics metrics: DockMetrics {}
    property int sizePercent: 100
    property int iconSize: Math.round(metrics.iconSize * sizePercent / 100)
    property int itemSize: iconSize + metrics.itemSize - metrics.iconSize
    property int spacing: metrics.spacing
    property int padding: metrics.padding
    property int edgeMargin: metrics.edgeMargin
    property real surfaceRadius: metrics.surfaceRadius
    property int bottomContentPadding: metrics.bottomContentPadding
    property string dockEdge: "bottom"
    // The arc unfolds from the row that faces the panel, so it needs a horizontal
    // one. The stored choice survives an edge change; only its presentation
    // follows the edge, which a return to the bottom or top restores.
    readonly property bool fanSupported: dockEdge === "bottom" || dockEdge === "top"
    property string panelMode: "overlay"
    onPanelModeChanged: {
        if (panelMode === "desktop") panelMode = PanelModes.normalize(panelMode)
    }
    property bool magnificationEnabled: true
    property bool reducedMotion: false
    property bool bounceEnabled: true
    property bool recentApplicationsEnabled: true
    property int recentApplicationsCount: 5
    // Popup presentation for the folder containers. The dock menus share the
    // same visual language but keep the platform sizes. The scale multiplies the
    // row and cell sizes, the first icon size is the base glyph of a folder grid,
    // the next two size the rows and the arc, and the height percent is how much
    // of the host a popup may cover before its content scrolls.
    property real popupScale: 1.0
    // Zero means the theme's large icon, so a profile that never chose a size
    // follows the platform.
    property int popupIconSize: 0
    property int popupHeightPercent: 80
    // The list/detail and fan glyphs are chosen separately: fan rows sit 1.33
    // icons apart, so a size that reads well in the grid crowds the arc. Zero
    // means the theme's token for that presentation.
    property int popupListIconSize: 0
    property int popupFanIconSize: 0
    // One range per presentation, shared by the settings sliders and the record
    // validation so a stored value can never be one a slider cannot show.
    readonly property int popupIconSizeMinimum: 24
    readonly property int popupGridIconSizeMaximum: 96
    readonly property int popupListIconSizeMaximum: 64
    readonly property int popupFanIconSizeMaximum: 56
    property var pinnedIds: ["files", "terminal", "browser", "kate", "systemsettings", "discover", "gwenview", "okular", "item:downloads", "item:trash"]
    // Folder containers owned by this profile. An empty path means the user's
    // download location, which the native folder model resolves through
    // QStandardPaths, so the built-in Downloads container needs no stored path.
    // The built-in container keeps its historical item id; containers added
    // later use item:folder:<id>.
    property var containers: [{id: "downloads", path: "", title: qsTr("Downloads"), icon: "folder-downloads", layout: "grid", sortMode: "modified", browseSubfolders: true, hiddenEntries: []}]
    // Icon chosen in the item editor for a pinned application. The catalog keeps
    // owning the desktop-entry icon; this map only overrides its presentation.
    property var iconOverrides: ({})
    // Compatibility accessor for existing scripts and schema-3/4 profiles.
    // Container layout is stored on each item; this mirrors the built-in one.
    property string downloadsView: "grid"
    onDownloadsViewChanged: setContainerLayout("item:downloads", downloadsView)
    onContainersChanged: {
        const downloads = container("item:downloads")
        if (downloads && LauncherIds.validLayout(downloads.layout)
                && downloadsView !== downloads.layout)
            downloadsView = downloads.layout
    }
    property real maximumIconScale: 2.0
    readonly property MotionPreferences desktopMotion: MotionPreferences {}
    readonly property bool effectiveReducedMotion: reducedMotion || desktopMotion.reducedMotion
    readonly property int clickDuration: bounceEnabled ? desktopMotion.clickDuration : 0
    readonly property int waveEnterDuration: desktopMotion.enterDuration
    readonly property int waveLeaveDuration: desktopMotion.leaveDuration
    readonly property int slideDuration: desktopMotion.slideDuration

    // One place that turns a stored record into the complete shape, so a new
    // container field never has to be repeated in every setter.
    function containerRecord(entry, patch): var {
        const next = {id: entry.id, path: entry.path, title: entry.title, icon: entry.icon,
            layout: entry.layout || "grid", sortMode: entry.sortMode || "modified",
            browseSubfolders: entry.browseSubfolders !== false,
            hiddenEntries: Array.isArray(entry.hiddenEntries) ? entry.hiddenEntries : []}
        if (patch) Object.assign(next, patch)
        return next
    }
    function container(appId): var {
        const id = containerIdOf(appId)
        if (id.length === 0) return null
        for (const entry of containers) if (entry.id === id) return entry
        return null
    }
    // Presentation a container really uses. A vertical panel has no near row to
    // unfold from, so a stored fan is presented as Grid without rewriting it.
    function effectiveContainerLayout(appId): string {
        const entry = container(appId)
        const layout = entry && entry.layout ? String(entry.layout) : "grid"
        return layout === "fan" && !fanSupported ? "grid" : layout
    }
    function containerIdOf(appId): string {
        // The built-in Downloads container keeps its historical item id.
        return appId === "item:downloads" ? "downloads" : LauncherIds.containerId(appId)
    }
    function addContainer(path: string, title: string, icon: string, layout): string {
        if (layout === undefined) layout = "grid"
        if (containers.length >= LauncherIds.maximumPins) return ""
        if (!LauncherIds.validContainerPath(path)) return ""
        if (!LauncherIds.validLayout(layout)) return ""
        let suffix = containers.length
        while (containers.some(entry => entry.id === "folder-" + suffix)) ++suffix
        const id = "folder-" + suffix
        containers = containers.concat([{id, path, title, icon: icon.length > 0 ? icon : "folder", layout,
            sortMode: "modified", browseSubfolders: true, hiddenEntries: []}])
        return "item:folder:" + id
    }
    function removeContainer(appId: string): bool {
        const id = containerIdOf(appId)
        if (id.length === 0 || id === "downloads") return false
        const next = containers.filter(entry => entry.id !== id)
        if (next.length === containers.length) return false
        containers = next
        return true
    }
    function setContainerPath(appId: string, path: string): bool {
        const id = containerIdOf(appId)
        if (id.length === 0 || !LauncherIds.validContainerPath(path)) return false
        let changed = false
        containers = containers.map(entry => {
            if (entry.id !== id || entry.path === path) return entry
            changed = true
            return containerRecord(entry, {path})
        })
        return changed
    }
    function setContainerLayout(appId: string, layout: string): bool {
        const id = containerIdOf(appId)
        if (id.length === 0 || !LauncherIds.validLayout(layout)) return false
        let found = false
        containers = containers.map(entry => {
            if (entry.id !== id) return entry
            found = true
            if (entry.layout === layout) return entry
            return containerRecord(entry, {layout})
        })
        return found
    }

    function setContainerBrowseSubfolders(appId: string, enabled: bool): bool {
        const id = containerIdOf(appId)
        if (id.length === 0) return false
        let changed = false
        containers = containers.map(entry => {
            if (entry.id !== id || (entry.browseSubfolders !== false) === enabled) return entry
            changed = true
            return containerRecord(entry, {browseSubfolders: enabled})
        })
        return changed
    }

    // A container enters the subfolders it lists only while its owner keeps the
    // switch on; the fan never enters them, whatever the switch says.
    function containerBrowseSubfolders(appId: string): bool {
        const entry = container(appId)
        return !entry || entry.browseSubfolders !== false
    }

    function iconOverride(appId: string): string {
        const name = iconOverrides ? iconOverrides[appId] : ""
        return typeof name === "string" ? name : ""
    }
    function setIconOverride(appId: string, iconName: string): bool {
        if (!LauncherIds.valid(appId) || !LauncherIds.validIconName(iconName)) return false
        const next = Object.assign({}, iconOverrides)
        if (iconName.length === 0) {
            if (!(appId in next)) return false
            delete next[appId]
        } else {
            if (next[appId] === iconName) return false
            next[appId] = iconName
        }
        iconOverrides = next
        return true
    }

    function setContainerSortMode(appId: string, sortMode: string): bool {
        const id = containerIdOf(appId)
        if (id.length === 0 || ["name", "size", "modified", "created", "kind"].indexOf(sortMode) < 0) return false
        let found = false
        containers = containers.map(entry => {
            if (entry.id !== id) return entry
            found = true
            if (entry.sortMode === sortMode) return entry
            return containerRecord(entry, {sortMode})
        })
        return found
    }

    // Entries the popup must skip, by name inside the container folder.
    // Everything else is shown, so files that arrive later need no new choice.
    function containerHiddenEntries(appId): var {
        const entry = container(appId)
        return entry && Array.isArray(entry.hiddenEntries) ? entry.hiddenEntries : []
    }
    function setContainerHiddenEntries(appId: string, names): bool {
        const id = containerIdOf(appId)
        if (id.length === 0 || !LauncherIds.validHiddenEntries(names)) return false
        const normalized = LauncherIds.normalizeHiddenEntries(names)
        let changed = false
        containers = containers.map(entry => {
            if (entry.id !== id) return entry
            const current = Array.isArray(entry.hiddenEntries) ? entry.hiddenEntries : []
            if (JSON.stringify(current) === JSON.stringify(normalized)) return entry
            changed = true
            return containerRecord(entry, {hiddenEntries: normalized})
        })
        return changed
    }

    function snapshot(): var {
        return {version: 11, downloadsView, containers, dockEdge, panelMode, sizePercent, magnificationEnabled,
            reducedMotion, bounceEnabled, maximumIconScale, pinnedIds, iconOverrides, recentApplicationsEnabled,
            recentApplicationsCount, popupScale, popupIconSize, popupListIconSize, popupFanIconSize,
            popupHeightPercent}
    }
    function validPopupIconSize(value, maximum): bool {
        return value === 0 || (Number.isInteger(value) && value >= popupIconSizeMinimum
            && value <= maximum)
    }
    function restore(data: var): bool {
        if (!data || [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11].indexOf(data.version) < 0) return false
        const hasLegacyDownloadsView = LauncherIds.validLayout(data.downloadsView)
        const legacyDownloadsView = hasLegacyDownloadsView ? data.downloadsView : downloadsView
        if (LauncherIds.validContainers(data.containers)) {
            containers = data.containers.map(entry => ({id: entry.id, path: entry.path,
                title: entry.title, icon: entry.icon,
                layout: LauncherIds.validLayout(entry.layout)
                    ? entry.layout : (entry.id === "downloads"
                        ? (hasLegacyDownloadsView ? legacyDownloadsView : "grid") : "grid"),
                sortMode: data.version >= 6 && ["name", "size", "modified", "created", "kind"].indexOf(entry.sortMode) >= 0
                    ? entry.sortMode : "modified",
                browseSubfolders: entry.browseSubfolders !== false,
                hiddenEntries: data.version >= 9 && LauncherIds.validHiddenEntries(entry.hiddenEntries)
                    ? LauncherIds.normalizeHiddenEntries(entry.hiddenEntries) : []}))
        } else if (hasLegacyDownloadsView && legacyDownloadsView !== downloadsView) {
            setContainerLayout("item:downloads", legacyDownloadsView)
        }
        if (["bottom", "left", "right"].indexOf(data.dockEdge) >= 0) dockEdge = data.dockEdge
        else if (data.dockEdge === undefined) dockEdge = "bottom"
        if (PanelModes.accepts(data.panelMode)) panelMode = PanelModes.normalize(data.panelMode)
        if (Number.isInteger(data.sizePercent) && data.sizePercent >= 50 && data.sizePercent <= 150)
            sizePercent = data.sizePercent
        if (Number.isFinite(data.maximumIconScale) && data.maximumIconScale >= 1 && data.maximumIconScale <= 3)
            maximumIconScale = data.maximumIconScale
        if (Number.isFinite(data.popupScale) && data.popupScale >= 0.8 && data.popupScale <= 1.3)
            popupScale = data.popupScale
        if (validPopupIconSize(data.popupIconSize, popupGridIconSizeMaximum))
            popupIconSize = data.popupIconSize
        if (validPopupIconSize(data.popupListIconSize, popupListIconSizeMaximum))
            popupListIconSize = data.popupListIconSize
        if (validPopupIconSize(data.popupFanIconSize, popupFanIconSizeMaximum))
            popupFanIconSize = data.popupFanIconSize
        if (Number.isInteger(data.popupHeightPercent) && data.popupHeightPercent >= 40
                && data.popupHeightPercent <= 90)
            popupHeightPercent = data.popupHeightPercent
        for (const key of ["magnificationEnabled", "reducedMotion", "bounceEnabled", "recentApplicationsEnabled"])
            if (typeof data[key] === "boolean") this[key] = data[key]
        if (Number.isInteger(data.recentApplicationsCount) && data.recentApplicationsCount >= 1
                && data.recentApplicationsCount <= 20)
            recentApplicationsCount = data.recentApplicationsCount
        // An invalid map is dropped as a whole; partial trust would keep names
        // the picker cannot render.
        iconOverrides = LauncherIds.validIconOverrides(data.iconOverrides) ? data.iconOverrides : ({})
        if (LauncherIds.validList(data.pinnedIds)) {
            pinnedIds = data.pinnedIds.slice()
            if (data.version === 1 && pinnedIds.indexOf("item:trash") < 0
                    && pinnedIds.length < LauncherIds.maximumPins)
                pinnedIds = pinnedIds.concat(["item:trash"])
            if (data.version < 3 && pinnedIds.indexOf("item:trash") >= 0
                    && pinnedIds.indexOf("item:downloads") < 0 && pinnedIds.length < LauncherIds.maximumPins) {
                const migrated = pinnedIds.slice()
                migrated.splice(migrated.indexOf("item:trash"), 0, "item:downloads")
                pinnedIds = migrated
            }
        }
        return true
    }
    function reset(): void {
        restore({version: 11, downloadsView: "grid", dockEdge: "bottom", panelMode: "overlay", sizePercent: 100,
            maximumIconScale: 2, magnificationEnabled: true, reducedMotion: false,
            bounceEnabled: true, recentApplicationsEnabled: true, recentApplicationsCount: 5,
            popupScale: 1, popupIconSize: 0, popupListIconSize: 0, popupFanIconSize: 0,
            popupHeightPercent: 80,
            iconOverrides: {},
            containers: [{id: "downloads", path: "", title: qsTr("Downloads"),
                icon: "folder-downloads", layout: "grid", sortMode: "modified"}],
            pinnedIds: ["files", "terminal", "browser", "kate", "systemsettings", "discover", "gwenview",
                "okular", "item:downloads", "item:trash"]})
    }
}
