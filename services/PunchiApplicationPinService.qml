// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import "../adapters/kde"
import "../config/PunchiDockItemIds.js" as PunchiDockItemIds

QtObject {
    id: root
    required property var settings
    required property var catalog
    property string query: ""
    property string selectedAppId: ""
    // Icon chosen in the picker before the item is pinned. It becomes the
    // per-item override when the user accepts, so a discarded edit leaves the
    // dock untouched.
    property string pendingIconName: ""
    readonly property PunchiApplicationSearchAdapter applications: PunchiApplicationSearchAdapter {
        sourceModel: root.catalog
        query: root.query
    }
    readonly property var selectedApplication: {
        if (!catalog || selectedAppId.length === 0) return null
        catalog.revision
        const app = catalog.application(selectedAppId)
        return app.installed ? app : null
    }
    readonly property string selectedIconName: {
        if (!root.settings) return ""
        root.settings.iconOverrides
        if (root.pendingIconName.length > 0) return root.pendingIconName
        if (selectedAppId.length > 0 && root.settings.iconOverride(selectedAppId).length > 0)
            return root.settings.iconOverride(selectedAppId)
        return root.selectedApplication ? String(root.selectedApplication.appIconName) : ""
    }
    readonly property bool canAdd: selectedApplication !== null
        && PunchiDockItemIds.valid(selectedAppId) && settings.pinnedIds.indexOf(selectedAppId) < 0
        && settings.pinnedIds.length < PunchiDockItemIds.maximumPins
    function begin(): void { cancel() }
    function cancel(): void { query = ""; selectedAppId = ""; pendingIconName = "" }
    function search(text: string): void { selectedAppId = ""; pendingIconName = ""; query = text.slice(0, 256) }
    function select(appId: string): void { selectedAppId = appId }
    function chooseIcon(iconName: string): void {
        if (!PunchiDockItemIds.validIconName(iconName)) return
        pendingIconName = iconName
    }
    function accept(): bool {
        if (!canAdd) return false
        const pins = settings.pinnedIds.slice()
        const trashIndex = pins.indexOf("item:trash")
        if (trashIndex === pins.length - 1) pins.splice(trashIndex, 0, selectedAppId)
        else pins.push(selectedAppId)
        if (pendingIconName.length > 0) settings.setIconOverride(selectedAppId, pendingIconName)
        settings.pinnedIds = pins
        cancel()
        return true
    }
    // Generic pin/unpin used by the fullscreen menu context menu. The Add flow
    // above keeps its own catalog-backed canAdd so an unavailable entry never
    // reaches the profile.
    function isPinned(appId: string): bool {
        return !!settings && typeof appId === "string" && appId.length > 0
            && settings.pinnedIds.indexOf(appId) >= 0
    }
    function canPinApp(appId: string): bool {
        return !!settings && typeof appId === "string" && appId.length > 0
            && appId.indexOf("item:") !== 0 && PunchiDockItemIds.valid(appId)
            && !isPinned(appId) && settings.pinnedIds.length < PunchiDockItemIds.maximumPins
    }
    function pinApp(appId: string): bool {
        if (!canPinApp(appId)) return false
        const pins = settings.pinnedIds.slice()
        const trashIndex = pins.indexOf("item:trash")
        if (trashIndex === pins.length - 1) pins.splice(trashIndex, 0, appId)
        else pins.push(appId)
        settings.pinnedIds = pins
        return true
    }
    function unpinApp(appId: string): bool {
        if (!isPinned(appId)) return false
        settings.pinnedIds = settings.pinnedIds.filter(id => id !== appId)
        return true
    }
}
