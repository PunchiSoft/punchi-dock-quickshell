// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import Quickshell
import Punchi.Kde as Native

QtObject {
    id: root
    property alias activationItem: nativeLauncher.activationItem
    signal launchFinished(string desktopId, bool success, string error)
    readonly property Native.DesktopLauncher nativeLauncher: Native.DesktopLauncher {
        id: nativeLauncher
        onLaunchFinished: function(desktopId, success, error) {
            root.launchFinished(desktopId, success, error)
        }
    }
    // Initialize the asynchronous index before the first user activation.
    readonly property int applicationCount: DesktopEntries.applications.values.length

    function launch(desktopId: string): bool {
        // Exact IDs from the configured model; never evaluate a raw Exec string.
        // KDE owns Exec expansion, terminal handling and startup notification.
        return nativeLauncher.launch(desktopId)
    }
    function actions(desktopId: string): list<var> { return nativeLauncher.actions(desktopId) }
    function launchAction(desktopId: string, actionId: string): bool {
        return nativeLauncher.launchAction(desktopId, actionId)
    }
    function canLaunchNewWindow(desktopId: string): bool { return nativeLauncher.canLaunchNewWindow(desktopId) }
    function openDownloads(): bool { return nativeLauncher.openDownloads() }
    function openFolderLocation(location: url): bool { return nativeLauncher.openFolderLocation(location) }
    function openFolderPath(path: string): bool { return nativeLauncher.openFolderPath(path) }
    function openFolderUrl(contents: var, location: url): bool {
        return nativeLauncher.openFolderUrl(contents, location)
    }
    function openPlace(places: var, resource: string): bool {
        return nativeLauncher.openPlace(places, resource)
    }
    function openRecent(documents: var, resource: string): bool {
        return nativeLauncher.openRecent(documents, resource)
    }
}
