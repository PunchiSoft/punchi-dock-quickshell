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
    // Per-desktop minimized window counts, and the transition that the dock
    // reacts to. The first snapshot arms the tracker without playing anything;
    // only a later increase in a count means a window just minimized.
    property var minimizedCounts: ({})
    property var observedMinimizedCounts: ({})
    property bool minimizeTrackingReady: false
    signal applicationMinimized(string desktopId)
    function refreshMinimizeCounts(): void {
        if (!backend.available) {
            root.minimizedCounts = ({})
            root.observedMinimizedCounts = ({})
            root.minimizeTrackingReady = false
            return
        }
        const counts = ({})
        const entries = backend.applicationEntries
        for (let index = 0; index < entries.length; ++index) {
            const entry = entries[index]
            const id = String(entry.desktopId || "")
            if (id.length === 0) continue
            const value = Number(entry.minimizedCount || 0)
            counts[id] = Math.max(0, Math.min(4096, Number.isFinite(value) ? value : 0))
        }
        if (root.minimizeTrackingReady) {
            for (const id in counts)
                if (counts[id] > (root.observedMinimizedCounts[id] || 0))
                    root.applicationMinimized(id)
        }
        root.minimizedCounts = counts
        root.observedMinimizedCounts = counts
        root.minimizeTrackingReady = true
    }
    Component.onCompleted: root.refreshMinimizeCounts()
    readonly property Connections backendChanges: Connections {
        target: root.backend
        function onChanged() { root.refreshMinimizeCounts() }
    }
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
