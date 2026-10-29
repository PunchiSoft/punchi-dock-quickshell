// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml

QtObject {
    property var source: null
    property rect region: Qt.rect(0, 0, 0, 0)
    readonly property bool available: source !== null && source.available
    readonly property bool showingDesktop: available && source.showingDesktop
    readonly property bool overlapping: {
        if (!available || showingDesktop) return false
        const revision = source.revision
        return source.overlaps(region)
    }
}
