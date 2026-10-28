// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Canonical first-run profile. The dock reads this module when no stored
// profile exists, `Reset defaults` restores it, and the profile exchange
// exports the same document shape as data (never as executable JavaScript).
// Keep the keys aligned with ShellSettings.snapshot().

const limits = {
    sizePercent: {minimum: 50, maximum: 150},
    maximumIconScale: {minimum: 1, maximum: 3},
    popupScale: {minimum: 0.8, maximum: 1.3},
    popupIconSize: {minimum: 24, maximum: 96},
    popupListIconSize: {minimum: 24, maximum: 64},
    popupFanIconSize: {minimum: 24, maximum: 56},
    popupHeightPercent: {minimum: 40, maximum: 90},
    recentApplicationsCount: {minimum: 1, maximum: 20}
}

const launchers = [
    {appId: "files", desktopId: "org.kde.dolphin", title: qsTr("Files"), iconName: "system-file-manager"},
    {appId: "terminal", desktopId: "org.kde.konsole", title: qsTr("Terminal"), iconName: "utilities-terminal"},
    {appId: "browser", desktopId: "org.mozilla.firefox", title: qsTr("Browser"), iconName: "internet-web-browser"},
    {appId: "kate", desktopId: "org.kde.kate", title: qsTr("Kate"), iconName: "kate"},
    {appId: "systemsettings", desktopId: "systemsettings", title: qsTr("System Settings"), iconName: "preferences-system"},
    {appId: "discover", desktopId: "org.kde.discover", title: qsTr("Discover"), iconName: "plasmadiscover"},
    {appId: "gwenview", desktopId: "org.kde.gwenview", title: qsTr("Gwenview"), iconName: "gwenview"},
    {appId: "okular", desktopId: "org.kde.okular", title: qsTr("Okular"), iconName: "okular"}
]

const profile = {
    version: 12,
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
    updateBadgeEnabled: true,
    popupScale: 1.0,
    popupIconSize: 0,
    popupListIconSize: 0,
    popupFanIconSize: 0,
    popupHeightPercent: 80,
    containers: [
        {id: "downloads", path: "", title: qsTr("Downloads"), icon: "folder-downloads",
            layout: "grid", sortMode: "modified", browseSubfolders: true, hiddenEntries: []},
        {id: "home", path: "", title: qsTr("Home"), icon: "user-home", layout: "fan",
            sortMode: "name", browseSubfolders: true, hiddenEntries: []}
    ]
}

// A fresh copy keeps a caller from changing the module for the next one.
function fresh() {
    return JSON.parse(JSON.stringify(profile))
}
