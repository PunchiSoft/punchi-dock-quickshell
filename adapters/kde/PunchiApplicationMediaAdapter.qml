// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import org.kde.plasma.private.mpris as Mpris

QtObject {
    id: root
    property string desktopId: ""
    property int revision: 0
    readonly property string desktopEntry: desktopId.replace(/\.desktop$/, "")
    readonly property var player: {
        const dependency = root.revision
        if (!/^[A-Za-z0-9_][A-Za-z0-9_.-]{0,254}$/.test(root.desktopEntry)) return null
        const candidate = players.playerForLauncherUrl("applications:" + root.desktopEntry + ".desktop", 0)
        // Application-level menus have no selected window PID. Never accept
        // an unrelated PID fallback or the global multiplexer.
        return candidate && candidate.desktopEntry === root.desktopEntry ? candidate : null
    }
    readonly property bool playing: player !== null && player.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property Mpris.Mpris2Model players: Mpris.Mpris2Model {}
    function refresh(): void { root.revision++ }
    readonly property Connections modelUpdates: Connections {
        target: root.players
        // The concatenating/filtering model must finish its structural update
        // before launcher lookup. Coalesce signals without copying model rows.
        function onRowsInserted(): void { Qt.callLater(root.refresh) }
        function onRowsRemoved(): void { Qt.callLater(root.refresh) }
        function onModelReset(): void { Qt.callLater(root.refresh) }
        function onLayoutChanged(): void { Qt.callLater(root.refresh) }
        function onDataChanged(): void { Qt.callLater(root.refresh) }
    }
}
