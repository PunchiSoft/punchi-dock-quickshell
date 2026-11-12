# Architecture

Folder containers use a native KDirModel/sort-proxy provider with reactive QML
roles. The built-in Home container resolves `QStandardPaths::HomeLocation` and
enables a proxy filter that keeps only the standard KDE/XDG user folders while
the listing is at that root. PunchiFolderNavigationController owns history and
file-opening intents, while the Grid/List/Detail content shares PunchiBalloonSurface. An action-row proxy appends
Grid's Open in File Manager cell without copying directory rows. The existing
KDE launch adapter resolves preferred MIME applications and captures activation
before popup dismissal. PopupBlurController confines KDE WindowSystem blur to the
current surface shape when the compositor exposes that effect.

The container presentation is shared. `components/PunchiEntryButton`, `PunchiEntryLayout`,
`PunchiEntryMarqueeLabel`, `PunchiFanView`, `PunchiFanRow`, `PunchiFanGeometry`, `PunchiPopupHeader` and
`PunchiPopupShadowLabel` render Grid, List, Detail and Fan for two confirmed consumers:
the folder container and the recent-applications container. They take the model
rows, the `PunchiPopupMetrics` and the pointer/keyboard emphasis as inputs and emit
intents, so neither the popup host nor a delegate reaches a service or an
adapter. `modules/recent` owns the recent container surface:
`PunchiRecentApplicationsPopup` anchors it to the dock item and confines the blur, and
`PunchiRecentApplicationsContent` draws the selection model the dock already filters.
The native `DockApplicationsModel` publishes either the resolved recent rows or
one `item:recent` row, never both, and that row exists only while the selection
has an application to show.

Special items use `DockItemCatalog`, a native concatenating model combining the
application catalog with separate item metadata. Trash has a structured item ID,
empty desktop ID and no application-picker presence. Existing pin ordering is
shared across item kinds. `TrashState` owns KIO state/operations, `PunchiTrashService`
owns the confirmation decision, and Qt-only content/motion plus a window wrapper
own presentation. The existing application launcher handles directory-app
selection and activation for opening `trash:/`.

Application media state is independent of dock surfaces. The native Plasma MPRIS
model lives behind `PunchiApplicationMediaAdapter`; `PunchiApplicationMediaService` owns the
transport contract and reusable metadata. Context rows emit intents through the
selected-application service.

The window backend shares `taskidentity` between running snapshots and activation.It resolves native launcher metadata first, then unambiguous KDE metadata aliases
cached per KSycoca revision. The dock projection consumes canonical identities.

`ShellRoot` composes independent modules. A feature has a small window wrapper and
Qt/Kirigami view. Shared components depend on inputs, not service singletons or window
internals. Services never import visual components. Settings flow through bindings.

Dock placement is composed from three objects: `PunchiDockServices` owns the shared
catalog, window backend, update tracker, Trash state, item models, KWin minimize
controller and clipboard once; `PunchiScreenPolicy` decides which connected screens may
show a dock; `PunchiVirtualDesktopPolicy` decides whether the active virtual desktop and
KDE activity are allowed. `Variants` creates one `Dock` PanelWindow per connected
screen, so changing the selection or switching desktops never recreates windows.
The policy keeps a disallowed window mapped but without exclusive zone, input mask
or edge trigger; unmapping every window would let the shell exit while a desktop
is excluded. `PunchiDockIpc` is the only `dock` handler and addresses a screen key.
When no selected screen is connected, `PunchiScreenPolicy` falls back to
`Native.ScreenInfo`, which exposes Qt's primary screen name. `PunchiScreenSelection.js`
holds the pure selection, identity and shared-edge logic.

Running markers consume `PunchiRunningApplications`: a native process owner receives
desktop-ID snapshots from a dedicated `punchi-window-state` executable, then the
QML service matches IDs through the native application catalog. The snapshot also
publishes `activities` and `currentDesktopIds`; the optional marker filter swaps
the running sets for those values while pinned items remain visible. The backend uses
Qt's public native Wayland registry and KDE's native TasksModel QML contract.
Its own hidden desktop declaration scopes KWin interface access to that executable;
no generic qs permission change or compositor bypass. Only window data drives the
marker, never launch completion, clicked selection or process-name polling.
Unavailable access is separate from a ready empty model; registration and lifetime
belong to the running-application markers.

Update notices follow the same split without a window of their own.
`UpdateState` is a native read-only aggregation of PackageKit, fwupd and Flatpak;
`PunchiUpdateNotice` owns which desktop ID receives the count and the settings gate;
`PunchiDockBadge` is a child of the launcher tile, so the magnification transform
carries it with the icon.

Native KDE integration is a product requirement. Quickshell hosts the QML
surfaces; KDE Frameworks and supported KWin interfaces own desktop integration.
Adapters must respect KDE preferences and capability restrictions. The native
`Punchi.Kde` QML module resolves desktop IDs with KService and launches through
KIO::ApplicationLauncherJob. KWaylandExtras requests a target-specific activation
token from the view's actual QQuickWindow and input serial; KIO receives that
token through setStartupId. KDE cursor feedback must come from the desktop rather
than a QML imitation. The adapter is implemented; real KWin activation and cursor
appearance remain unvalidated.

```text
shell.qml
  └─ modules/dock/PunchiDock.qml        Quickshell window and wiring
       ├─ config/PunchiShellSettings    Reactive dimensions and motion preferences
       ├─ services/PunchiDockFixtureModel  Configured desktop IDs
       ├─ services/PunchiApplicationLaunchService  Validated intent routing
       │    └─ adapters/kde/PunchiDesktopApplicationAdapter → native/Punchi.Kde → KService/KIO
       └─ modules/dock/PunchiDockView   Qt/Kirigami view and intent signals
            ├─ modules/dock/PunchiDockMagnification  Spatial wave and entry/exit progress
            └─ components/PunchiDockTile  Unified icon/frame/hit transform
                 ├─ components/PunchiDockClickFeedback → PunchiTwoHopBounce
                 ├─ components/PunchiDockTooltip  Unscaled themed speech balloon
                 └─ components/PunchiAntialiasedSurface  Shared bounded MSAA profile
```

This split lets Qt Quick Test exercise interaction without loading Quickshell's
statically registered runtime types. Real-session probes load the same Dock window
through Quickshell, then check rendering and lifecycle.

The eight preset launchers are initial defaults. DockApplicationsModel references
pinned rows plus known running unpinned catalog rows; transient entries never
change persisted pins. Activation
selects a row and emits an ID. PunchiApplicationActivationService asks the separate
WindowActivation domain to find and activate an existing native window inside the
backend, cycles matching groups or minimizes a single active window.
PunchiApplicationStartupGuard and native IsStartup prevent repeated normal launches
while starting. A fresh no-window result routes through PunchiApplicationLaunchService to
PunchiDesktopApplicationAdapter, which calls the native KDE launcher. Explicit desktop
actions retain their launch path; middle-click New Window uses requestNewInstance
when a native window exists and KIO otherwise. Accepted
dispatch and asynchronous completion are separate signals. Delegates never
execute processes. Visual window selection, task filters, and shortcuts
remain future service/adapter responsibilities.
Rust is optional and has no dependency or placeholder crate at this stage.

The panel supports bottom, left and right screen edges through `PunchiShellSettings.dockEdge`.
Orientation follows the selected edge. The bottom allocation has one anchor;
lateral allocations use top/bottom plus the selected side so KWin supplies their
usable main-axis extent, with compact content centered inside the masked window.
Normal modes respect other panels' exclusion zones; edge modes retain the
existing physical-edge policy.
PunchiDockPanelPolicy validates four native visibility modes and selects base-space
reservation; PunchiDockVisibilityController handles auto-hide and window dodge.
All modes use Top. PunchiPanelModes normalizes the retired desktop ID to dodge-windows.
The default reserves no space; reserve mode excludes the transparent top allocation.
`PunchiDockIpc` changes the policy live for every screen. The dock accepts on-demand
keyboard focus rather than exclusive focus. All Plasma panels and services remain active. Restoration stops only this
configuration. Future session replacement requires a separate explicit decision.

Quickshell 0.2.1 installed type metadata and the versioned
[PanelWindow](https://quickshell.org/docs/v0.2.1/types/Quickshell/PanelWindow/)
and [keyboard-focus documentation](https://quickshell.org/docs/v0.2.1/types/Quickshell.Wayland/WlrKeyboardFocus/)
back these API choices. KDE capability claims still need actual compositor evidence.

Pointer coordinates and logical cell centers remain stable during the wave. Only
entry/exit progress animates; pointer motion maps directly to the cosine functions.
The window reserves the maximum visual extent. The visible background follows the
main-axis bounds without changing its base thickness or feeding layout back into the
pointer calculation. Tooltips remain unscaled and follow the rendered icon top or inward-facing side.
Running markers remain below the icon in every orientation.

The common cosine profile spans seven logical pitches, so three neighbours on
each side receive graded magnification. Its full amplitude follows the selected
zoom; there is no separately capped shoulder or narrow added peak. Horizontal
translation uses closed-form finite cosine sums: the displacement difference
between adjacent centres equals half their combined natural-cell growth,
preserving their original gap. Far translations saturate at the same profile's
maximum. The natural theme-derived cell, rather than additional slot padding,
defines this growth. No per-pointer loop, model rebuild or relayout is added.

PunchiDockMetrics defines the maximum icon ceiling as three times the normal Kirigami
base size. The existing 100–300% zoom preference selects the interval from the
chosen base size (100%, no enlargement) to that ceiling (300%). At the normal
base size it retains the original percentage/size relation; smaller bases can
reach the same maximum absolute theme size. Larger bases are never shrunk.
Texture resolution and static window reserves consume the effective scale,
including scales above 3 when the base is small. These proportions are calibrated
against the supplied macOS references, not Apple's exact formula or fixed pixels.

`adapters/kde/PunchiMotionPreferences.qml` reads Kirigami durations and detects disabled
system animations through `shortDuration`. Settings expose a separate explicit
reduced-motion override. Reduced motion removes displacement and animated entry,
retaining at most an instant 8% active-item emphasis.

PunchiDockMetrics is the shared geometry profile for settings, view, and tile defaults.
It derives compact proportions from Kirigami icon sizes, spacing, and corner radius.
The reference screenshot informs proportions without freezing KDE theme units.
Tooltip spacing and border metrics also use Kirigami.Units.

PunchiTwoHopBounce preserves the original two peaks and easing. PunchiDockClickFeedback
coalesces repeated feedback without suppressing activation intents. Its offset adds
to wave lift; the frame, hit target, and balloon remain tied to the control transform.
Reserved window geometry includes the maximum bounce amplitude. Disabled motion,
hidden surfaces, or disabled controls reset feedback immediately.

The dock context menu uses a nonmodal Qt Quick Controls `Popup.Item` in the
same QQuickWindow as the dock. A separate native Qt popup grabs Wayland input,
preventing interaction with other launchers until dismissal. `PunchiPopupAnchor`
captures rendered icon bounds; the wrapper normalizes the vertical coordinate
against the dock's base allocation and centers the popup above the icon, clamping
horizontally within the window. `PunchiDockWindowGeometry` keeps the revealed client's
transparent allocation stable at the monitor height minus its bottom margin.
Menu visibility and content never resize the native window, avoiding transient
Wayland configure/buffer/input-coordinate changes during popup interaction. The
visible dock stays at its bottom baseline with unchanged surface height and
exclusive zone. Quickshell's input region combines the dock viewport and visible
menu, allowing surrounding transparent allocation to pass input to the desktop.
Auto-hide still collapses the native window after its slide finishes; its input
region follows the bottom activation strip while waiting for the resize.
`PunchiDockContextContent` supplies compact action rows and a separator. Inactive rows
have no separate background. `PunchiBalloonSurface` supplies the shared rounded
body/pointer silhouette, theme colors and Kirigami metrics. Its pointer uses
client coordinates within the same window. Every popup row, listing entry and
popup control asks for the pointing hand while it can act and keeps the arrow
when it cannot: Qt 6 exposes no `Item.cursorShape`, so each control declares a
passive `HoverHandler` whose `cursorShape` follows that control's enablement.
Magnification remains active while
visiting the menu and follows the pointer when it returns to another launcher.
Outside presses dismiss the nonmodal popup and reach the clicked control in one
interaction; Escape and focus restoration remain available. Pending opens are
cancelled when another launcher activates. Real KWin input regions, placement and
native activation remain separate session checks.

Desktop actions come from `KService::actions()` for the configured desktop ID,
with hidden/separator/empty-command actions excluded. KDE supplies localized names
and command parsing. Execution uses `KIO::ApplicationLauncherJob(KServiceAction)`.
A separate adapter receives the menu content's host QQuickWindow, capturing its
input serial before the popup closes. No application-specific commands are invented.
Task/window management and the original dock's blur controller are not ported.

`PunchiApplicationContextService` combines desktop actions with a generic new-window
action and local dock pin settings. New-window eligibility follows Plasma's
`SingleMainWindow`, `X-GNOME-SingleWindow`, and duplicate desktop-action rules.
`PunchiRecentDocumentsAdapter` exposes a native proxy over Activities Stats `ResultModel`:
the selected desktop ID and current activity scope the five most recent resources.
Rows update through model signals. Recent activation verifies that the resource is
still in the selected model, uses KIO URL arguments and the popup activation token,
and selects the preferred MIME handler when the originating app cannot open it.
Explicit history clearing uses the same app/current-activity query; unpin updates
Punchi settings without modifying Plasma launchers. `PunchiDockContextAction` sizes rows
from the system font, Kirigami icon metrics and padding. No new window-management
capability is implied: Close/Move/More need the dedicated window-detection backend.

For `FileManager` desktop entries, `PunchiFilePlacesAdapter` exposes a native proxy over
`KFilePlacesModel`. It reads KDE's shared bookmarks, filters hidden places, preserves
native labels/icons and projects the first group inline with later groups as
navigation entries. Like Plasma, more than seven top-level entries initially show
five plus a remaining count. More and group/back navigation stay in the same
balloon; they do not create a new window or acquire a popup grab. Model indexes,
not copied row data, define this projection. Native bookmark edits update the
existing menu. The service resets navigation when selecting a launcher again.
Places replace the app's recent section, including its history-clearing action.
Activation rechecks visible native membership and the file-manager category, then
sends the native URL through KIO and the existing activation-token path. Places
requiring device setup are disabled; mounting is a separate capability. Shared
section headings and separators consume Kirigami theme colors and units.

The [official task-menu backend](https://github.com/KDE/plasma-desktop/blob/master/applets/taskmanager/backend.cpp)
and local taskmanager metadata inform these contracts. Recent data uses the public
Activities Stats model API, without importing the private taskmanager applet.

The root configuration opts into Quickshell's `UseQApplication` and
`RespectSystemStyle` startup pragmas. KDE QQC2 Desktop Style needs QApplication
for its QStyle-backed controls; respecting the system avoids Quickshell's default
Fusion override and preserves explicit user style choices. The settings view
owns a Kirigami Window color set, native font and palette role bindings rather
than inheriting the scroll container's View colors. These startup options require
a Punchi Dock Quickshell process restart; ordinary settings remain live.
Configuration uses KDE application styling; Plasma SVG widget themes are a
separate theme layer. No private style imports or system configuration writes are
needed. The pragmas were verified in the installed Quickshell 0.2.1 revision.

The shell does not import Plasma Core's Dialog QML type. This removes its duplicate
visible-property cache and localization-context thread mismatch from our startup
path. KDE application behavior remains in Frameworks adapters; popup hosting uses
Quickshell's public API rather than PlasmaQuick's private C++ window API.

## Application item configuration — first stage

The settings view composes a bounded eight-grid-unit category sidebar, Items,
General and Popups pages, a main-content footer and a modal item draft. Native
ItemDelegate selection and Kirigami View/Window color sets define navigation.
General retains the initial selection. Items lists the pinned projection; its Add intent opens a
type selector for applications, folder containers and Trash. Application search
and selection flow through `PunchiApplicationPinService`; only accepting the modal
adds the selected application to the settings draft. Containers carry their
selected Grid/List/Detail view, and Trash is offered only when not already pinned.
Discard, Escape and closing the settings window clear the picker state.
Selection never launches an application.

`PunchiSettingsEditService` owns the window-wide PunchiShellSettings draft, baseline and dirty
state. The view emits Apply/Accept/Close intents; PunchiSettingsWindow connects them to
commit/cancel and window lifecycle. Only Apply/Accept update the existing dock
settings and PunchiSettingsStore. Untouched fields follow external changes; explicit
edits win field conflicts on commit. A pending reset or added pin never reaches
the dock or persistence on Close/titlebar close/Escape. The window remains live
after Apply, with a clean baseline; opening an already visible window preserves
its current draft. No service depends on visual components.

`PunchiPinnedItemsEditService` owns selected item identity, bounded adjacent
reordering, and removal from the pending pin list. Removing a user folder also
removes its descriptor; it never deletes the directory or its contents. Built-in
Home and Downloads metadata remains available if their dock pin is removed. The Items view
exposes configure, native arrow and remove controls, tracks Qt model structural
signals to refresh its selected row and preserves selection across moves/removal.
Up/down keyboard navigation selects list entries; action activation changes the
pending draft. Apply/Accept publish it through the existing incremental pin
projection, preserving unaffected dock delegates.

Settings window visibility is composed into the dock's transient `configuring`
state. `PunchiDockConfigurationController` reveals the host and restores prior explicit
visibility on close. `PunchiDockPanelPolicy` requests Top during configuration without
changing the saved mode/reservation; `PunchiDockVisibilityController` treats it as an
interaction that holds auto-hide revealed. Native panel hosting remains in Dock;
shared controllers can be tested with an offscreen window independently of KWin.
The application picker uses a larger results region and a left-aligned two-column
metadata grid, rather than FormLayout's centered intrinsic columns.

`PunchiApplicationCatalog` is a native Qt model built from KService desktop metadata,
refreshed by KSycoca database changes. The eight legacy preset IDs and dock icons
remain mapped, while new entries use `desktop:<storageId>`. The picker uses native
application names/icons and a QSortFilterProxyModel for installed-entry search,
without a JavaScript copy of the application catalogue. It filters NoDisplay and
invalid desktop IDs; icon URLs cannot fetch remote content. Search filter changes
use row-filter notifications on supported Qt, with an older-Qt fallback. Identical
catalogue reloads do not reset views.

`PunchiDockItemIds.js` validates persistence IDs and unique pin lists, bounded to 32
entries within the 256 KiB profile limit, and validates folder-container
entries (stable slug, absolute or empty path, unique ids and a supported layout).
Schema version 7 retains the old preset/application and structured special-item
IDs, stores the layout on each container, adds per-container sorting and adds
the recent-applications switch/count; version 13 adds the recent-applications
presentation and its container view, validated by `PunchiRecentPresentation.js`. A compatibility `downloadsView` mirror
preserves schema-3/4 profiles and existing diagnostics. Schemas 1 to 6 remain
readable, with one-time Trash/Downloads migrations when capacity permits. The
built-in Downloads container keeps its historical `item:downloads` id; the
built-in Home container and containers added later use `item:folder:<slug>`,
which the native catalogue exposes as one row each. An empty path is resolved by
the native provider: `home` uses `HomeLocation`, `downloads` uses
`DownloadLocation`. First-run defaults include Home between Konsole and the
Browser item with Fan/Name presentation and subfolder browsing off; a stored
profile with containers keeps its own list, so the default is not a migration. Unknown removed applications stay
in persisted pins and reappear when their desktop entry returns. The pin projection
inserts, moves, updates or removes only affected rows, preserving other delegates.
New pins use the existing KService/KIO launcher and native context-menu pipeline.
Raw commands, custom display metadata and other item kinds
are outside this first editor stage.

`PunchiDefaultProfile.js` owns the first-run launcher catalogue, pinned order,
containers, preference values and validation ranges. `PunchiShellSettings` starts from
that data and `reset()` restores a fresh copy, so a first install and an explicit
reset cannot drift. A catalogue row either names one desktop entry or, with an
empty `desktopId` plus `defaultMimeTypes`, a role: `PunchiApplicationCatalog` asks
`KApplicationTrader::preferredService` for the ordered MIME types and publishes
the resolved `storageId`, so the Browser item opens whatever this KDE session
prefers and every consumer — launching, running markers, window actions and
media control — keeps seeing one real desktop id. The resolved application's
icon replaces the role's own icon, and no picker duplicate is offered. `PunchiProfileDocument.js` validates the portable JSON exchange
document and raw saved profiles; `PunchiProfileExchangeService` previews the result on
a separate `PunchiShellSettings` and leaves the target untouched until confirmation.
The native `ProfileFile` bounds reads to 256 KiB, rejects FIFOs and devices,
checks UTF-8 and writes atomically with owner-only permissions while refusing
symbolic-link destinations. A profile is data only: it contains no command,
script, autostart entry or KDE configuration.

`PunchiRecentApplications` references Plasma Activities Stats through the native
adapter and selection proxy. It filters invalid, pinned and open applications and
bounds the visible count. The exclusion list follows `catalog.revision`, because
a preset row resolves its desktop id only after the asynchronous catalogue load;
without that dependency a pinned application reached the container. The
selection either appends resolved rows to `DockApplicationsModel` before special
items (`icons`) or feeds the container item and its popup (`container`, the
first-run value), never both. History is read from KDE; the project does not
maintain a second recent list. The adapter keeps its `KActivities::Consumer` for its whole
lifetime and builds the Stats source only while the list is enabled, so
`available` describes the KDE service instead of the dock preference; that
separation keeps the settings switch usable after hiding the list and keeps
recording dock launches while the list is hidden. The history query is scoped to
KDE's current activity; when the service reports none, the adapter reads every
activity instead of the empty current activity, which would match nothing. That
fallback affects only reading: KDE keeps recording new launches for its current
activity, so a session without one does not grow the history. The adapter also reads `what-to-remember` from
`kactivitymanagerd-pluginsrc` and watches that file, because KDE records no
application history when the setting is "remember none"; the settings card uses
that state to disable the controls and explain the requirement. The adapter
writes only the two public states of that key when the user flips the
remember-history switch, and opens KDE's `kcm_recentFiles` module for the
remaining options. The container keeps the four folder presentations; a side
dock presents a stored fan as Grid, and its menu stores the chosen view.

`AutoHideEdge` owns a separate, transparent Wayland edge sensor on the dock's
named output. KWin manages its native edge activation and themed glow. The sensor
uses an asynchronous private client connection, bounded shared-memory buffers,
no keyboard focus and no reserved space. Input is cleared immediately after
activation and while the dock is visible. Missing capabilities retain the dock's
local edge strip. This sensor does not own or animate the dock scene.

The dock keeps its stable client allocation to preserve menu/hover behavior.
`PunchiDockVisibilityController` animates a single reveal progress with Plasma-like
cubic entry/exit and KDE duration preferences. Completion settles visibility
without polling. `PunchiDockSlideGeometry` captures visual travel only at settled
endpoints, excludes unused top headroom and preserves the distance during a
reversal. Native edge handling and QML sliding have separate responsibilities;
there is no second compositor animation on the large dock window.

`PunchiWindowModels.qml` is embedded in the dedicated window-state executable. It owns
separate official KDE projections for all running windows and visible windows on
the current desktop/activity. The backend emits IDs plus an independent
visibility snapshot; it observes `KWindowSystem::showingDesktopChanged` and uses a
short settling delay for newly placed-window geometry. No titles, PIDs, actions,
network services or extra desktop permissions are added.

`WindowVisibilityState` owns bounded geometry parsing and intersection queries
behind the shared process transport. `PunchiWindowOverlap` exposes its reactive results
to `PunchiDockVisibilityController`. `PunchiDockRestingGeometry` derives the resting painted
footprint from logical screen coordinates and KDE metrics, independent of the
large host allocation, zoom and slide. `dodge-windows` adds hiding only for known
intersection outside Showing Desktop; provider loss reveals the dock. Auto-hide
keeps its original pointer-exit policy. Both surfaces declare scope `dock`, which
KWin uses for desktop-shell classification separately from Top/Bottom layers.

## Where the files live

The physical map of the repository is the `Repository tree` section of the tracked
`CONTRIBUTING.md`, so it exists in every clone; this document explains behavior, not
paths. Published documentation is tracked under `docs-public/`; generated and
machine-local paths are ignored:

| Ignored path | Purpose |
| --- | --- |
| `build/build-<ID>/` | one build tree per distribution; `build/dev` for the preset |
| `scratch/`, `backup/` | disposable local work and safety copies |
| `.qmlls.ini` | editor QML language-server metadata, regenerated on demand |

`docs-public/README.md` indexes the published documents.
