// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml

// Virtual desktop and KDE activity visibility. Everything stays visible when
// the window backend cannot answer, and an unknown current target keeps the
// dock visible instead of making it disappear at startup.
QtObject {
    id: root
    required property var settings
    required property var runningApplications

    readonly property bool available: runningApplications !== null
        && runningApplications !== undefined && runningApplications.available === true
    readonly property string currentDesktopId: {
        if (!root.available) return ""
        for (const desktop of root.runningApplications.virtualDesktops || [])
            if (desktop && desktop.current === true) return String(desktop.id)
        return ""
    }
    readonly property string currentActivityId: {
        if (!root.available) return ""
        for (const activity of root.runningApplications.activities || [])
            if (activity && activity.current === true) return String(activity.id)
        return ""
    }
    readonly property bool desktopAllowed: {
        if (!root.available || root.settings.desktopMode !== "selected") return true
        if (root.currentDesktopId.length === 0) return true
        return (root.settings.selectedDesktops || []).indexOf(root.currentDesktopId) >= 0
    }
    readonly property bool activityAllowed: {
        if (!root.available || root.settings.activityMode !== "selected") return true
        if (root.currentActivityId.length === 0) return true
        return (root.settings.selectedActivities || []).indexOf(root.currentActivityId) >= 0
    }
    readonly property bool allowed: desktopAllowed && activityAllowed
}
