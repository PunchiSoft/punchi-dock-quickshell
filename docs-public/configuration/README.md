# Configuration

How to change the dock and how those changes persist. Settings are edited in the
dock's own window and stored per operating-system user; a portable profile can
exchange the same data between machines.

## Pages

- [Settings](settings.md): the settings window, its categories, defaults,
  persistence and schema versions.
- [Dock modes](dock-modes.md): placement, visibility modes, screens, virtual
  desktops and activities.
- [Profiles](profiles.md): export, import and preview of a portable profile.

## Opening the settings window

Right-click the dock and choose **Configure Dock**. With Punchi Dock Quickshell
running, `./scripts-user/settings.sh` also opens the window.

**Apply** saves pending changes without closing. **Accept** saves and closes.
**Close** discards pending changes. Untouched fields follow external changes;
explicit edits win field conflicts on commit.

Settings update existing surfaces through bindings and notifications, without a
restart. The exceptions are the startup pragmas described in
[Architecture overview](../architecture/overview.md#startup-configuration), which
need a new process.

## Where preferences live

Preferences are stored separately for each operating-system user in
`$XDG_CONFIG_HOME/punchi-dock-quickshell.json`, or
`~/.config/punchi-dock-quickshell.json` when `XDG_CONFIG_HOME` is unset. They are
not stored in the installed program files, and a Plasma update does not
intentionally manage them.

A trial run reads and writes its own profile instead, so it starts from the default
items and never changes the profile an installed copy owns.
