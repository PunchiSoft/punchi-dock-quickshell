// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQml
import Quickshell
import Punchi.Kde as Native
import "../../config"
import "../../adapters/kde"
import "../../config/PunchiRecentPresentation.js" as PunchiRecentPresentation
import "../../services"

// Data and coordination shared by every dock window. One instance serves all
// screens, so the window backend, the desktop-entry catalog and the update
// tracker are never duplicated per monitor.
Scope {
    id: root
    required property PunchiShellSettings settings

    readonly property alias catalog: availableApps
    readonly property alias applicationCatalog: itemCatalog
    readonly property alias trashState: trashState
    readonly property alias runningApplications: runningApps
    readonly property alias updateNotice: updateNotice
    readonly property alias recentApplications: recentApplications
    readonly property alias dockItems: dockItems
    readonly property alias minimizeEffects: minimizeEffects
    readonly property alias clipboard: clipboard
    readonly property alias distribution: distributionInfo

    PunchiApplicationCatalog { id: availableApps }
    Native.DockItemCatalog {
        id: itemCatalog
        applications: availableApps
        containers: root.settings.containers
        downloadsTitle: qsTr("Downloads")
        trashTitle: qsTr("Trash")
        trashIconName: root.trashState.hasItems ? "user-trash-full" : "user-trash"
    }
    Native.TrashState { id: trashState }
    PunchiRunningApplications { id: runningApps; catalog: availableApps }
    PunchiUpdateNotice { id: updateNotice; settings: root.settings; catalog: availableApps }
    PunchiPinnedApplications {
        id: fixtureModel
        catalog: itemCatalog
        pinnedIds: root.settings.pinnedIds
        iconOverrides: root.settings.iconOverrides
    }
    PunchiRecentApplications {
        id: recentApplications
        settings: root.settings
        catalog: itemCatalog
        runningDesktopIds: runningApps.desktopIds
    }
    Native.DockApplicationsModel {
        id: dockItems
        // The menu leads the dock. Its title is the only state it needs, and the
        // dock window turns a click on it into the open intent.
        leadingTitle: qsTr("Menu")
        leadingIcon: "start-here-kde"
        pinned: fixtureModel
        catalog: itemCatalog
        recent: recentApplications.selection
        // The history joins the row as one container item, or as the resolved
        // rows themselves; the selection model feeds the container popup.
        recentContainer: root.settings.recentApplicationsPresentation === "container"
        recentContainerTitle: qsTr("Recent applications")
        recentContainerIcon: PunchiRecentPresentation.containerIcon
        // The optional filter keeps pinned items visible while running markers
        // and transient rows follow the active desktop and activity.
        runningDesktopIds: runningApps.available
            ? (root.settings.runningMarkersFollowDesktop ? runningApps.currentDesktopIds : runningApps.desktopIds)
            : []
        runningApplications: runningApps.available
            ? (root.settings.runningMarkersFollowDesktop
                ? runningApps.currentDesktopApplications : runningApps.applicationEntries)
            : []
    }
    Native.KWinMinimizeEffectController { id: minimizeEffects }
    PunchiClipboardService { id: clipboard }
    PunchiDistributionInfo { id: distributionInfo }
}
