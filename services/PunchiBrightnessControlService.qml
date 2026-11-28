// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml

// Brightness of the first controllable display reported by PowerDevil. The
// internal panel wins; an external display is accepted only when the provider
// reports a real range for it. A gesture captures the display identity and
// refuses a late value after the selection changed.
QtObject {
    id: root
    property var provider: null
    property bool gestureActive: false
    property string gestureDisplayId: ""
    readonly property bool available: root.provider !== null
        && root.provider.available === true
    readonly property var displays: root.provider !== null
        ? root.provider.displays : []
    readonly property var display: {
        const list = root.displays || []
        for (const entry of list)
            if (entry && entry.internal === true && Number(entry.maximum) > 0) return entry
        for (const entry of list)
            if (entry && Number(entry.maximum) > 0) return entry
        return null
    }
    readonly property bool hasControl: root.available && root.display !== null
    readonly property string label: root.display
        ? String(root.display.label || "") : ""
    readonly property int percent: root.display ? Number(root.display.percent) : 0
    readonly property bool pending: root.provider !== null
        && root.provider.pending === true
    readonly property string statusText: !root.available ? qsTr("Unavailable")
        : !root.hasControl ? qsTr("No controllable display") : root.label
    function beginGesture(): void {
        root.gestureActive = true
        root.gestureDisplayId = root.display ? String(root.display.id) : ""
    }
    function endGesture(): void {
        root.gestureActive = false
        root.gestureDisplayId = ""
    }
    function setPercent(value: real): bool {
        if (!root.hasControl) return false
        const id = String(root.display.id)
        if (root.gestureActive && id !== root.gestureDisplayId) return false
        return root.provider.setPercent(id, Math.round(Math.max(0, Math.min(100, value))))
    }
}
