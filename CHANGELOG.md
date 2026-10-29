# Changelog

## Unreleased

- Record and enforce the component naming convention. `AGENTS.md` defines the
  `Punchi` prefix, the surface level that disambiguates two owners
  (`PunchiDock*`, `PunchiMenu*`) and the reserved QtQuick.Controls names, so
  "menu" means the application menu and a dock item is not called a launcher.
  `tests/naming_test.py` (`component_naming`) checks the rule against
  `tests/naming-baseline.json`, which lists the 119 types written before it and
  may only shrink; a new non-compliant type, a shadowing name or a stale entry
  fails the build.

- Correct the Debian runtime package mappings, recognize Quickshell installed
  outside package management and install it from Debian backports.
  `scripts-user/lib/setup-deps.sh` checks Debian 13's actual package names
  (`qml6-module-org-kde-desktop`, `libkf6service-bin`, and
  `libplasmaactivitiesstats1`) instead of unverified placeholders, treats the
  Quickshell package as satisfied whenever `qs` is already on PATH, and, when
  Debian has no Quickshell candidate in the configured suites, offers to enable
  the matching `<codename>-backports` source with an explicit confirmation
  before installing it. Declining that offer keeps the other missing packages
  installable because a package without a candidate no longer aborts the whole
  `apt-get` call.
- Load the dock on the KDE stack Debian 13 ships. `CMakeLists.txt` requires
  KF6WindowSystem 6.13 and `DesktopLauncher` falls back to
  `KWaylandExtras::requestXdgActivationToken()` until 6.19 provides
  `xdgActivationToken()`, `DockItemCatalog` publishes its own role names because
  Qt 6.8's `QConcatenateTablesProxyModel` has none, and `UpdateState` skips the
  PackageKit and fwupd queries when the system bus is unavailable. The settings
  sliders drop `Kirigami.StyleHints`, which only exists from Kirigami 6.24;
  its default already disables tick marks, so nothing visual changes.
  `WindowModels.qml` follows the active desktop through
  `filterByVirtualDesktop` and `VirtualDesktopInfo.currentDesktop`, available
  from Plasma 6.3, instead of Plasma 6.7's `filterByCurrentVirtualDesktop`.
- Group the build trees under `build/`. The setup, the start script, the restore
  script, the developer scripts and the tests resolve `build/build-<ID>` (for
  example `build/build-debian`), `cmake --preset dev` writes the generic
  `build/dev` tree, and the flat `build-<ID>` and plain `build/` trees of the
  earlier layouts are still read when they are the only complete ones, so testing
  several systems never reuses another one's objects or CMake cache while the
  checkout stays ordered. `PUNCHI_BUILD_DIR` overrides the location and is
  validated before it is used or removed, `scripts-user/lib/build-dir.sh` owns the
  rule, and a stale cache naming a tool this system lacks is discarded before
  CMake reconfigures.
- Offer the recent applications as a container. **Presentation** in General now
  chooses between the extra launchers and one item with the fixed `folder-temp`
  glyph that opens a container with the same entries; the container is the new
  default and its **Container view** chooses Grid, List (the default), Detail or
  Fan, reusing the folder container presentations. A side dock presents a stored
  fan as Grid without rewriting it, the item appears only while KDE history has
  an application to show, and its menu switches the view. Launches go through
  the selection itself, so an application that is also a first-run preset row
  still opens and records the access; the pinned and open-window exclusions keep
  applying inside the container. The container presentation primitives move from
  `modules/folders` to `components/` now that a second consumer confirmed them,
  and the profile format advances to version 13 with the two new fields.
- Open the browser this session prefers from the default **Browser** item. The
  first-run catalogue names a role instead of a desktop entry: an empty
  `desktopId` plus the ordered MIME types `x-scheme-handler/https`,
  `x-scheme-handler/http` and `text/html` let `ApplicationCatalog` publish the
  `storageId` that `KApplicationTrader::preferredService` returns, so a first run
  never assumes Firefox is installed and follows the default chosen in KDE
  System Settings, including a replaced or removed one. The item shows the
  resolved application's icon, launching, running markers, window actions and
  media control keep receiving one real desktop id, and the resolved application
  is still offered once in the application picker.
- Start the first-run **Home** container with **Browse subfolders** off. Its
  standard user folders are places to go, so a selected folder opens in the file
  manager instead of replacing the listing; Downloads, containers added later
  and every stored profile keep their own value.
- Show one emphasis band at a time in the dock menu, the container menu and the
  folder arc. These rows have no durable selection, so the pointer and the
  keyboard now share a single band: the surface that receives both publishes
  `pointerEmphasis`, real pointer motion takes the band, a Tab, Backtab or
  Shortcut focus reason releases it, and every row binds its hover and focus fill
  through that flag. Opening a popup with the pointer forwards the pointer's
  focus reason instead of forcing `Qt.TabFocusReason`, which used to paint a
  keyboard band under a pointer that had not moved. `emphasis_contract` fails the
  build when a row drops the gate or when the initial focus hardcodes a keyboard
  reason.
- Restore the container context menu. The menu read a self-referencing settings
  property, so the folder section (sort, presentation and open actions) and the
  menu motion were missing; the popup now reads the dock settings.
- Add per-screen and per-desktop placement. Every connected screen owns a dock
  window backed by one shared runtime: the application catalog, window backend,
  update tracker, Trash state and KWin minimize controller are created once
  instead of once per screen. **Screens and desktops** in General chooses all
  connected screens (default) or a multi-selection, keeps the configured screen
  selected across hot-plug, and falls back to the system primary screen while no
  selected screen is connected. The dock no longer follows the screen where it
  happens to be launched.
- Keep the placement controls in the established single-column card
  distribution. The settings window uses the macOS-derived 54u × 38u Kirigami
  reference (screen-capped, 14u minimum) and reinstalls it whenever it is
  opened, so a compositor-remembered or dragged size cannot replace it. Pages
  scroll inside the reference instead of resizing the window when optional
  screen, desktop or activity rows appear. Pages use the shared thin
  `PopupScrollBar` (no trough) kept visible at rest, anchored to the reserved
  right gutter; scrolling and the indicator remain, but the vertical groove line
  no longer crosses the cards. Each selection list sits directly below its
  selector with a small caption, so the generated options are no longer one
  unordered block. An unplugged saved screen stays visible as **Not connected**,
  and the screen showing the dock meanwhile is marked **Fallback** instead of
  the card looking as if the missing monitor were still selected. With one
  connected screen, **Show dock on** and its screen list are hidden when they
  offer no choice; the saved profile is unchanged, and the row returns when a
  second screen is connected or a saved selection needs the **Not connected** /
  **Fallback** explanation.
- Add virtual-desktop and KDE activity visibility. All desktops and activities
  are visible by default; selecting specific ones hides the dock on the others
  without reserving screen space, without registering the edge reveal trigger,
  and without closing the window, so returning to an allowed desktop restores
  the configured mode. An optional switch makes running markers and transient
  rows follow the current desktop and activity while pinned items stay visible.
  The window backend now publishes `activities` and `currentDesktopIds` from the
  active desktop/activity. Without that backend, filtering degrades to "all".
- Keep the dock visible when its configured edge borders another screen and
  `avoidInnerEdgeAutoHide` is enabled: an edge mode would have no free strip to
  reveal from, so that dock stays visible while other screens keep their mode.
- Move the dock command surface into one `DockIpc` coordinator. The previous
  `dock` methods keep working on the primary screen, and `screenKeys`,
  `snapshotFor`, `revealFor` and `focusFor` address a specific screen.
- Bump the saved profile to version 12 with `screenMode`, `selectedScreens`,
  `desktopMode`, `selectedDesktops`, `activityMode`, `selectedActivities`,
  `runningMarkersFollowDesktop` and `avoidInnerEdgeAutoHide`. Version 11 profiles
  load with the new defaults, and imported profiles validate every new field.
- Add a **Profile** category that imports and exports a portable JSON profile of
  dock items, folder containers and preferences. `config/DefaultProfile.js` is
  now the single first-run source for the launcher catalogue, pinned order,
  containers and preferences, so a fresh install and **Reset defaults** use the
  same data. Import accepts the portable document or a raw saved profile,
  validates every field, previews the result and keeps it pending until Apply or
  Accept. A profile carries data only, never executable JavaScript, autostart,
  KDE configuration or user files. The selected file must be a regular UTF-8
  file of at most 256 KiB; exports are written atomically with owner-only
  permissions and a symbolic link is never overwritten. The card states what a
  profile includes and what it leaves out. Applying a profile now
  writes the settings file once instead of once per property.
- Add a built-in **Home** folder container to the first-run profile. It sits
  between Konsole and Firefox, uses `user-home`, opens as Fan and sorts by name.
  Home resolves through `QStandardPaths::HomeLocation` and lists only the
  existing standard KDE/XDG user folders (Desktop, Documents, Downloads, Music,
  Pictures, Public, Templates and Videos), so localized folder names and custom
  `user-dirs.dirs` settings work on any KDE account. The filter turns off when
  navigating into one of those folders. Downloads keeps its Grid default before
  Trash. Existing saved profiles keep their containers and pin order.
- Adopt release-based versioning. Pending changes accumulate here; a release
  moves them under a dated heading and advances the version once. Documentation,
  tests, CI and repository metadata alone do not change the version.
- Update both READMEs to the current feature set, state that Punchi Dock
  Remastered is the project's base, and add the **Made with love** dedication.
- Refuse to install or launch outside KDE Plasma on Wayland at the point where
  nothing has been written yet. Install and trial check the session before
  building, name the detected desktop, distinguish *Plasma not installed* from
  *Plasma installed but not the current session*, and ask once for confirmation
  (`PUNCHI_ALLOW_NON_KDE=1` skips it). A session without a graphical display is
  installed for later use instead of being blocked.
- Report an unsupported session at startup with a native system dialog. The
  guard shares one detection library with the setup assistant, names the detected
  desktop and display server, covers a KDE session without Wayland, and exits
  with status 3. `kdialog`, `zenity` and `xmessage` are tried in that order, the
  same text always reaches stderr, the application-menu launcher does not repeat
  the notice when the dialog was displayed and keeps its notification when no
  dialog tool exists, `PUNCHI_NOTICE_DIALOG=0|1` controls the dialog, and the
  desktop value is treated as untrusted input instead of being pathname-expanded.
- Treat Ctrl+C and a session logout as a stop. The trial phase reports
  `Run: Stopped` with the line `The trial stopped.`, a started dock reports
  `The dock stopped.`, and the trial confirmation now reads as ending the trial
  instead of removing "what the trial created". Nothing is reported as an exit
  status failure for 130/143, the cleanup still runs, and the exit status is
  preserved for `--test` callers.
- Compress the dependency report. Build and trial phases print one summary row
  per section with ready counts and expand only the missing items, without the
  check title, the distribution line or the rules the phase line and the setup
  header already provide, which turns a forty-eight line block into seven lines;
  "Check runtime and build dependencies" keeps the full inventory, now laid out
  in columns sized to the terminal and falling back to one item per line when the
  window is narrow.

## 0.1.47 — 2026-10-27

- Add a **Made with love** section to the About page. It states that this is a
  native port of the Punchi Dock Remastered plasmoid, made for the community and
  built to go past what a plasmoid can do in KDE Plasma, links the original
  plasmoid, and closes with **Linux for everyone!**.

## 0.1.46 — 2026-10-27

- Isolate the trial run. "Try it without installing" exports an absolute trial
  profile inside the instance runtime directory, and `SettingsStore` and
  `AutostartService` honour `PUNCHI_PROFILE_DIR`, so a trial starts from the
  default dock items and never reads or rewrites the preferences an installed
  copy owns. The **Start with KDE Plasma** switch stays disabled during a trial,
  with a note saying that a trial cannot start at sign-in.
- Ask once after the trial. When the dock exits, including after Ctrl+C, the
  assistant asks one confirmation and then removes the build output, the trial
  profile, the window-state registration and the runtime lock. The installed
  copy, its preferences and the source checkout stay untouched. A trial refuses
  to start while this checkout is already running, and the cleanup never acts on
  a running copy, so it cannot delete the build output or the registration an
  open dock is using.
- Replace the uninstall questionnaire with one choice: **Keep my data** keeps the
  previous three questions, and **Remove everything** deletes the preferences,
  the legacy `punchi-shell.json`, the build output, the runtime lock and the
  window-state registration behind one destructive confirmation.
- Remove the leftover window-state registration. Uninstall unregisters
  `org.punchi.Shell.WindowState.desktop` through the native backend, and deletes
  it when its content still matches this project, so an uninstalled copy no
  longer leaves a dangling entry in the application menu.

## 0.1.45 — 2026-10-27

- Move the update badge to the icon's lower-right corner, the place KDE gives its
  update notification dots, so the upper-right area stays clear for the window
  controls. The centre keeps its `badgeInset` overlap, and the badge no longer
  drifts upward against the dock edge while the icon magnifies.
- Follow the install instead of the clock. `UpdateState` watches PackageKit's live
  transaction list, reports `updating` while a transaction with the
  `update-packages` or `upgrade-system` role runs, and re-checks as soon as it
  ends. `InstalledChanged` joins `UpdatesChanged` and fwupd's `DeviceChanged`, a
  change that arrives during a check queues one replay instead of being dropped,
  and no check starts while an install holds the PackageKit lock.
- Show the tray's own state while installing. The disc paints the Breeze
  `update-busy` glyph without the number, keeps the neutral fill and stays until
  the re-check settles, so the count the user just applied is never painted
  again. The Discover icon, the click target and the motion profile are
  unchanged, and reduced motion behaves as before.
- Count security updates correctly. PackageKit reports them as info
  `SECURITY` = 8 (`NORMAL` is 5), so the red `update-high` fill could never be
  reached; the constant, its test and the record now use the value observed in
  live `Package` signals.

## 0.1.44 — 2026-10-26

- Show pending updates on the Discover launcher. Discover publishes no update
  state over D-Bus, so the badge reads the same sources Discover uses: PackageKit
  `GetUpdates` on the system bus with a `background` hint, fwupd `GetDevices`
  plus `GetUpgrades` for every updatable device, and
  `flatpak remote-ls --updates --cached` for local metadata. The query is
  read-only: no install, no `RefreshCache`, no authorization prompt and no
  network. A missing service contributes zero instead of an error, and the
  aggregate settles to `Ready` or `Unavailable`.
- Carry the badge with the icon, on its corner. The counter is a child of the
  launcher tile, so the existing magnification scale and translate move it
  instead of leaving it behind. Its centre sits on the icon's upper-right corner,
  inset by `Kirigami.Units.smallSpacing` so the disc overlaps the icon like a
  system notification badge; the first offset used `iconSize / √2` on both axes,
  which put it past the corner and left a gap that grew while magnified. Size,
  font, halo width and durations are Kirigami values — `iconSizes.small`,
  `Theme.smallFont`, `smallSpacing`, `shortDuration` and `veryShortDuration` — so
  no arbitrary pixel size or duration remains. The badge is laid out at the
  configured maximum magnification and counter-scaled, the same technique the
  icons use through `highQualityIconSize`, so the digits are downscaled at rest
  and drawn 1:1 at the wave peak, never upscaled. Entry and exit are opacity
  only; a new count while the badge is visible plays one bounded halo that never
  scales the number, and reduced motion removes the halo while keeping the final
  state.
- Follow the update front-end that is actually configured instead of assuming a
  distribution. `UpdateNotice` resolves the pinned launcher of the first supported
  front-end (`org.kde.discover`, then `org.gnome.Software`,
  `io.elementary.appcenter`, `update-manager`) and badges only that tile; a dock
  with none of them paints no badge. The data stays distribution-neutral:
  PackageKit names its own backend (`dnf5`, `apt`, `alpm`, `zypper` ...) and now
  reports it through `UpdateState.backendName`, alongside new
  `systemAvailable`/`flatpakAvailable`/`firmwareAvailable` flags.
- Use the color of KDE's update notification. The badge first read the item
  palette, which inside Quickshell resolves to the Qt Quick Controls fallback: a
  washed-out lavender disc with a dark number. It now uses the roles Breeze
  itself paints those notifications with — `neutralTextColor` (#f67400, the dot
  of `update-medium`) while updates are pending and `negativeTextColor`
  (#da4453, the dot of `update-high`) once a security update is present — with
  the number in `textColor`, the same glyph-versus-dot pairing as those icons.
- Say which update sources answered. The **Updates** note is no longer a fixed
  promise: it lists the sources from the last check, such as
  `Updates from dnf5 · Flatpak · firmware`, falls back to `system packages` when
  PackageKit reports no backend name, and hides itself while nothing is known.
- Report the count accessibly and let the user turn it off. The launcher
  description now reads "Running" and "N updates available" together, and the
  new **Updates** category in settings toggles the badge without a restart. The
  click target is unchanged: Discover still launches normally.

## 0.1.43 — 2026-10-26

- Ask for the pointing hand over every popup item. The dock context menu rows,
  the folder container rows of Grid, List, Detail and Fan, the folder header
  controls, the folder entry menu and the Empty Trash confirmation now change the
  pointer to the hand while the item can act, and keep the arrow when it cannot.
  Qt 6 has no `Item.cursorShape`, so each interactive control declares a passive
  `HoverHandler` whose `cursorShape` follows that control's own enablement. The
  hover band, selection emphasis, layout and keyboard profile are unchanged.
- Stop the folder listing from hiding that hand. The full-size `MouseArea` that
  caught the secondary click and forwarded the wheel also published its own arrow
  cursor over every row, so Grid, List and Detail kept the pointer instead of the
  hand. The gesture and the wheel now travel through a `TapHandler` and a
  `WheelHandler`, which request no cursor; the row menu, the wheel pace, left
  clicks and keyboard focus behave as before.

## 0.1.42 — 2026-10-26

- Size a folder list popup from what its rows can paint. The surface reserved the
  width of the longest entry name while every label paints at most the resting
  cap of ten glyphs, so a single long file name left a wide empty surface and a
  selection band spanning it. The surface now asks for the capped name and
  reserves the chevron column only while a navigable directory will paint it;
  long names still scroll through the existing carousel on hover or focus.

## 0.1.41 — 2026-10-26

- Move popup size, popup height and popup icon size out of General into their own
  **Popups** category between General and About. The three controls describe the
  popup surfaces rather than the dock's geometry, so the sidebar now reads
  Items, General, Popups and About, with About still pinned to the sidebar foot.
  The section glyph is a symbolic window, so every category icon follows the
  theme text color instead of carrying colors of its own. The page reuses the
  same responsive two-column section, the same control names and the same
  pending Apply/Accept flow; no popup value or default changes, and the dock
  context menu keeps its own metrics.
- Keep the About page reachable at its new index: the category indices are
  Items 0, General 1, Popups 2 and About 3, and focus restoration follows the new
  scroll page map.
- Give the grid, the list/detail rows and the fan their own glyph size. The fan
  reused the grid glyph with rows 1.33 icons apart, so a size that read well in
  the grid crowded the arc. The Icon size card holds three sliders that move in
  steps of two pixels with a pixel readout: 24–96 px for the grid, 24–64 px for
  the rows and 24–56 px for the fan; zero keeps the theme's token for that
  presentation. The stored record moves to schema 11, so a profile recorded
  earlier keeps its grid size while the arc returns to the theme token.

## 0.1.40 — 2026-10-26

- Keep the folder popup open while its listing changes. The entry model now
  ignores a row the listing no longer exposes instead of reading the source that
  already left, which crashed the dock while a grid or list delegate was being
  created. A native row-mapping test and a popup test that cycles every
  presentation around hiding and restoring an entry cover it.
- State that **Recent applications** lists applications only: the resolver
  refuses recent documents, folders and arbitrary URLs, and the selection proxy
  drops any row without an application identity. KDE's recent documents and
  places stay in the context menu sections, unchanged.

## 0.1.39 — 2026-10-26

- Give the folder popups, the dock context menu and its sections one visual
  language, taken from the native delegate: a pointer or keyboard band of the
  theme accent at 30 % with a one-pixel hairline, a solid highlight with
  highlighted text for a selection, and the native row radius. The dock menu now
  uses the same row instead of its own colours, and only one row ever paints a
  band: the pointer owns the emphasis until a key takes it back.
- End every folder presentation with the same **Open** row, as the reference
  does. Grid, List, Detail and Fan take it from the listing model, so it is
  reached with the arrow keys and carries the coloured `folder-open` icon; the
  footer button and the circular Grid cell are gone.
- Arrange the entries from the space the popup really has: a cost model prefers a
  wider-than-tall shape, counts whole visible rows and leaves scrolling as the
  last resort. The surface reserves the indicator strip only while it scrolls,
  and the slim thumb fades out while the listing rests.
- Mark a folder that the popup can enter with a trailing chevron, and offer
  **Open in File Manager** and **Copy Path** from a right-click or the Menu key on
  an entry. Copy Path writes through a clipboard service injected by the dock and
  stays disabled for a remote location.
- Add popup size, popup height and popup icon size to Dock settings (schema 10).
  The scale multiplies rows and cells, the height caps how much of the host a
  popup may cover, and the icon size sets the base glyph of a folder grid; an
  untouched profile keeps the theme's large icon. Every row, cell and indicator
  measurement now derives from Kirigami instead of a literal.

## 0.1.38 — 2026-10-26

- Pace the setup progress so the work is readable. On a terminal a step stays
  visible for at least 0.9 s, keeping the spinner running instead of flashing
  past, and the completion line holds 0.4 s before the next output.
  `PUNCHI_PROGRESS_MIN_SECONDS` and `PUNCHI_PROGRESS_SETTLE_SECONDS` tune both,
  failures still report immediately, and redirected output never waits.

## 0.1.37 — 2026-10-26

- Animate the dependency check. The report is collected behind the same
  progress line as the other long steps — spinner plus a bar that advances by
  section — and then replayed, so the check is visible before the listing
  arrives. Replayed rules match the real terminal, and re-checking after an
  installation no longer replays the previous report.

## 0.1.36 — 2026-10-26

- Give the setup assistant the presentation of the main Punchi Dock project: a
  boxed header with the version, distribution and installed RAM/CPU/build-job
  figures, a phase list for every multi-step action, and one animated progress
  line for the long steps that still records the complete CMake output for the
  failure log. The automatic build job count is now capped by installed memory,
  `-j/--jobs` stays the explicit override, and `PUNCHI_NO_PROGRESS=1` prints the
  raw command output.
- Add **Try it without installing** to the setup menu (`--try`, alias `--test`):
  it checks dependencies, builds the checkout and runs the dock from the
  checkout without writing an installation, an application-menu launcher or
  preferences. **Start the dock** now states that it needs an existing build or
  installation, and the dock runs as a child process so closing it returns to
  the menu instead of ending the assistant.

## 0.1.35 — 2026-10-20

- Keep recent KDE activity applications visible when Plasma reports no current
  activity. The history query falls back to every activity, ordered by most
  recent use, instead of the empty current activity that matched nothing. The
  fallback covers reading only: KDE still records new launches while an activity
  is active.

## 0.1.34 — 2026-10-20

- Group the **Add item to Dock** fields into the rounded settings card General
  already uses: one labeled block holds the type, name, icon, view, folder and
  entry list, and its surface follows the active KDE color scheme.
- Keep the form in place while the application result list is open. The list now
  overlays the fields from the typing row instead of pushing Icon and
  Description out of the card.

## 0.1.33 — 2026-10-20

- Rework **Add item to Dock** for applications. The result list stays closed until
  the name is typed or the search button is pressed, and it hangs from the typing
  row instead of the label column, so the form below keeps its place.
- Add a theme icon chooser to both item editors: a dialog with the categories the
  theme declares, a search field, captioned tiles and OK/Cancel. It opens from an
  application's icon button and from a popup container's, applies only on **OK**,
  and stores the chosen name per item (schema 8) with the application icon as
  fallback.
- Let a folder container keep entries out of its popup. The editor and the item
  details pane list the folder with one check box per entry, an unchecked entry is
  stored by name (schema 9), files that arrive later still appear, and **Show all**
  clears the list. The editor lists nothing until a folder is chosen.
- Enumerate the icon theme in a native catalog that scans off the GUI thread,
  caches the result per theme under `$XDG_CACHE_HOME/punchi-dock-quickshell`, and
  reports each repeated Qt SVG warning once instead of once per paint.

## 0.1.32 — 2026-10-20

- Fix every folder activation from the folder popup. The dock asked KDE for a
  Wayland activation token from the context menu, whose content has no window
  until that menu opens, so selecting a file, a folder or the location action
  was refused while the menu was closed. The activation now anchors to the dock
  window that received the input. The real Quickshell probe asserts that the
  anchor resolves to a visible window while the popup is open.

## 0.1.31 — 2026-10-20

- Add a per-container **Browse subfolders** switch to the folder details pane.
  With it on, selecting a directory enters it, as before; with it off, the same
  selection opens the directory in the file manager, so every entry still leads
  somewhere. Existing profiles keep entering subfolders, and the switch is
  offered only for folder containers, never for the Trash entry.
- Make the fan a leaf in every case: selecting a directory opens it in the file
  manager instead of replacing the arc with its contents, whatever the
  container's switch says.

## 0.1.30 — 2026-10-20

- Fix the recent-applications switch becoming permanently disabled after it was
  turned off. The card gated its own switch on a service state that disabling the
  list made false, so only editing the configuration file or Reset defaults
  restored it. Dock controls no longer depend on KDE's tracking preference: the
  note appears while KDE saves no history, and the switches stay usable.
- Keep the Activities consumer for the adapter's lifetime so `available`
  describes the KDE history service instead of the dock's display preference.
  Hiding the list now stops only the history query; dock launches keep being
  reported to KDE, so the list is complete when it is shown again.
- Replace the regression that asserted the disabled controls with cases that
  hide and show the list again and check that KDE's preference never disables a
  dock control.

## 0.1.29 — 2026-10-20

- Add Punchi Menu's hover pulse to dock popups. Context-menu rows, Places,
  recent files, window actions, media controls and the folder Grid, List,
  Detail and Fan presentations now share one hover surface: the fill fades and
  the row pulses to 1.03 in 95 ms, returning in 125 ms, exactly like the
  reference menu. Press travels through the same surface at 0.97, and leaving
  mid-pulse settles at rest, so interrupted gestures always end in the correct
  state.
- Keep hover and keyboard focus distinct, scale row content instead of the fill
  so the rounded surface and its ring stay crisp, derive the fade from the theme
  short duration instead of a fixed floor, and disable scaling while reduced
  motion is active.
- Recover the Punchi Dock Remastered motion pack as English skills: policy,
  fluid mechanism, audit catalog, per-frame cost and surface-effect levels,
  adapted to Quickshell and KDE Plasma/KWin.

## 0.1.28 — 2026-10-20

- Add a **Fan** presentation to folder containers. Entries unfold from the dock
  icon as one arc: every row leans a little more than the one before it, the
  room the leaned pills need is kept inside the popup instead of being clipped,
  and the row that faces the panel stays upright. The closing row opens the
  folder in the file manager. Only the rows paint: there is no card, title or
  close control, and the popup is placed from the glyph that faces the panel,
  so the arc grows out of the dock icon. Choose it in the container settings or
  the dock context menu beside Grid, List and Detail; the choice is stored per
  container and restored with the profile. A vertical dock has no near row to
  unfold from, so it keeps the stored choice and presents Grid, and its menu
  and selector do not offer the arc.
- Keep the fan within the space the display offers by dropping whole rows, keep
  its opening derived from one interruptible progress, and disable travel,
  scale and partial opacity when motion is reduced. The other presentations
  keep the balloon.

## 0.1.27 — 2026-10-20

- Add a **Remember application history in KDE** switch to the recent
  applications card. It writes only the two public states of
  `what-to-remember` (`0` all applications, `2` none) with the KConfig notify
  flag so `kactivitymanagerd` reloads immediately, and leaves KDE's
  per-application allow/block lists untouched.
- Add a **KDE recent files options** row that opens the `kcm_recentFiles`
  module, keep the reference note while KDE saves no history, and cover the
  writes, preserved lists, disabled controls and switch gesture with native and
  QML regressions.

## 0.1.26 — 2026-10-20

- Detect when KDE is configured not to remember applications
  (`what-to-remember=2` in `kactivitymanagerd-pluginsrc`) and watch that file so
  the state follows external changes. Recent-application settings disable their
  switch and count and show a short note explaining how to enable KDE tracking,
  instead of leaving controls that cannot have an effect. Skip notifying KDE of
  dock launches while it would discard those events.
- Clarify in the README and the local records that the recent list depends on
  KDE activity history and that existing history is not recovered by enabling
  tracking.

## 0.1.25 — 2026-10-20

- Add optional recent KDE activity applications as dock launchers, with a
  configurable count and exclusions for pinned and running applications.
- Refresh settings pages with shared card, row and separator components, and
  show the bundled license inside the About view.
- Package the native QML implementation library with user-local installs and
  configure relative library lookup for installed and CMake layouts.
- Record Fedora 44's Plasma 6.7.5/KWin 6.7.5 validation, clarify that Arch's
  successful initial start still needs prolonged-use validation, and mark X11
  as out of scope with no planned support work.

## 0.1.24 — 2026-10-19

- Make Places rows fill the available context-menu width instead of shrinking
  the hover/highlight background to their text width. Add a regression that
  compares a Places row against the section header width.
- Record current Arch rolling package versions checked on 2026-10-19
  (Plasma/KWin 6.8.0, Qt 6.12.0, KF6 6.31.0, Quickshell 0.3.2) while keeping
  Fedora 44 as the validated 6.7.5 set and marking the Arch combination as
  pending runtime and visual validation.

## 0.1.23 — 2026-10-19

- Align dock context-menu rows with the installed KDE `MenuItem` style:
  `focusColor` hover and press fill, a 1px focus border, the native corner
  radius and the native frame-contrast body border, while keeping keyboard
  focus as a separate outline.
- Isolate KDE Places and recent-file bookmark stores from the writable test
  data home so `places_runtime` cannot modify the real user
  `user-places.xbel`. Keep the public menu shape and tail contract intact.
- Document the native-first KDE policy and Plasma 6.8 capability review in the
  project skills without raising the declared minimum or claiming unverified
  6.8 support.

## 0.1.22 — 2026-10-19

- Add an optional **Start with KDE Plasma** switch to General settings. Apply or
  Accept writes an owned
  `$XDG_CONFIG_HOME/autostart/punchi-dock-quickshell.desktop` entry that launches
  `scripts-user/launcher.sh start`; Close discards the pending switch. The entry
  uses `OnlyShowIn=KDE;`, `X-KDE-autostart-phase=2` and takes effect at the next
  Plasma sign-in.
- Preserve foreign autostart files. The switch is disabled when the exact path
  exists without the Punchi ownership marker, and uninstall removes only a
  Punchi-owned entry.
- Add a Quickshell runtime regression for owned enable/disable and foreign-file
  preservation, plus a settings component regression for the draft/Apply/Close
  lifecycle.

## 0.1.21 — 2026-10-19

- Add a contextual details pane to Items settings. The dock list and the pane
  sit side by side on wide pages and stack in a narrow window; the pane shows
  the selected application, folder or Trash item, moves the folder path and
  Grid/List/Detail controls out of the list footer, and shows an explanatory
  note when there is no selection.
- Open the Items page without a preselected entry. The explanatory note is the
  initial state, row hover emphasis remains available until a row is chosen,
  and closing and reopening the window starts neutral again. If an external
  change removes the selected entry, its selection clears instead of moving to
  a neighbour.
- Present the settings categories with a large themed icon above a centered
  label, matching the sidebar hierarchy of the reference interface while
  preserving the existing selection highlight and keyboard focus.
- Keep the selected settings category as the only filled state. Category
  buttons no longer paint a pointer-hover background while another page is
  current. The single-emphasis rule is recorded in the `selection-emphasis`
  skill for future lists, tabs and delegates.
- After a successful interactive update pull, ask whether to rebuild and install
  the updated copy. The non-interactive `--pull` path still never rebuilds or
  installs on its own.
- Add a Spanish README translation (`README.es.md`) with a clear compatibility
  table and link both language versions.

## 0.1.20 — 2026-10-19

- Add a "Check for updates" menu entry and `--check-updates` option. It fetches
  the configured Git remote once, reports ahead/behind counts, the upstream
  declared version and the installed copy version, and suggests
  `git pull --ff-only`. The menu asks before pulling; `--pull` performs the
  fast-forward pull non-interactively. It refuses modified tracked files and
  never rebases, resets, stashes, rebuilds or reinstalls on its own. Git stays
  optional: the dependency report flags it only for update checks and prints
  the distribution install command instead of installing it.
- Resolve `qtpaths6`, `qmllint` and `qmltestrunner` from the distribution Qt bin
  directory when they are not on `PATH`, including `/usr/lib/qt6/bin`,
  `/usr/lib64/qt6/bin` and Debian multiarch paths, plus `QT_INSTALL_BINS` and
  the `PUNCHI_QT_BIN_DIRS` override. Arch no longer reports these tools as
  missing when they are installed.

## 0.1.19 — 2026-10-19

- Keep install/update and build-only from starting the dock implicitly. The
  setup menu returns after the action; use Start the dock or `--start` to launch
  it, so the installer no longer takes over the terminal.
- Keep the source checkout's `build/` directory when uninstalling. Removal now
  requires `--remove-build` or a separate confirmation in the menu.
- Offer to install missing dependencies before building, with Fedora,
  Debian/Ubuntu and Arch package maps. Non-Fedora mappings remain best-effort.
- Require and report KDE Plasma/KWin explicitly, and refuse to start the dock
  outside an active KDE session.
- Write a timestamped build-failure log under the user's Documents directory.
- Make `restore-kde.sh` stop the active Punchi Dock instance from either the
  checkout or the user-local installation.
- Check `kbuildsycoca6`, show stale installed versions in the menu, and keep the
  previous installation available for rollback when launcher writing fails.
- Route the application-menu entry through `launcher.sh`, which logs startup
  output, notifies on failure and provides Stop and Settings actions.
- Add an isolated install/uninstall regression test.
- Add CMake install rules, an `uninstall` target, a relocatable installed
  launcher, a desktop entry, an icon and a portable CPack TGZ configuration.

## 0.1.18 — 2026-10-19

- Added `scripts-user/setup.sh`, a guided menu and non-interactive commands for
  install/update, build-only, start, dependency checks, uninstall and help.
- Added a reversible per-user installation under
  `${XDG_DATA_HOME:-$HOME/.local/share}/punchi-dock-quickshell`, an application-menu
  launcher, an install manifest and an uninstall flow that stops only this
  project's configurations and restores owned KWin settings.
- Added Fedora dependency checks for runtime, build and validation packages,
  plus command checks that work on other distributions without claiming their
  package names are validated.
- Enforced a single Punchi Dock Quickshell instance across the source checkout
  and the user-local installation, and allowed the active installation to
  refresh its own window-backend registration without accepting unrelated files.
- Kept `start.sh` as the direct foreground launcher and documented its panel
  modes through `--help`.
- Reworked the README installation sections and the `scripts-user` overview so
  the setup path and its limits are explicit.

## 0.1.17 — 2026-10-19

- Suppress pointer-hover emphasis while a settings list has a selected item, so
  selection and hover do not render competing backgrounds.
- Record the single-emphasis rule in the UI and accessibility skills.

## 0.1.16 — 2026-10-19

- Show PunchiSoft as the project author and refresh the version displayed in the
  About page.
- Document the use of AI coding agents as development support.
- Requested an AI-assisted project and security review over a coffee before
  publication.

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
