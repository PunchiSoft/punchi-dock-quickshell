// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml

QtObject {
    id: root

    property string mode: "overlay"
    property bool configuring: false
    property real baseHeight: 0
    property real bottomClearance: 0
    readonly property string effectiveMode: accepts(mode) ? mode : "overlay"
    readonly property bool belowWindows: effectiveMode === "desktop" && !configuring
    readonly property int exclusiveZone: effectiveMode === "reserve"
        ? Math.ceil(Math.max(0, baseHeight) + Math.max(0, bottomClearance)) : 0

    function accepts(candidate: string): bool {
        return candidate === "overlay" || candidate === "reserve" || candidate === "desktop"
            || candidate === "autohide" || candidate === "dodge-windows"
    }
}
