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
    readonly property bool configured: backend.enabled
    readonly property list<string> desktopIds: backend.desktopIds
    readonly property var applicationEntries: backend.applicationEntries
    readonly property var virtualDesktops: backend.virtualDesktops
    readonly property var activities: backend.activities
    readonly property var currentDesktopIds: backend.currentDesktopIds
    readonly property var currentDesktopApplications: {
        if (!backend.available) return []
        return backend.applicationEntries.filter(entry =>
            backend.currentDesktopIds.indexOf(entry.desktopId) >= 0)
    }
    readonly property var windowActivation: backend.windowActivation
    readonly property var visibilityState: backend.visibilityState
    readonly property int revision: backend.revision + (catalog ? catalog.revision : 0)
    function isRunning(appId: string): bool {
        if (!catalog || !backend.available) return false
        const application = catalog.application(appId)
        if (application.desktopId) return backend.isRunning(application.desktopId)
        const prefix = "desktop:"
        return appId.startsWith(prefix) ? backend.isRunning(appId.slice(prefix.length)) : false
    }
    function isRunningDesktop(desktopId: string): bool { return backend.isRunning(desktopId) }
    function windowActions(desktopId: string): var { return backend.windowActions(desktopId) }
}
