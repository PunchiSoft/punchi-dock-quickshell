// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import Quickshell
import Punchi.Kde as Native

QtObject {
    id: root
    required property var catalog
    readonly property Native.RunningApplications backend: Native.RunningApplications {
        executable: Quickshell.env("PUNCHI_WINDOW_BACKEND") || ""
        enabled: executable.length > 0
    }
    readonly property bool available: backend.available
    readonly property int revision: backend.revision + (catalog ? catalog.revision : 0)
    function isRunning(appId: string): bool {
        if (!catalog || !backend.available) return false
        return backend.isRunning(catalog.application(appId).desktopId || "")
    }
}
