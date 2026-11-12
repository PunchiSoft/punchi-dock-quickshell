# Applications and windows

The core dock loop: pin applications, start them through KDE, bring an existing
window forward, and reach the actions KDE exposes for that application.

## Pinned applications

- Discover and search installed applications through KDE, add or reorder
  launchers, and save preferences.
- Eight preset application launchers plus the Home and Downloads containers and
  Trash form the initial configuration. The preset list is a default, not a
  requirement: every item can be replaced.
- A pinned item keeps its saved order. Unpinning updates the dock settings without
  modifying Plasma launchers.
- An item editor can choose a theme icon for a pinned application or folder
  container and store it by name, falling back to the item's own icon.

## Launching

- Native application launching through KService and KIO, with Wayland activation
  integration.
- A normal click activates an existing KDE window or minimizes an eligible active
  window before considering a launch.
- Startup launch coordination prevents a second normal launch while the
  application is starting.
- Window cycling and known running unpinned applications are implemented; an
  unpinned application with an open window can appear as a running entry without
  changing the persisted pins.
- Middle-click **New Window** uses the native new-instance request when a window
  exists and KIO otherwise.

Activation remains limited to the validated environment; physical KDE
foreground/restoration checks are pending. See
[Compatibility](../getting-started/compatibility.md).

## Context menus

A launcher's context menu combines, where the application supports them:

- **KDE desktop actions**, with hidden, separator and empty-command actions
  excluded. KDE supplies localized names and command parsing.
- **Recent documents**: the five most recent resources for the selected
  application in the current KDE activity. A cleared entry disappears from the
  model instead of being guessed. Clearing history uses the same
  application/current-activity query.
- **Unpin** and local dock pin settings.
- **Window actions** such as Move to Desktop, Maximize and Fullscreen for the
  selected application's window.
- **KDE Places navigation** for eligible file-manager launchers: the first group
  is inline, later groups open as navigation entries, and places that need device
  setup stay disabled.

The menu is a nonmodal control in the dock's own window, so outside presses
dismiss it and reach the clicked control in one interaction. Escape restores
focus. A pending open is cancelled when another launcher activates. Dismissal
and focus behavior are documented in
[Dock runtime](../architecture/dock-runtime.md#popups-and-context-menus).

## Running indicators

A themed dot marks pinned applications with open windows. The marker follows
window data only, never a launch completion or a clicked selection.

Running markers exist with isolated validation and remain in development;
physical KDE checks are pending. The snapshot also carries activities and current desktop IDs, so
the optional filter can follow the current desktop and activity while pinned items
stay visible.

## Not included

Task/window management beyond the documented actions is not ported. Close, Move
and More require the dedicated window-detection backend and are not implied by the
current menu. Drag-to-pin, drop targets and a separate task manager remain future
work; see [Features](README.md#not-implemented-yet).
