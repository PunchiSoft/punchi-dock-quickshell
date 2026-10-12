// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml

QtObject {
    property real screenX: 0
    property real screenY: 0
    property real screenWidth: 0
    property real screenHeight: 0
    property real bodyWidth: 0
    property real bodyHeight: 0
    property real bottomClearance: 0
    property real edgeMargin: 0
    // Logical screen coordinates, independent of slide progress/menu allocation.
    readonly property rect region: Qt.rect(screenX + (screenWidth - bodyWidth) / 2,
        screenY + screenHeight - bodyHeight - bottomClearance - edgeMargin,
        Math.max(0, bodyWidth), Math.max(0, bodyHeight))
}
