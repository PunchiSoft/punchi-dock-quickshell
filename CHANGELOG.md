# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
No version has been published yet: the repository carries no tag and no release.
The tree prepares `0.2.0-beta.1` as its first pre-release; `0.1.47` remains
the legacy development baseline. New pending work accumulates under `Unreleased`.

## Unreleased

### Added

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
  at the bottom. **Show menu button** in Settings → Menu restores a removed
  icon; the global shortcut and IPC commands still open the menu.

### Changed

- Apply the 0.25 theme-aware text shadow to the fullscreen-menu distribution
  name, matching the application labels.
- Fit the fullscreen menu to the seven-column, five-row reference with a
  proportional scale: rectangular cells, a square hover and selection card
  inside each cell, whole rows and centred margins so no tile is clipped.
  Application icons keep the reference size and category headings use one row.
- Set fullscreen-menu labels to 14 px with the same 0.25 theme-aware text shadow
  as the popup entries.

### Fixed

- Show application labels when the fullscreen menu opens before its surface is
  measured.

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
