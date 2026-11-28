// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQml
import Quickshell.Services.Mpris

// MPRIS players visible to the session through Quickshell's public service.
// Unlike the dock's app-scoped adapter, the top panel needs the session-wide
// list: the service picks one player and only announces its own capabilities.
QtObject {
    id: root
    property bool active: false
    readonly property var players: {
        const model = Mpris.players
        return root.active && model && model.values ? model.values : []
    }
    readonly property int count: root.players.length
}
