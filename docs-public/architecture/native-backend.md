# Native backend

Punchi Dock Quickshell cannot implement application launching, window access or
KDE status through QML alone. A native Qt/KDE QML module (`Punchi.Kde`) and a
dedicated window-state executable form the boundary between the QML surfaces and
the desktop. Everything here is an adapter: no visual component imports it
directly.

## Contract

Native KDE integration is a product requirement. Quickshell hosts the surfaces;
KDE Frameworks and supported KWin interfaces own desktop integration. Adapters
must respect KDE preferences and capability restrictions. Where a capability is
optional, loss of the provider must degrade to a documented state instead of a
crash or a silent false value.

Quickshell uses private Qt APIs, so its binary must match the Qt version it was
built for. A normal KDE, Qt or Quickshell update can therefore invalidate it;
rebuilding addresses a binary mismatch, while a changed API contract needs code
adaptation and regression checks.

## Launch and activation

The `Punchi.Kde` QML module resolves desktop IDs with `KService` and launches
through `KIO::ApplicationLauncherJob`. `KWaylandExtras` requests a
target-specific activation token from the view's actual `QQuickWindow` and input
serial, and KIO receives that token through `setStartupId`. KDE cursor feedback
must come from the desktop rather than a QML imitation.

Accepted dispatch and asynchronous completion are separate signals, so a launch
that was accepted is never reported as completed. `PunchiApplicationStartupGuard`
and native `IsStartup` prevent repeated normal launches while an application is
starting. Explicit desktop actions retain their launch path; middle-click New
Window uses `requestNewInstance` when a native window exists and KIO otherwise.

Desktop actions come from `KService::actions()` for the configured desktop ID,
with hidden, separator and empty-command actions excluded. KDE supplies localized
names and command parsing, and execution uses
`KIO::ApplicationLauncherJob(KServiceAction)`. A separate adapter receives the
menu content's host `QQuickWindow`, capturing its input serial before the popup
closes. No application-specific commands are invented.

New-window eligibility follows Plasma's `SingleMainWindow`,
`X-GNOME-SingleWindow` and duplicate desktop-action rules.
`PunchiApplicationContextService` combines desktop actions with a generic
new-window action and local dock pin settings. Task/window management beyond the
documented set is not implied by these adapters.

## Window access

`punchi-window-state` is a dedicated executable. Its own hidden desktop
declaration scopes KWin interface access to that executable; no generic
Quickshell permission change or compositor bypass is involved. It uses Qt's public
native Wayland registry and KDE's native TasksModel QML contract.

`PunchiWindowModels.qml` is embedded in that executable. It owns separate official
KDE projections for all running windows and visible windows on the current
desktop/activity. The backend emits IDs plus an independent visibility snapshot;
it observes `KWindowSystem::showingDesktopChanged` and uses a short settling delay
for newly placed-window geometry. No titles, PIDs, actions, network services or
extra desktop permissions are added.

The window backend shares `taskidentity` between running snapshots and activation.
It resolves native launcher metadata first, then unambiguous KDE metadata aliases
cached per KSycoca revision. The dock projection consumes canonical identities.

Unavailable access is separate from a ready empty model; registration and lifetime
belong to the running-application markers. Visual window selection, task filters
and shortcuts remain future service/adapter responsibilities.

## Running markers

`PunchiRunningApplications` is a native process owner that receives desktop-ID
snapshots from `punchi-window-state`; the QML service then matches IDs through the
native application catalog. The snapshot also publishes `activities` and
`currentDesktopIds`; the optional marker filter swaps the running sets for those
values while pinned items remain visible.

Only window data drives the marker: never launch completion, a clicked selection
or process-name polling. That separation keeps a click from claiming a window that
does not exist.

## Updates

Update notices follow the same split without a window of their own.
`UpdateState` is a native read-only aggregation of PackageKit, fwupd and Flatpak.
`PunchiUpdateNotice` owns which desktop ID receives the count and the settings
gate; `PunchiDockBadge` is a child of the launcher tile, so the magnification
transform carries it with the icon.

The count is read only through those native interfaces. The dock never asks
Discover, never installs anything, never refreshes package caches and never
requests authorization. PackageKit reports its own backend (`dnf5`, `apt`, `alpm`,
`zypper`), so distribution packages work wherever PackageKit is installed; AUR
helpers and Snap are not queried.

## Media and recent data

The private Plasma MPRIS provider is isolated in one adapter
(`PunchiApplicationMediaAdapter`). `PunchiApplicationMediaService` owns the
transport contract and reusable metadata, so media state is independent of dock
surfaces. Context rows emit intents through the selected-application service.

`PunchiRecentDocumentsAdapter` exposes a native proxy over the Activities Stats
`ResultModel`: the selected desktop ID and current activity scope the five most
recent resources. Rows update through model signals. Recent activation verifies
that the resource is still in the selected model, uses KIO URL arguments and the
popup activation token, and selects the preferred MIME handler when the originating
application cannot open it. Explicit history clearing uses the same
application/current-activity query.

For `FileManager` desktop entries, `PunchiFilePlacesAdapter` exposes a native proxy
over `KFilePlacesModel`. It reads KDE's shared bookmarks, filters hidden places,
preserves native labels and icons, and projects the first group inline with later
groups as navigation entries. Like Plasma, more than seven top-level entries
initially show five plus a remaining count; More and group/back navigation stay in
the same balloon. Activation rechecks visible native membership and the
file-manager category, then sends the native URL through KIO and the existing
activation-token path. Places requiring device setup are disabled; mounting is a
separate capability.

The [official task-menu backend](https://github.com/KDE/plasma-desktop/blob/master/applets/taskmanager/backend.cpp)
and local taskmanager metadata inform these contracts. Recent data uses the public
Activities Stats model API, without importing the private taskmanager applet.

## Owned KWin settings

Punchi Dock Quickshell may change the global KWin minimize effect only after an
explicit user selection, and only within KWin's `exclusiveGroup=minimize`. Before
its first write, it captures the presence and boolean value of every discovered
`Plugins/<effect>Enabled` key in the user-owned
`$XDG_STATE_HOME/punchi-dock-quickshell/owned-settings.json` recovery record
(fallback: `$HOME/.local/state/punchi-dock-quickshell/owned-settings.json`). A
legacy record in the former `punchi-shell/` directory is read only when the new
record does not exist, and the original snapshot is preserved during migration.
The record is written atomically with owner-only permissions before `kwinrc`
changes.

Only keys whose effective values differ from the requested state are written, and
unrelated KWin settings are preserved. On clean shutdown and when
`scripts-user/restore-kde.sh` runs, each owned key is restored only if its current
presence and value still match the last state Punchi Dock Quickshell wrote. An
original value is restored when the key was present, or the key is deleted when it
was originally absent. A key that no longer matches the recorded write is
preserved as an external user change and its ownership entry is discarded. The
recovery record stays when restoration or its durable write fails, so the restore
script can retry after an unclean exit.

## Capability limits

One current dependency needing particular attention is
`org.kde.plasma.private.mpris`, the internal Plasma module behind the context
menu's media transport. Window/task integrations and KDE screen-edge behavior also
need testing against the target Plasma/KWin version. Prefer public APIs, keep
internal integrations isolated, and provide graceful unavailability where a
capability is optional.

Real KWin activation, native cursor appearance, physical hot-plug, fractional
scaling and full visual quality remain separate session checks; a passing
offscreen test does not establish them. See
[Compatibility](../getting-started/compatibility.md) for the validated versions.
