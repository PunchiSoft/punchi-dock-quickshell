// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import QtQml.Models
ListModel {
    id: root
    required property var catalog
    required property var pinnedIds
    function rebuild(): void {
        const next = []
        for (const id of pinnedIds || []) {
            for (let index = 0; catalog && index < catalog.count; ++index) {
                const row = catalog.get(index)
                if (row.appId === id) {
                    next.push({appId: row.appId, desktopId: row.desktopId,
                        title: row.title, iconName: row.iconName})
                    break
                }
            }
        }
        for (let row = count - 1; row >= 0; --row)
            if (!next.some(item => item.appId === get(row).appId)) remove(row)
        for (let row = 0; row < next.length; ++row) {
            let current = row
            while (current < count && get(current).appId !== next[row].appId) ++current
            if (current === count) insert(row, next[row])
            else {
                if (current !== row) move(current, row, 1)
                const previous = get(row)
                if (previous.desktopId !== next[row].desktopId || previous.title !== next[row].title
                    || previous.iconName !== next[row].iconName) set(row, next[row])
            }
        }
    }
    readonly property Connections catalogChanges: Connections {
        target: root.catalog
        function onModelReset() { root.rebuild() }
        function onRowsInserted() { root.rebuild() }
        function onRowsRemoved() { root.rebuild() }
        function onDataChanged() { root.rebuild() }
    }
    onCatalogChanged: rebuild()
    onPinnedIdsChanged: rebuild()
    Component.onCompleted: rebuild()
}
