// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import Punchi.Kde as Native

// Decides which launcher receives the update count. The native backend only
// reports read-only counts from PackageKit, fwupd and Flatpak; this service owns
// the presentation policy, so views stay free of desktop queries.
QtObject {
    id: root
    required property var settings
    property var catalog: null
    property var backend: Native.UpdateState {}

    // Update front-ends a KDE user may pin, in preference order. The dock does
    // not guess a distribution: PackageKit, fwupd and Flatpak report the same
    // data everywhere, and the badge follows whichever front-end is really
    // configured. PackageKit already reports its own backend (dnf5, apt, alpm,
    // zypper...), so no distribution detection is needed here.
    readonly property var updaterDesktopIds: [
        "org.kde.discover",
        "org.gnome.Software",
        "io.elementary.appcenter",
        "update-manager",
    ]
    readonly property int count: backend.count
    readonly property int securityCount: backend.securityCount
    readonly property int revision: backend.revision + (catalog && catalog.revision !== undefined
        ? catalog.revision : 0)
    readonly property bool enabled: settings !== null && settings.updateBadgeEnabled
    readonly property bool available: backend.state !== Native.UpdateState.Unavailable
    readonly property string backendName: typeof backend.backendName === "string"
        ? backend.backendName : ""
    // Which sources answered the last check, in display order. Each one is
    // optional, so the UI can name exactly what the count covers instead of
    // promising all three.
    readonly property var availableSources: {
        backend.revision
        const sources = []
        if (backend.systemAvailable === true) sources.push("system")
        if (backend.flatpakAvailable === true) sources.push("flatpak")
        if (backend.firmwareAvailable === true) sources.push("firmware")
        return sources
    }

    // Resolved once per revision: the pinned launcher of the first updater found
    // in the catalog. An unpinned updater, or a dock without any of them, simply
    // shows no badge.
    readonly property string targetAppId: {
        root.revision
        if (!catalog || catalog.count === undefined) return ""
        for (const candidate of root.updaterDesktopIds) {
            for (let index = 0; index < catalog.count; ++index) {
                const row = catalog.get(index)
                if (row && root.normalizedDesktopId(row.desktopId) === candidate) return row.appId
            }
        }
        return ""
    }

    function refresh(): void { backend.refresh() }

    // KDE reports storage ids with the `.desktop` suffix, so compare without it.
    function normalizedDesktopId(desktopId: string): string {
        if (typeof desktopId !== "string") return ""
        return desktopId.endsWith(".desktop") ? desktopId.slice(0, -8) : desktopId
    }

    function targets(appId: string): bool {
        return targetAppId.length > 0 && appId === targetAppId
    }

    function badgeCount(appId: string): int {
        if (!enabled || count <= 0 || !targets(appId)) return 0
        return count
    }

    function badgeSecurityCount(appId: string): int {
        if (!enabled || count <= 0 || !targets(appId)) return 0
        return securityCount
    }
}
