// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQml
import Quickshell.Services.Pipewire

// Default audio sink of the running PipeWire session. Quickshell already owns
// the PipeWire client, default-sink metadata and the node audio interface, so
// this adapter only names the contract the audio control consumes.
QtObject {
    id: root
    property bool active: false
    // Bind the node's audio interface before anyone reads it.
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property PwObjectTracker tracker: PwObjectTracker {
        objects: root.active && root.sink ? [root.sink] : []
    }
    readonly property bool available: root.active && Pipewire.ready
    readonly property bool ready: root.available && root.sink !== null
        && root.sink.ready && root.sink.audio !== null
    readonly property string nodeId: root.ready ? String(root.sink.id) : ""
    readonly property string description: root.ready
        ? String(root.sink.description || root.sink.nickname || root.sink.name || "") : ""
    readonly property real volume: root.ready ? Number(root.sink.audio.volume) : 0
    readonly property bool muted: root.ready ? root.sink.audio.muted === true : false
    signal changed()

    function setVolume(value: real): bool {
        if (!root.ready) return false
        root.sink.audio.volume = Math.max(0, Number(value))
        return true
    }
    function setMuted(muted: bool): bool {
        if (!root.ready) return false
        root.sink.audio.muted = muted
        return true
    }
    readonly property Connections pipewireChanges: Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() { root.changed() }
        function onReadyChanged() { root.changed() }
    }
    readonly property Connections sinkChanges: Connections {
        target: root.ready ? root.sink.audio : null
        function onVolumesChanged() { root.changed() }
        function onMutedChanged() { root.changed() }
    }
    onSinkChanged: root.changed()
}
