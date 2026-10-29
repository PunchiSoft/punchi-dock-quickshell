// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import "../config/PunchiScreenSelection.js" as PunchiScreenSelection

// Screen selection and hot-plug policy. A dock window exists for every
// connected screen; this object decides which of them are allowed to show.
// The host injects the connected screens and the system primary screen, so the
// policy stays free of a compositor dependency and can be exercised offscreen.
QtObject {
    id: root
    required property var settings
    property var connectedScreens: []
    property string primaryScreenName: ""

    readonly property var activeScreens: PunchiScreenSelection.resolveScreens(
        connectedScreens, settings.screenMode, settings.selectedScreens, primaryScreenName)
    function allows(screen): bool {
        return PunchiScreenSelection.allows(screen, connectedScreens, settings.screenMode,
            settings.selectedScreens, primaryScreenName)
    }
    function isSharedEdge(screen, edge): bool {
        return PunchiScreenSelection.edgeIsShared(screen, connectedScreens, edge)
    }
}
