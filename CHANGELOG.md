# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
No version has been published yet: the repository carries no tag and no release.
The tree prepares `0.2.0-beta.1` as its first pre-release; `0.1.47` remains
the legacy development baseline. New pending work accumulates under `Unreleased`.

## Unreleased

### Added

- Add a read-only **Do Not Disturb** row to the top-panel quick controls. It
  shows Plasma's effective `Inhibited` state and opens Plasma's notification
  settings; no public setter exists for Plasma's persistent mode, so the panel
  does not fake a switch or take over notifications.
- Add a **Now playing** row to the top-panel quick controls through Quickshell's
  public MPRIS service. It prefers a playing player, shows the announced track
  and artist, enables only the previous/play/next actions the player reports, and
  hides when the session has no player.
- Add top-panel **brightness** through PowerDevil's per-display
  `org.kde.ScreenBrightness` interface. The quick controls show the internal
  display first, clamp the slider to the provider range, confirm the value by
  reading it back and disable the row when no controllable display exists. There
  is no generic sysfs write.
- Add an optional top panel, off by default, with **Settings → General → Show top
  panel**. One bar per screen selected for the dock reserves its height and hosts
  a Punchi menu (Applications and Dock settings), KRunner search, a quick-controls
  center and a clock with a monthly calendar. Disabling the switch, removing a
  screen or stopping Punchi releases the surface, its popups and the reserved
  space without restarting. The optional `topBarEnabled` profile field keeps the
  format version; a profile without it restores the panel off.
- Add top-panel quick controls that report only provider-confirmed state: PipeWire
  volume and mute of the default sink, NetworkManager Wi-Fi through Quickshell,
  BlueZ Bluetooth adapter presence, power and blocking, and removable UDisks2
  storage. Credentials, pairing and device configuration stay in KDE; storage
  distinguishes unmounting one filesystem from safely removing a whole drive,
  never forces, ejects or powers off, and keeps busy, rejected and disconnected
  results explicit.
- Right-click a PunchiMenu tile, or press the Menu key on the current cell, for
  the application's own actions: the desktop entry's actions, Places, Recent
  Files with Forget Recent Files, Open New Window, Pin to Dock or Unpin from
  Dock, and Edit Application through KMenuEdit. Each row appears only when KDE
  reports that capability for the application.
- Make a minimized window travel to the dock icon: the window helper publishes
  each launcher's resting rectangle through KWin's minimize-geometry protocol, so
  the compositor's effect targets the matching icon. It is independent of the
  opt-in icon reaction and falls back when the helper or protocol is unavailable.
- Add an opt-in **Settings → General → Minimize reaction** with **Slow bounce**
  and **Lateral ripple**. When a window minimizes, the dock reacts on the icon of
  its application, using KDE's window model so multiple windows keep one icon;
  reduced motion disables the reaction. The profile schema advances to version 17.
- Add a **Menu → Right-click menu text shadow** switch, on by default, for the
  dock's right-click menu only. Turn it off for readers who find the doubled edge
  harder to read. The fullscreen menu, folder and recent containers and Fan rows
  keep the 0.25 shadow independently.
- Scroll overflowing fullscreen-menu labels on pointer or keyboard selection,
  matching the popup entries.
- Close the fullscreen menu with Escape from the search field or a selected
  tile.
- Add a configurable global shortcut for the fullscreen menu. It is empty by
  default and opens on the pointer screen when allowed, then on the last used,
  selected or primary screen.
- Allow hiding the fullscreen-menu close button. Right stays the default, and
  Escape, the backdrop and the dock button still close the menu.
- Right-click the PunchiMenu icon in the dock for a balloon list of installed
  applications, with Remove from Dock, Show PunchiMenu and Configure PunchiDock
  at the bottom. The balloon sizes to its content under the shared 24 grid-unit
  cap, and long names use the label carousel. **Show menu button** in Settings →
  Menu restores a removed icon; the global shortcut and IPC commands still open
  the menu.

### Changed

- Release the settings view one second after the window closes, once pending
  focus and layout callbacks have settled. Reopening within that second keeps
  the view; after it, the settings pages are destroyed instead of staying
  resident for the rest of the session.
- Create each fullscreen menu window only when its screen opens the menu, keep
  it through the closing fade and release it afterwards. An isolated one-screen
  measurement dropped startup PSS from about 180 MB to 177 MB; opening and
  closing the menu kept the same footprint.
- Create the dock context, folder and recent popups on first use through
  Quickshell's `LazyLoader`, so a dock that never opens them does not keep their
  content trees at startup. An isolated one-screen measurement dropped startup
  PSS from about 201 MB to 183 MB; the popups stay loaded after the first use.
- Release the fullscreen menu's catalogue search index and row model when the
  menu is unmapped, so a closed menu no longer keeps its delegates alive. An
  isolated one-screen measurement dropped PSS by about 11 MB while closed, open
  and after close, and three open/close cycles did not grow.
- Load the settings view on the first open instead of at shell startup, so a
  session that never opens settings does not keep every page alive. An isolated
  two-screen measurement dropped PSS from about 298 MB to 267 MB; the view stays
  loaded after the first open.
- Adopt a shared strong ease-out curve for the fullscreen menu, the popup family
  and the auto-hide slide, so these surfaces settle into place instead of
  marching and the dock leaves immediately instead of hanging before it snaps.
  The menu and its backdrop now share one open and one close duration, and hover
  fills use a gentler ease. The curve set lives in `config/PunchiMotion.js`; the
  dock wave and the two-hop bounce keep their current profile.
- Open the folder and recent-container view choices as submenus with a **Back to
  menu** row, and restore the Remastered icons for the view and sort rows.
- Apply the 0.25 theme-aware text shadow to the fullscreen-menu distribution
  name, matching the application labels.
- Fit the fullscreen menu to the seven-column, five-row reference with a
  proportional scale: rectangular cells, a square hover and selection card
  inside each cell, whole rows and centred margins so no tile is clipped.
  Application icons keep the reference size and category headings use one row.
- Set fullscreen-menu labels to 14 px with the same 0.25 theme-aware text shadow
  as the popup entries.

### Fixed

- Clear the style background on the top panel's popups so the shared
  balloon surface draws its rounded body and tail in the Punchi menu, the
  control centre and the calendar instead of a flat rectangle.
- Pin the top panel's quick-controls popup to the right edge of its
  screen. Its anchor binding did not follow the trigger's layout position, so it
  could open at the left edge instead of under the control-centre button.
- Stop a running installed copy before an install/update replaces it, then
  restart the updated copy automatically unless `--no-restart` is passed, so
  the new native plugin loads instead of the previous process keeping deleted
  libraries mapped.
- Reject a symlink, directory, FIFO, socket or device at the window-state
  registration path before opening it, so a foreign special file can no longer
  block `--register` or be removed. A non-Punchi regular file stays preserved.
- Discover Squash from KWin's `X-KWin-Exclusive-Category=minimize` metadata as
  well as the nested `exclusiveGroup=minimize` used by Magic Lamp, so both
  installed minimize effects appear in the selector and enter the recovery
  snapshot.
- Measure a settings save in UTF-8 bytes before replacing the profile, so a
  multibyte snapshot can no longer pass the 256 KiB guard and then fail to load
  on the next start. An over-limit save keeps the previous readable file.
- Run every isolated CTest probe against the build tree under test.
  `run-isolated.py` now receives `--build-dir`, exports it to child probes, and
  the setup-script and install mocks no longer inherit an external
  `PUNCHI_BUILD_DIR`; a focused regression uses two temporary trees to prove the
  selected QML artifacts.
- Install `scripts-user/lib/build-dir.sh` with the CMake layout, so the installed
  `start.sh` no longer stops with a missing-helper error. The install regression
  now invokes the installed `start.sh` and `restore-kde.sh` and verifies that
  startup resolves the installed QML plugin and backend.
- Persist the KWin minimize-effect recovery record before the first `kwinrc`
  write. A failed record save now leaves the shared configuration clean, and a
  failed `kwinrc` sync discards the unconfirmed writes while keeping the record
  for retry, so an effect selection cannot be applied without a recovery record.
- Search PunchiMenu by the desktop entry's generic name, keywords and desktop id,
  so `gimp` finds GNU Image Manipulation Program instead of only matching its
  long display name.
- Resolve the dock context menu's window actions by the application's desktop
  ID, so Close, Minimize and the other window commands appear for running apps.
- Offer only local KDE Places schemes (`file`, `trash`, `recentdocuments`,
  `activities`); a remote or custom KIO scheme is no longer passed to the
  launcher.
- Cap a folder listing at 5,000 entries, so a huge directory or an accidental
  mount point cannot fill the popup and its icon requests.
- Show application labels when the fullscreen menu opens before its surface is
  measured.
- Open the PunchiMenu dock balloon without the Qt SVG buffer warning: popup rows
  draw icons from a 64 px source and scale the scene transform instead of
  rasterising complex icons at 16 px.
- Quote the autostart icon path and escape control characters in its `Exec`
  value, so a checkout path with a newline cannot inject a desktop-entry key.
- Build the folder-container location with `QUrl::fromLocalFile`, so a configured
  path containing `#` or `?` opens instead of failing closed.
- Read the autostart entry through a 16 KiB bounded reader that rejects FIFOs,
  devices, oversized files and symbolic links before opening, so a foreign path
  cannot stall startup or be adopted.
- Remove a stale build tree only when its CMake cache names this checkout, so a
  `PUNCHI_BUILD_DIR` pointing at another project is never deleted.
- Treat an autostart entry as owned only when it carries the exact ownership
  marker and the exact launcher command, not when a foreign file merely contains
  the marker text.
- Check shell removal commands in the validation graph: a quoted variable followed
  by `/*` and a recursive removal without `--` fail the run.

## 0.2.0-beta.1 — 2026-11-11

### Added

- Add the fullscreen application menu: one overlay surface per screen, a dock row
  that opens it, search across name, title and description, and alphabetical,
  manual or category order.
- Add continuous scrolling to the fullscreen menu, with a wheel gesture that
  settles on the nearest row boundary, and keep the dock above the menu while it
  is open.
- Draw the menu close control with the user's window decoration and fall back to a
  theme icon when it is unavailable.
- Add per-screen and per-desktop placement: choose screens, virtual desktops and
  activities, keep the selection across hot-plug, and fall back to the primary
  screen while no selected screen is connected.
- Add a built-in Home folder container and a recent-applications container with
  Grid, List, Detail and Fan presentations.
- Add a Profile category that imports and exports a portable JSON profile.
- Resolve the first-run Browser item through KDE's preferred application instead
  of assuming Firefox is installed.
- Refuse to install or launch outside KDE Plasma on Wayland, and report an
  unsupported session at startup with a native system dialog.
- Add per-screen dock IPC commands alongside the existing primary-screen methods.

### Changed

- **Breaking:** Rename the public QML types to the `Punchi` prefix and empty the
  naming baseline. The native `Punchi.Kde` module keeps its own class names.
- Keep one emphasis band across the dock menu, container menu, folder arc and
  fullscreen menu, shared by pointer and keyboard.
- Persist every menu setting, including application order and the scroll bar, and
  move menu settings into their own category.
- Advance the profile schema to version 16. It adds per-screen, per-desktop and
  per-activity placement, the recent-applications container presentation, the
  application order and the menu scroll bar; version 15 profiles migrate
  `menuShowPageArrows` to `menuShowScrollBar`.
- Create one menu row delegate per section row instead of one per application, so
  the fullscreen menu stays responsive with 1000 applications
  ([#67](https://github.com/PunchiSoft/punchi-dock-quickshell/pull/67)).
- Keep the placement controls in the single-column settings card and scroll long
  pages inside the fixed window.
- Compress the dependency report, ask one decision at a time, and install the
  validation packages with the runtime and build groups.
- Treat Ctrl+C and a session logout as a stop without reporting an exit-status
  failure.
- Load the dock on the KDE stack Debian 13 ships, including Qt 6.8, KF6 6.13 and
  Plasma 6.3.

### Fixed

- Open the fullscreen menu at the top instead of at the last hovered cell.
- Keep full application and category rows visible across display sizes, and
  apply row snapping immediately when reduced motion is enabled.
- Paint the keyboard selection in the fullscreen menu and let a pointer that
  enters a cell continue keyboard navigation from there.
- Restore the container context menu, and stop the dock background menu from
  opening with a stray divider.
- Start the first-run Home container with Browse subfolders off.
- Correct the Debian runtime package mappings and offer the matching backports
  source with explicit confirmation.
- Name an invalid repository signature with the commands that correct the system
  clock, and name the next step when no package map exists.
- Load the settings user header with Kirigami Addons 1.16.
- Keep the dock visible when its edge borders another screen and inner-edge
  auto-hide leaves no strip to reveal from.
- Restart the assistant after updating the checkout so the post-pull action reads
  the new checkout.

## 0.1.47 — 2026-10-27

_Unpublished development baseline; this was not a released version._

- Add a **Made with love** section to the About page. It states that this is a
  native port of the Punchi Dock Remastered plasmoid, made for the community and
  built to go past what a plasmoid can do in KDE Plasma, links the original
  plasmoid, and closes with **Linux for everyone!**.
