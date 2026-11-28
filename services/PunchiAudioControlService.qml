// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml

// Volume and mute of the default audio sink. The service owns the gesture rule:
// a drag captures the sink identity and refuses to write after the provider
// switched to a different sink, so a late slider value never lands on the new
// device. The provider keeps owning the amplification policy and the scale.
QtObject {
    id: root
    property var provider: null
    property bool gestureActive: false
    property string gestureNodeId: ""
    property bool gestureStale: false
    readonly property bool available: root.provider !== null
        && root.provider.available === true
    readonly property bool ready: root.available && root.provider.ready === true
    readonly property string nodeId: root.ready ? String(root.provider.nodeId || "") : ""
    readonly property string description: root.ready
        ? String(root.provider.description || "") : ""
    readonly property real volume: root.ready ? Number(root.provider.volume) : 0
    readonly property int percent: Math.round(root.volume * 100)
    readonly property bool muted: root.ready && root.provider.muted === true
    // Amplification the provider already reports. A separate surface never
    // raises the ceiling plasma-pa configured; it only mirrors a boost that is
    // already there, and keeps it stable while the pointer drags.
    property int providedCeiling: 100
    readonly property int maximumPercent: Math.max(100, root.providedCeiling)
    readonly property string iconName: root.muted ? "audio-volume-muted"
        : root.percent <= 0 ? "audio-volume-muted"
        : root.percent < 34 ? "audio-volume-low"
        : root.percent < 67 ? "audio-volume-medium" : "audio-volume-high"
    function captureCeiling(): void {
        root.providedCeiling = Math.max(100, Math.ceil(root.volume * 100))
    }
    function beginGesture(): void {
        root.gestureActive = true
        root.gestureNodeId = root.nodeId
        root.gestureStale = false
    }
    function endGesture(): void {
        root.gestureActive = false
        root.gestureStale = false
        root.captureCeiling()
    }
    function setPercent(value: real): bool {
        if (!root.ready) return false
        if (root.gestureActive && root.nodeId !== root.gestureNodeId) {
            root.gestureStale = true
            return false
        }
        const target = Math.max(0, Math.min(root.maximumPercent, Number(value)))
        return root.provider.setVolume(target / 100)
    }
    function toggleMute(): bool {
        if (!root.ready) return false
        return root.provider.setMuted(!root.provider.muted)
    }
    onVolumeChanged: if (!root.gestureActive) root.captureCeiling()
    onNodeIdChanged: if (root.gestureActive && root.nodeId !== root.gestureNodeId)
        root.gestureStale = true
    Component.onCompleted: root.captureCeiling()
}
