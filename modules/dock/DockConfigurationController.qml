// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml

QtObject {
    id: root
    required property var hostWindow
    property bool active: false
    property bool previousVisibility: true
    onActiveChanged: {
        if (!hostWindow) return
        if (active) {
            previousVisibility = hostWindow.visible
            hostWindow.visible = true
        } else hostWindow.visible = previousVisibility
    }
}
