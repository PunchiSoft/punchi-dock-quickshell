// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import "../../config/PanelModes.js" as PanelModes

QtObject {
    id: root

    property string mode: "overlay"
    property real baseHeight: 0
    property real bottomClearance: 0
    readonly property string effectiveMode: PanelModes.effective(mode)
    readonly property int exclusiveZone: effectiveMode === "reserve"
        ? Math.ceil(Math.max(0, baseHeight) + Math.max(0, bottomClearance)) : 0

    function accepts(candidate: string): bool {
        return PanelModes.accepts(candidate)
    }
}
