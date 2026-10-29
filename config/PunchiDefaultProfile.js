// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Canonical first-run profile. The dock reads this module when no stored
// profile exists, `Reset defaults` restores it, and the profile exchange
// exports the same document shape as data (never as executable JavaScript).
// Keep the keys aligned with PunchiShellSettings.snapshot().

const limits = {
    sizePercent: {minimum: 50, maximum: 150},
    maximumIconScale: {minimum: 1, maximum: 3},
    popupScale: {minimum: 0.8, maximum: 1.3},
    popupIconSize: {minimum: 24, maximum: 96},
    popupListIconSize: {minimum: 24, maximum: 64},
    popupFanIconSize: {minimum: 24, maximum: 56},
    popupHeightPercent: {minimum: 40, maximum: 90},
    recentApplicationsCount: {minimum: 1, maximum: 20},
    // The menu keeps the original floor of 0.50, so the desktop never shows
    // through enough to make the grid unreadable.
    menuBackgroundOpacity: {minimum: 0.50, maximum: 1.0},
    menuIconScale: {minimum: 0.75, maximum: 1.5}
}

// `desktopId` names the desktop entry an item launches. An empty one plus
// `defaultMimeTypes` names a role instead: the catalogue asks KDE which
// application this session prefers for those types, in this order, so a first
// run never pins a browser the distribution did not choose. The types are one
// space-separated string because a ListModel element stores an array as a
// nested model.
const launchers = [
    {appId: "files", desktopId: "org.kde.dolphin", title: qsTr("Files"), iconName: "system-file-manager"},
    {appId: "terminal", desktopId: "org.kde.konsole", title: qsTr("Terminal"), iconName: "utilities-terminal"},
    {appId: "browser", desktopId: "", title: qsTr("Browser"), iconName: "internet-web-browser",
        defaultMimeTypes: "x-scheme-handler/https x-scheme-handler/http text/html"},
    {appId: "kate", desktopId: "org.kde.kate", title: qsTr("Kate"), iconName: "kate"},
    {appId: "systemsettings", desktopId: "systemsettings", title: qsTr("System Settings"), iconName: "preferences-system"},
    {appId: "discover", desktopId: "org.kde.discover", title: qsTr("Discover"), iconName: "plasmadiscover"},
    {appId: "gwenview", desktopId: "org.kde.gwenview", title: qsTr("Gwenview"), iconName: "gwenview"},
    {appId: "okular", desktopId: "org.kde.okular", title: qsTr("Okular"), iconName: "okular"}
]

const profile = {
    version: 14,
    downloadsView: "grid",
    dockEdge: "bottom",
    panelMode: "overlay",
    // One shared profile serves every screen. `selectedScreens` holds screen
    // connector names; the system primary is the fallback when none of them is
    // connected.
    screenMode: "all",
    selectedScreens: [],
    // Virtual desktops and KDE activities use their KWin identifiers, stored as
    // strings so a numeric desktop id round-trips.
    desktopMode: "all",
    selectedDesktops: [],
    activityMode: "all",
    selectedActivities: [],
    runningMarkersFollowDesktop: false,
    avoidInnerEdgeAutoHide: true,
    sizePercent: 100,
    magnificationEnabled: true,
    reducedMotion: false,
    bounceEnabled: true,
    maximumIconScale: 2.0,
    pinnedIds: ["files", "terminal", "item:folder:home", "browser", "kate",
        "systemsettings", "discover", "gwenview", "okular", "item:downloads",
        "item:trash"],
    iconOverrides: {},
    recentApplicationsEnabled: true,
    recentApplicationsCount: 5,
    // The applications open as one container item by default; the stored view
    // is a folder container view.
    recentApplicationsPresentation: "container",
    recentApplicationsContainerLayout: "list",
    updateBadgeEnabled: true,
    popupScale: 1.0,
    popupIconSize: 0,
    popupListIconSize: 0,
    popupFanIconSize: 0,
    popupHeightPercent: 80,
    // Fullscreen menu presentation. The backdrop keeps the original floor of
    // 0.50 opacity, the distribution title and the page arrows are optional,
    // and the close button keeps the original corner choice.
    menuBackgroundOpacity: 0.6,
    menuBackgroundBlurEnabled: true,
    menuShowDistributionName: true,
    menuShowPageArrows: true,
    menuShowLabels: true,
    menuIconScale: 1.0,
    menuCloseButtonPosition: "right",
    // The original menu offered four hover behaviours; the pointer
    // animation is the same on every cell so the surface stays calm.
    menuHoverAnimation: "pulse",
    containers: [
        {id: "downloads", path: "", title: qsTr("Downloads"), icon: "folder-downloads",
            layout: "grid", sortMode: "modified", browseSubfolders: true, hiddenEntries: []},
        // Home lists the standard user folders as places to go, so the first-run
        // profile opens a selected folder in the file manager instead of
        // replacing the listing with its contents.
        {id: "home", path: "", title: qsTr("Home"), icon: "user-home", layout: "fan",
            sortMode: "name", browseSubfolders: false, hiddenEntries: []}
    ]
}

// A fresh copy keeps a caller from changing the module for the next one.
function fresh() {
    return JSON.parse(JSON.stringify(profile))
}
