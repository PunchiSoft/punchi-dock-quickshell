// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import "../config"

QtObject {
    id: root
    required property ShellSettings settings
    property string selectedAppId: ""
    property int previousIndex: 0
    readonly property int selectedIndex: settings.pinnedIds.indexOf(selectedAppId)
    readonly property bool canMoveUp: selectedIndex > 0
    readonly property bool canMoveDown: selectedIndex >= 0 && selectedIndex < settings.pinnedIds.length - 1
    readonly property bool canRemove: selectedIndex >= 0

    function select(appId: string): void {
        if (settings.pinnedIds.indexOf(appId) >= 0) selectedAppId = appId
    }
    function ensureSelection(): void {
        if (!settings || selectedIndex >= 0) return
        const pins = settings.pinnedIds
        selectedAppId = pins.length > 0 ? pins[Math.min(previousIndex, pins.length - 1)] : ""
    }
    function move(direction: int): bool {
        if (direction !== -1 && direction !== 1) return false
        const from = selectedIndex
        const to = from + direction
        if (from < 0 || to < 0 || to >= settings.pinnedIds.length) return false
        const next = settings.pinnedIds.slice()
        next.splice(to, 0, next.splice(from, 1)[0])
        settings.pinnedIds = next
        return true
    }
    function removeSelected(): bool {
        const from = selectedIndex
        if (from < 0) return false
        const next = settings.pinnedIds.slice()
        const removedId = next.splice(from, 1)[0]
        if (String(removedId).indexOf("item:folder:") === 0)
            settings.removeContainer(removedId)
        settings.pinnedIds = next
        selectedAppId = next.length > 0 ? next[Math.min(from, next.length - 1)] : ""
        previousIndex = Math.max(0, Math.min(from, next.length - 1))
        return true
    }
    onSelectedIndexChanged: if (selectedIndex >= 0) previousIndex = selectedIndex
    onSettingsChanged: ensureSelection()
    Component.onCompleted: ensureSelection()
    readonly property Connections changes: Connections {
        target: root.settings
        function onPinnedIdsChanged() { root.ensureSelection() }
    }
}
