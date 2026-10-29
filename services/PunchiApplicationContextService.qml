// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import "../adapters/kde"
import "../config/PunchiDockItemIds.js" as PunchiDockItemIds

QtObject {
    id: root
    required property var entries
    required property var adapter
    required property var settings
    property string appId: ""
    property string desktopId: ""
    property var actions: []
    property bool canLaunchNewWindow: false
    readonly property bool pinned: appId.length > 0 && settings.pinnedIds.indexOf(appId) >= 0
    readonly property bool canPin: appId.length > 0 && desktopId.length > 0 && !appId.startsWith("item:")
        && PunchiDockItemIds.valid(appId) && !pinned && settings.pinnedIds.length < PunchiDockItemIds.maximumPins && isConfigured()
    readonly property PunchiRecentDocumentsAdapter recentDocuments: PunchiRecentDocumentsAdapter { desktopId: root.desktopId }
    readonly property PunchiFilePlacesAdapter places: PunchiFilePlacesAdapter { desktopId: root.desktopId }
    readonly property bool usesPlaces: places.count > 0
    readonly property PunchiApplicationMediaService media: PunchiApplicationMediaService { desktopId: root.desktopId }
    signal requestRejected(string appId)

    function isConfigured(): bool {
        for (let row = 0; row < entries.count; ++row) {
            const entry = entries.get(row)
            if (entry.appId === appId && entry.desktopId === desktopId) return true
        }
        return false
    }

    function select(id: string): void {
        appId = ""
        desktopId = ""
        actions = []
        canLaunchNewWindow = false
        for (let row = 0; row < entries.count; ++row) {
            const entry = entries.get(row)
            if (entry.appId !== id) continue
            appId = id
            desktopId = entry.desktopId
            actions = adapter.actions(desktopId)
            canLaunchNewWindow = adapter.canLaunchNewWindow(desktopId)
            return
        }
    }
    function showMorePlaces(): void { if (isConfigured()) places.showAll = true }
    function enterPlacesGroup(group: string): bool { return isConfigured() && places.enterGroup(group) }
    function leavePlacesGroup(): void { places.leaveGroup() }
    function openPlace(resource: string): bool {
        if (isConfigured() && adapter.openPlace(places, resource)) return true
        requestRejected(appId)
        return false
    }
    function openRecent(resource: string): bool {
        if (isConfigured() && adapter.openRecent(recentDocuments, resource)) return true
        requestRejected(appId)
        return false
    }
    function openNewWindow(): bool {
        if (isConfigured() && canLaunchNewWindow && adapter.launch(desktopId)) return true
        requestRejected(appId)
        return false
    }
    function forgetRecent(): bool { return isConfigured() && recentDocuments.forget() }
    function controlMedia(command: string): bool { return isConfigured() && media.dispatch(command) }
    function unpin(): bool {
        if (!pinned) return false
        settings.pinnedIds = settings.pinnedIds.filter(id => id !== root.appId)
        return true
    }
    function pin(): bool {
        if (!canPin) return false
        settings.pinnedIds = settings.pinnedIds.concat([root.appId])
        return true
    }
}
