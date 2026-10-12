# Changelog

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

## Unreleased — 2026-10-12

- Fixed the saved presentation mode reverting after a Quickshell reload. The
  session snapshot was held as a property value, which Quickshell's reloader does
  not match, so the start-mode override re-applied on every reload and overwrote
  live changes. SettingsStore is now a non-visual `Singleton` so the session can
  be a real child that survives a reload. `settings_reload` passes.

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

## Unreleased — 2026-10-11

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

- Established Punchi Shell as a modular Quickshell/QML project targeting KDE.
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
