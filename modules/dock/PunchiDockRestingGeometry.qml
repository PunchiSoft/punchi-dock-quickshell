// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml

QtObject {
    property string dockEdge: "bottom"
    property real screenX: 0
    property real screenY: 0
    property real screenWidth: 0
    property real screenHeight: 0
    property real bodyWidth: 0
    property real bodyHeight: 0
    property real bottomClearance: 0
    property real edgeMargin: 0
    // Logical screen coordinates, independent of slide progress/menu allocation.
    readonly property rect region: Qt.rect(
        dockEdge === "left" ? screenX + edgeMargin + bottomClearance
            : dockEdge === "right" ? screenX + screenWidth - bodyWidth - edgeMargin - bottomClearance
            : screenX + (screenWidth - bodyWidth) / 2,
        dockEdge === "bottom" ? screenY + screenHeight - bodyHeight - bottomClearance - edgeMargin
            : screenY + (screenHeight - bodyHeight) / 2,
        Math.max(0, bodyWidth), Math.max(0, bodyHeight))
}
