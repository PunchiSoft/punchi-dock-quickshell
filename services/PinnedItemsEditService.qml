// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import "../config"

QtObject {
    id: root
    required property ShellSettings settings
    // Opening the page starts without a selection; the details pane explains
    // the available actions until the user chooses a row.
    property string selectedAppId: ""
    readonly property int selectedIndex: settings.pinnedIds.indexOf(selectedAppId)
    readonly property bool canMoveUp: selectedIndex > 0
    readonly property bool canMoveDown: selectedIndex >= 0 && selectedIndex < settings.pinnedIds.length - 1
    readonly property bool canRemove: selectedIndex >= 0

    function select(appId: string): void {
        if (settings.pinnedIds.indexOf(appId) >= 0) selectedAppId = appId
    }
    function clearSelection(): void { selectedAppId = "" }
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
        return true
    }
    onSettingsChanged: selectedAppId = ""
    readonly property Connections changes: Connections {
        target: root.settings
        // An external removal clears the selection instead of choosing a
        // neighbour the user did not ask for. A removal through this service
        // sets its follow-up selection after the model change.
        function onPinnedIdsChanged() {
            if (root.selectedAppId.length > 0 && root.selectedIndex < 0)
                root.selectedAppId = ""
        }
    }
}
