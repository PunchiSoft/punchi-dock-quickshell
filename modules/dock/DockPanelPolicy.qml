// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import "../../config/PanelModes.js" as PanelModes

QtObject {
    id: root

    property string mode: "overlay"
    // An internal edge between monitors has no free strip to reveal from, so an
    // edge mode leaves the dock visible instead of hiding it unreachably.
    property bool edgeTriggerAvailable: true
    property real baseHeight: 0
    property real bottomClearance: 0
    readonly property string requestedMode: PanelModes.effective(mode)
    readonly property string effectiveMode: edgeTriggerAvailable ? requestedMode
        : (requestedMode === "autohide" || requestedMode === "dodge-windows" ? "overlay" : requestedMode)
    readonly property int exclusiveZone: effectiveMode === "reserve"
        ? Math.ceil(Math.max(0, baseHeight) + Math.max(0, bottomClearance)) : 0

    function accepts(candidate: string): bool {
        return PanelModes.accepts(candidate)
    }
}
