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
        const excluded = []
        for (const appId of root.settings.pinnedIds || []) {
            const row = root.catalog ? root.catalog.application(appId) : null
            if (row && row.desktopId) excluded.push(row.desktopId)
        }
        for (const desktopId of root.runningDesktopIds || []) excluded.push(desktopId)
        return excluded
    }
    readonly property bool available: history.available
    readonly property int count: selection.count
    readonly property var items: selection.items
    function recordAccess(appId: string): void {
        if (!root.available || !root.catalog) return
        const row = root.catalog.application(appId)
        if (row && row.desktopId) root.history.recordAccess(row.desktopId)
    }
}
