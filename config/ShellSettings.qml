// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
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
    property string panelMode: "overlay"
    onPanelModeChanged: {
        if (panelMode === "desktop") panelMode = PanelModes.normalize(panelMode)
    }
    property bool magnificationEnabled: true
    property bool reducedMotion: false
    property bool bounceEnabled: true
    property var pinnedIds: ["files", "terminal", "browser", "kate", "systemsettings", "discover", "gwenview", "okular", "item:downloads", "item:trash"]
    // Folder containers owned by this profile. An empty path means the user's
    // download location, which the native folder model resolves through
    // QStandardPaths, so the built-in Downloads container needs no stored path.
    // The built-in container keeps its historical item id; containers added
    // later use item:folder:<id>.
    property var containers: [{id: "downloads", path: "", title: qsTr("Downloads"), icon: "folder-downloads", layout: "grid", sortMode: "modified"}]
    // Compatibility accessor for existing scripts and schema-3/4 profiles.
    // Container layout is stored on each item; this mirrors the built-in one.
    property string downloadsView: "grid"
    onDownloadsViewChanged: setContainerLayout("item:downloads", downloadsView)
    onContainersChanged: {
        const downloads = container("item:downloads")
        if (downloads && ["grid", "list", "detail"].indexOf(downloads.layout) >= 0
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

    function container(appId): var {
        const id = containerIdOf(appId)
        if (id.length === 0) return null
        for (const entry of containers) if (entry.id === id) return entry
        return null
    }
    function containerIdOf(appId): string {
        // The built-in Downloads container keeps its historical item id.
        return appId === "item:downloads" ? "downloads" : LauncherIds.containerId(appId)
    }
    function addContainer(path: string, title: string, icon: string, layout): string {
        if (layout === undefined) layout = "grid"
        if (containers.length >= LauncherIds.maximumPins) return ""
        if (!LauncherIds.validContainerPath(path)) return ""
        if (["grid", "list", "detail"].indexOf(layout) < 0) return ""
        let suffix = containers.length
        while (containers.some(entry => entry.id === "folder-" + suffix)) ++suffix
        const id = "folder-" + suffix
        containers = containers.concat([{id, path, title, icon: icon.length > 0 ? icon : "folder", layout, sortMode: "modified"}])
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
            return {id: entry.id, path, title: entry.title, icon: entry.icon,
                layout: entry.layout || "grid", sortMode: entry.sortMode || "modified"}
        })
        return changed
    }
    function setContainerLayout(appId: string, layout: string): bool {
        const id = containerIdOf(appId)
        if (id.length === 0 || ["grid", "list", "detail"].indexOf(layout) < 0) return false
        let found = false
        containers = containers.map(entry => {
            if (entry.id !== id) return entry
            found = true
            if (entry.layout === layout) return entry
            return {id: entry.id, path: entry.path, title: entry.title,
                icon: entry.icon, layout, sortMode: entry.sortMode || "modified"}
        })
        return found
    }

    function setContainerSortMode(appId: string, sortMode: string): bool {
        const id = containerIdOf(appId)
        if (id.length === 0 || ["name", "size", "modified", "created", "kind"].indexOf(sortMode) < 0) return false
        let found = false
        containers = containers.map(entry => {
            if (entry.id !== id) return entry
            found = true
            if (entry.sortMode === sortMode) return entry
            return {id: entry.id, path: entry.path, title: entry.title,
                icon: entry.icon, layout: entry.layout || "grid", sortMode}
        })
        return found
    }

    function snapshot(): var {
        return {version: 6, downloadsView, containers, dockEdge, panelMode, sizePercent, magnificationEnabled,
            reducedMotion, bounceEnabled, maximumIconScale, pinnedIds}
    }
    function restore(data: var): bool {
        if (!data || [1, 2, 3, 4, 5, 6].indexOf(data.version) < 0) return false
        const hasLegacyDownloadsView = ["grid", "list", "detail"].indexOf(data.downloadsView) >= 0
        const legacyDownloadsView = hasLegacyDownloadsView ? data.downloadsView : downloadsView
        if (LauncherIds.validContainers(data.containers)) {
            containers = data.containers.map(entry => ({id: entry.id, path: entry.path,
                title: entry.title, icon: entry.icon,
                layout: ["grid", "list", "detail"].indexOf(entry.layout) >= 0
                    ? entry.layout : (entry.id === "downloads"
                        ? (hasLegacyDownloadsView ? legacyDownloadsView : "grid") : "grid"),
                sortMode: data.version >= 6 && ["name", "size", "modified", "created", "kind"].indexOf(entry.sortMode) >= 0
                    ? entry.sortMode : "modified"}))
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
        for (const key of ["magnificationEnabled", "reducedMotion", "bounceEnabled"])
            if (typeof data[key] === "boolean") this[key] = data[key]
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
        restore({version: 6, downloadsView: "grid", dockEdge: "bottom", panelMode: "overlay", sizePercent: 100,
            maximumIconScale: 2, magnificationEnabled: true, reducedMotion: false,
            bounceEnabled: true, containers: [{id: "downloads", path: "", title: qsTr("Downloads"),
                icon: "folder-downloads", layout: "grid", sortMode: "modified"}],
            pinnedIds: ["files", "terminal", "browser", "kate", "systemsettings", "discover", "gwenview",
                "okular", "item:downloads", "item:trash"]})
    }
}
