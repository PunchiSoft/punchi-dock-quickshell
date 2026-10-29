// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import Punchi.Kde as Native

QtObject {
    id: root
    required property var settings
    required property var catalog
    property var runningDesktopIds: []
    readonly property Native.RecentApplicationsAdapter history: Native.RecentApplicationsAdapter {
        enabled: root.settings.recentApplicationsEnabled
    }
    readonly property Native.RecentApplicationsModel selection: Native.RecentApplicationsModel {
        enabled: root.settings.recentApplicationsEnabled
        sourceModel: root.history
        maximumItems: root.settings.recentApplicationsCount
        excludedStorageIds: root.excludedStorageIds
    }
    readonly property var excludedStorageIds: {
        // The catalogue fills itself asynchronously, and a preset row resolves
        // its desktop id only then. Reading the revision re-evaluates the
        // exclusion list, so a pinned application never reaches the container
        // or the inline rows once KDE reports it.
        const revision = root.catalog ? root.catalog.revision : 0
        const excluded = []
        for (const appId of root.settings.pinnedIds || []) {
            const row = root.catalog ? root.catalog.application(appId) : null
            if (row && row.desktopId) excluded.push(row.desktopId)
        }
        for (const desktopId of root.runningDesktopIds || []) excluded.push(desktopId)
        return excluded
    }
    readonly property bool available: history.available
    readonly property bool trackingEnabled: history.trackingEnabled
    // Recording is about KDE, not about showing the list: a hidden list can
    // still keep the history complete for when it is shown again.
    readonly property bool recordingEnabled: available && trackingEnabled
    readonly property int count: selection.count
    readonly property var items: selection.items
    function setTrackingEnabled(enabled: bool): bool {
        return history.setTrackingEnabled(enabled)
    }
    function openTrackingSettings(): bool {
        return history.openTrackingSettings()
    }
    function recordAccess(appId: string): void {
        if (!root.recordingEnabled || !root.catalog) return
        const row = root.catalog.application(appId)
        if (row && row.desktopId) root.history.recordAccess(row.desktopId)
    }
}
