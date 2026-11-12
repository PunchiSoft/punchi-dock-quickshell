# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
No version has been published yet: the repository carries no tag and no release.
The tree declares `0.1.47` as its legacy development baseline, not a published
release. Pending work accumulates under `Unreleased`.

## Unreleased

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
