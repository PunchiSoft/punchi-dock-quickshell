// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import "../adapters/kde"

QtObject {
    id: root
    property string desktopId: ""
    property var adapter: ApplicationMediaAdapter { desktopId: root.desktopId }
    readonly property var player: adapter.player
    readonly property bool available: player !== null
    readonly property bool playing: available && adapter.playing
    readonly property bool canPrevious: available && player.canGoPrevious
    readonly property bool canNext: available && player.canGoNext
    readonly property bool canPlayPause: available && (playing ? player.canPause : player.canPlay)
    readonly property bool canStop: available && player.canStop
    readonly property string title: available ? player.track : ""
    readonly property string artist: available ? player.artist : ""
    readonly property string album: available ? player.album : ""
    readonly property string artUrl: available ? player.artUrl : ""

    function dispatch(command: string): bool {
        // Resolve capabilities and the current player at dispatch, including
        // departure or a target change while the menu was open.
        const current = root.player
        if (!current) return false
        if (command === "previous" && root.canPrevious) current.Previous()
        else if (command === "next" && root.canNext) current.Next()
        else if (command === "play-pause" && root.canPlayPause) current.PlayPause()
        else if (command === "stop" && root.canStop) current.Stop()
        else return false
        return true
    }
}
