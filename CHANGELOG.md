# Changelog

## 0.1.16 — 2026-10-19

- Show PunchiSoft as the project author and refresh the version displayed in the
  About page.
- Document the use of AI coding agents as development support.

## 0.1.15 — 2026-10-19

- Keep Add Item inside the Items settings page, replacing only the item-content
  area while preserving the sidebar, toolbar and settings footer.
- Add Plasma task-window actions to the application context menu, gated by live
  window capabilities and virtual-desktop state from KDE's task model.
- Accept KDE's transient empty virtual-desktop names so the window backend stays
  available during startup.
- Restore the dock's Open Trash entry point in the real KDE adapter.

## 0.1.14 — 2026-10-14

- Use the theme's `folder-open` icon for the folder container's Open entry.
- Added transient dock entries for eligible running KDE windows that lack a
  visible application desktop entry, using the task model's application name
  and theme icon metadata.
- Unified item addition for applications, Grid/List/Detail folder containers
  and a single Trash item; Items settings can configure, reorder and remove
  pinned entries without deleting applications or folder contents.

## 0.1.13 — 2026-10-14

- Renamed the project and repository to **Punchi Dock Quickshell** and added a
  Fedora source-checkout setup recipe. Existing `punchi-shell.json` preferences
  and KWin recovery records are migrated without replacing a newer file.
- Added an About page to settings with the project logo, current delivery
  version, repository and issue links, license information and contributor
  attribution.
- Added recoverable ownership for Punchi Dock Quickshell's global KWin minimize-effect
  changes. The shell records original key presence and values, restores only
  settings that still match its own writes, and exposes a restore command for
  recovery after an unclean exit.
- Bounded KWin effect metadata reads and changed the live reconfigure request to
  asynchronous D-Bus.

## 0.1.12 — 2026-10-14

- Kept the development documentation under `docs/` local: it is no longer
  published with the repository, and the files remain on disk unchanged.
- Replaced the published `docs/` links with local file references in `README.md`,
  `CONTRIBUTING.md`, `tests/README.md`, `AGENTS.md` and the skills, so a fresh
  clone has no broken documentation links.
- Corrected the documented settings-format version in the README to schema 6,
  matching `ShellSettings.qml`.

## 0.1.11 — 2026-10-14

- Added folder containers: **Add folder** in Items binds a dock item to any
  folder and **Choose folder** changes its path later. The container keeps a
  stable slug, so changing the folder preserves its order and its open popup.
  The built-in Downloads container stays first, before Trash.
- Added Downloads with Grid, List and Detail views, native KDE directory
  updates, navigation with Back restoration and preferred KDE file/folder
  opening through the existing KIO/Wayland activation path.
- Matched the folder Grid popup to Punchi Dock's reference with larger bold
  labels, a top-right close control, a circular Open in File Manager cell, and
  KDE blur behind the balloon when available.
- Labeled the Grid popup's final folder-opening cell “Open” beneath its arrow
  icon and increased its icon slots from 2.5 to 3 grid units.
- Added fixed-geometry marquee captions for long file and folder names in popup
  Grid/List/Detail views, with a matching 25% theme-colored shadow on the title
  and a reduced-motion tooltip fallback.
- Added folder context-menu sorting by name, size, modification date, creation
  date or type, plus Grid/List/Detail selection and an action to open the
  configured folder. Preferences persist per folder; Date Added and the Options
  submenu remain deferred.
- Added Bottom/Left/Right position selection with pending edits, persistence and
  reactive dock geometry; older profiles keep their Bottom default.
- Reused the wave vertically with inward growth/bounce, upright icons, indicators
  below icons, Up/Down navigation and bounded wheel/keyboard overflow handling.
- Added side-following balloon tails and icon-relative popup placement while
  preserving horizontal behavior and subsequent launcher clicks.
- Extended native KDE auto-hide sensors to both side borders with bounded
  allocations, edge-to-content pointer holding and axis-aware dodge/reservation.
- Matched launcher-tooltip colors to the context menu's Kirigami Window profile,
  preserving its comic balloon, pointer and system font.
- Persisted containers, their layout and their sort criterion in schema 6, which
  accepts schemas 1 to 5 and keeps the one-time Trash/Downloads migrations.
- Validation: the full CTest graph passed (29/29, `qml_lint` included, no new
  diagnostics). Physical KWin placement, KDE blur and real-theme appearance
  remain separate manual checks.

## 0.1.10 — 2026-10-13

- Added a native read-only KDE user header with Kirigami's circular shader avatar
  and a themed icon fallback for missing photos or software rendering.
- Grouped settings into responsive appearance, behavior and animation sections,
  with descriptive slider endpoints, accessible numeric values and a No position that
  replaces the separate magnification toggle.
- Kept the sidebar and Apply/Accept/Close footer fixed while central pages scroll,
  preserving pending edits and reactive external settings.
- Preserved application-picker space and corrected keyboard selection after item
  moves to follow the selected application rather than a transient view cursor.
- Positioned Small along the magnification track, separated from No, and hid
  repeated native tick marks without changing input steps or keyboard operation.
- Validation: 24 isolated CTest groups and 162 component cases passed. The
  registered real-session reload probe remains excluded; lint retains the same
  three upstream warnings. GPU-photo clipping and physical KWin checks remain
  separate from the inspected offscreen light/dark layouts.

## 0.1.09 — 2026-10-13

- Documented version-matched Quickshell/Qt editor setup and added official
  reference, tooling-diagnostic and KDE-boundary guidance to the Quickshell skill.
- Recorded the three remaining upstream tooling diagnostics, the zero-new-warning
  policy, and the checks required to retire resolved exceptions after updates.
- Widened the dock magnification profile to three graded neighbours per side and
  removed the shoulder cap that stopped neighbour growth above 200% zoom.
- Matched horizontal separation to adjacent scaled cells using constant-time
  finite cosine sums, preserving gaps without additional layout or animation loops.
- Derived the maximum icon ceiling from KDE metrics and decoupled it from small
  base sizes; 100% remains unmagnified and normal-size percentage behaviour remains
  intact. Texture and reserve bounds follow the effective magnification.
- Added coverage for high-zoom neighbour growth, cursor transfer, exact separation,
  small/normal/large bases and edge containment; refreshed numeric profile samples
  for the corrected spatial contract.
- Validation: 24 isolated CTest groups passed; the registered real-session
  `settings_reload` probe was excluded under the existing session restriction.
  QML lint retains the same three upstream diagnostics, with no new warnings.
  Physical KWin/visual behavior remains separate from automated checks.

## 0.1.08 — 2026-10-12

- Adopted a padded development-delivery counter, increasing once per delivery
  commit. The first `v0.1.0` snapshot is the `0.1.00` baseline; seven subsequent
  commits map to `0.1.01` through `0.1.07`, and this grouped delivery is `0.1.08`.
- Added native existing-window activation/minimization, group cycling, startup
  guards, middle-click New Window and transient running-application entries.
- Preserved application focus during pointer use so native active-window
  minimization can select the correct task.
- Added reusable KDE application media controls, distinct context pointer/focus
  states and shared application-identity matching for running windows.
- Added the reorderable Trash item, native KIO state and operations, confirmation
  motion, schema migration and early special-item metadata initialization.
- Added native KDE icon-theme notification refresh without replacing icon sources
  or delegates.
- Documented installation/distribution requirements, user settings and defaults,
  modular panel growth and KDE/Qt update compatibility responsibilities.
- Validation: 24 isolated CTest groups passed; the registered real-session
  `settings_reload` probe was excluded under the existing session restriction.
  QML lint retains three documented upstream diagnostics, with no new warnings.
  Physical KWin behavior and broad distribution compatibility remain separate.

## 0.1.0 — 2026-10-12

- First versioned repository snapshot of the current development work.
- Includes the modular Quickshell dock, native Qt/KDE adapters, configurable
  launchers, animated magnification, context menus and persistent settings.
- Includes developer validation tools, behavioral tests, architecture documents,
  attribution and GPL-3.0-or-later licensing.
- This snapshot is an initial prototype; desktop compatibility and visual
  validation retain the limits documented in the development guide.
- Known validation failure: `settings_reload` observes the startup panel-mode
  override after a Quickshell engine reload instead of retaining the changed
  mode. The regression test remains enabled.
- The dated development entries below preserve the implementation history
  included in this snapshot.

## Development history — 2026-10-12

- Refresh rendered dock, Trash, context-menu and application-picker icons after
  KDE icon-theme notifications, using the existing native KDE loader and Kirigami
  renderer without replacing delegates or icon sources. Added isolated pixel
  checks across repeated theme changes.

- Initialized special-item metadata before QML bindings run, preventing undefined
  Trash titles during early dock/settings model projection. Added startup and
  reactive-title regressions without suppressing warnings.

- Added a reorderable special Trash item, reactive native KIO empty/full state,
  KDE directory-app opening, an icon-anchored Open/Empty menu and themed animated
  confirmation. Schema 2 preserves item order and migrates legacy pins without
  removing entries. Running applications precede trailing special items.
- Added owned native-state and Quickshell confirmation tests; no real mounted
  trash is emptied during validation.

- Separated context-menu pointer fill from keyboard visual focus, preventing the
  programmatically focused Configure Dock row from duplicating mouse hover.
- Added reusable application-scoped KDE MPRIS state and native context transport,
  including live capabilities and player departure without a global fallback.
- Shared KDE metadata identity resolution between running snapshots and window
  activation, covering differing executable/desktop names and rejecting ambiguous
  aliases. Added owned native-provider and identity regressions.

- Fixed the dock requesting keyboard focus merely by becoming visible, which can
  deactivate the application before deciding whether to minimize. Pointer use
  now follows Plasma's non-focusable panel policy; menus/explicit keyboard mode
  retain OnDemand. Added pointer-mode regressions and deliberate focusDock IPC.

- Added native window-group cycling, KDE startup-task detection and bounded
  normal-launch reservations to suppress repeated starts. Added middle-click
  New Window using requestNewInstance or the existing KIO fallback. A native
  dock projection now references pinned and known running catalog applications,
  keeping transient apps out of saved pins and restoring keyboard focus on removal.

- Normal clicks now request minimization of an eligible active matching window
  through KDE TasksModel. Inactive/minimized windows retain the activation path;
  a non-minimizable window is not toggled. Added native eligibility and typed
  result regression checks; physical KWin minimize/restore remains to validate.

- Added normal-click activation of existing KDE application windows through the
  dedicated backend, selecting an active or most recently used window, including
  minimized windows. Fresh no-window results use the existing KIO launcher;
  errors/timeouts do not launch duplicates as recovery. Explicit New Window
  remains separate. Added bounded command/result transport and isolated tests.

- Fixed the saved presentation mode reverting after a Quickshell reload. The
  session snapshot was held as a property value, which Quickshell's reloader does
  not match, so the start-mode override re-applied on every reload and overwrote
  live changes. SettingsStore is now a non-visual `Scope` so the session can be
  a real child that survives a reload. `settings_reload` passes.

- Retained the native edge pointer through reveal until a real Wayland leave,
  preventing trigger disarming from dropping the dock's visibility hold. Limited
  input and magnification to rendered content plus lower clearance; excluded
  unused headroom and preserved icon hover/click delivery through an ancestor
  observer. Added native lifecycle and pointer-handoff regressions.

- Shared a stationary input rectangle between dock hover detection and the native
  input mask, including transparent bottom clearance and the fallback edge strip.
  Separated transient launcher hover fill from the foreground keyboard-focus
  outline; pointer clicks no longer retain selection frames under icons.

- Matched Plasma's four visibility choices and their order. Always visible now
  selects reservation; Windows go below keeps the dock above ordinary windows
  without reservation. Retired Below windows stacking and migrated its saved
  `desktop` mode to genuine Dodge windows, including startup overrides and IPC.

- Classified dock and edge surfaces with KDE's `dock` scope for Show Desktop.
  Added the separate Dodge windows mode with native desktop/activity-filtered
  geometry, interaction holds, bounded snapshots and unavailable fallback.

- Fixed the native edge sensor's reactive `armed` binding loop by giving each
  writable property its own change notification. Added a strict QML regression.

- Added a scoped native KWin auto-hide edge sensor with themed compositor glow,
  pointer input release and a local fallback. Corrected slide timing, visual
  travel, reversal geometry and completion without changing menu allocation.

- Added themed, baseline-anchored markers for pinned applications with open KDE
  windows, separate from focus and launch feedback. A dedicated read-only native
  window-state backend uses scoped desktop registration instead of granting
  generic Quickshell configurations access to KWin window management.

- Aligned application-picker details at the left beneath a larger results list.
- Added item-order arrows with retained selection and pending Apply/Close behavior.
- Keep the dock revealed with a temporary Top-layer request while configuring,
  restoring its normal policy and prior visibility after closing settings.
- Reorganized dock settings into a narrow themed category sidebar and wider
  main content, with + Add Item at the top left and Reset defaults at the bottom.
- Added Apply, Accept and Close with pending edits: save without closing, save
  and close, or discard. Application additions and resets stay pending until
  saved; unrelated external dock settings remain current.

## Development history — 2026-10-11

- Added Items/General settings navigation and an application-only Add item dialog.
  Native KDE discovery and search fill application metadata; discard leaves the
  dock unchanged and confirmation pins once with live persistence. Existing preset
  launchers remain compatible; pin updates preserve unchanged delegates.

- Enabled Quickshell's system-style and QApplication startup options so KDE's
  native desktop controls can style the settings window. Bound the settings
  surface and font to Kirigami's Window theme, preserving user style overrides.

- Replaced dock settings checkboxes with native switches for magnification,
  click bounce and reduced motion, preserving live settings and keyboard input.

- Enlarged the dock settings window to a preferred 40 by at least 32 Kirigami
  grid units, with theme-derived spacing between control groups. Content growth,
  screen-height capping, scrolling and user resizing remain supported.

- Added native KDE Places for file-manager launcher menus, with hidden-place
  filtering, grouped navigation and expandable entries. Other applications retain
  recent files. Menu section headings and separators use shared theme metrics.

- Stabilized the dock's transparent client allocation across context-menu changes
  to avoid resize-related flicker and hover resets. The visible dock height,
  bottom baseline, input regions, reserved space and auto-hide edge remain distinct
  from that allocation.

- Fixed launcher interaction while a context menu is open. The shared-window,
  nonmodal popup allows live hover magnification and opening another application
  with a single click, preserving dock height/baseline and limiting its input
  region to the dock and menu.

- Added native KDE recent files to launcher menus, with scoped history clearing,
  KIO document opening, eligible new-window actions and reactive dock unpinning.
  Shared menu rows now follow Kirigami spacing, icon sizes and system font metrics.

- Replaced the dock menu window with an icon-relative Quickshell PopupWindow.
  Shared the tooltip balloon silhouette, removed inactive row backgrounds,
  and retained KDE desktop actions. Removed the Plasma Dialog import causing
  startup thread/property warnings and the unrequested shortcuts.
- Added per-application desktop actions discovered by KService and executed by
  KIO, using the menu window's input serial for Wayland activation.

- Replaced generic desktop-entry execution with a native Qt/KDE launch module
  using KService, KIO startup jobs, and asynchronous Wayland activation tokens.
  Added isolated completion/error checks; real KDE cursor feedback remains unvalidated.

- Slowed the hover wave and the auto-hide slide for a softer feel while keeping
  pointer tracking continuous. The slide now has its own duration instead of
  sharing the click bounce timing.

- Changed auto-hide to an edge-directed slide with eased reversal and KDE timing.

- Added automatic dock hiding with an interruptible transition and bottom-edge reveal.
  The hidden window shrinks to a transparent theme-derived input strip.

- Added a dock context menu with Configure Dock instead of opening settings on right-click.

- Added a separate themed dock settings window with live visibility, icon scale,
  zoom, bounce and reduced motion.
- Removed the unrequested checkbox/Up/Down launcher editor. Item configuration
  will follow Punchi Dock.
- Added validated JSON preference persistence and scoped configuration entry points.

- Established Punchi Dock Quickshell as a modular Quickshell/QML project targeting KDE.
- Added a fixed-icon dock with selection, keyboard navigation, and scoped dismissal.
- Added safe foreground start and restore scripts while keeping Plasma untouched.
- Adapted reusable agent workflows and added component/session validation tooling.
- Added five KDE sample apps for eight interaction-only launchers.
- Adapted Punchi Dock's horizontal zoom wave and high-resolution theme-icon sizing.
- Kept magnified icons, hover/focus frames, and hit targets together.
- Added themed speech balloons and a horizontally expanding dock background.
- Reused the background MSAA pattern through one shared surface primitive.
- Added reactive KDE animation preferences and wave/rendering regressions.
- Connected configured desktop entries through a launch service and adapter.
- Reused the original two-hop click bounce with coalesced feedback and reduced motion.
- Added launch-sentinel checks and real dock activation validation.
- Derived compact screenshot-inspired geometry and tooltip measures from Kirigami.Units.
- Added a read-only standalone KDE window-access probe and capability-state tests.
- Recorded KWin's rejected Quickshell window-management access without treating
  its empty model as successful intersection detection; hiding remains pending.
- Added temporary overlay, reserve, and desktop layer/space modes with live scoped IPC.
- Added actual Wayland protocol checks for layer and base-only exclusive-zone updates.
