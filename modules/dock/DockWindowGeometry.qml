// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml

QtObject {
    id: root
    property real baseHeight: 0
    property real screenHeight: 0
    property real bottomMargin: 0
    property real edgeHeight: 1
    property bool surfaceVisible: true
    // A stable transparent client area avoids Wayland configure/input resets
    // when a same-window menu opens, changes content, or closes.
    readonly property int revealedHeight: Math.ceil(Math.max(1,
        nonNegative(baseHeight), nonNegative(screenHeight) - nonNegative(bottomMargin)))
    readonly property int windowHeight: surfaceVisible ? revealedHeight
        : Math.ceil(Math.max(1, nonNegative(edgeHeight)))
    function nonNegative(value: real): real {
        return Number.isFinite(value) ? Math.max(0, value) : 0
    }
}
