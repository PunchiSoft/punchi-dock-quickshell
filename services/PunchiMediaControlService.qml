// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml

// One session-wide MPRIS player for the top panel. A playing player wins; when
// none is playing the first controllable player is shown so it can be started.
// The service re-resolves the player and its capabilities at every command and
// never fabricates an action the player did not announce.
QtObject {
    id: root
    property var provider: null
    readonly property var players: root.provider !== null
        ? root.provider.players : []
    readonly property var player: {
        const list = root.players || []
        for (const entry of list)
            if (entry && entry.isPlaying === true) return entry
        for (const entry of list)
            if (entry && entry.canControl !== false) return entry
        return list.length > 0 ? list[0] : null
    }
    readonly property bool available: root.player !== null
    readonly property bool playing: root.available && root.player.isPlaying === true
    readonly property string title: root.available
        ? String(root.player.trackTitle || root.player.identity || "") : ""
    readonly property string artist: root.available
        ? String(root.player.trackArtist || "") : ""
    readonly property string playerName: root.available
        ? String(root.player.identity || "") : ""
    readonly property string statusText: root.artist.length > 0
        ? root.artist : root.playerName
    readonly property bool canPrevious: root.available
        && root.player.canGoPrevious === true
    readonly property bool canNext: root.available
        && root.player.canGoNext === true
    readonly property bool canPlayPause: root.available
        && (root.playing ? root.player.canPause === true : root.player.canPlay === true)
    function dispatch(command: string): bool {
        const current = root.player
        if (!current) return false
        if (command === "previous") {
            if (current.canGoPrevious !== true) return false
            current.previous()
        } else if (command === "next") {
            if (current.canGoNext !== true) return false
            current.next()
        } else if (command === "play-pause") {
            const allowed = current.isPlaying === true
                ? current.canPause === true : current.canPlay === true
            if (!allowed) return false
            current.togglePlaying()
        } else {
            return false
        }
        return true
    }
}
