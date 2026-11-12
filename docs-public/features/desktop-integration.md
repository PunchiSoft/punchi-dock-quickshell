# Desktop integration

Punchi Dock Quickshell runs next to Plasma, not instead of it. This page states
what the dock owns, what it changes and how those changes are reversed.

## Coexistence

- Plasma keeps running. The project does not remove panels, claim
  notification/tray/polkit ownership, replace the session or restart Plasma.
- Other Plasma configuration is untouched.
- Only one Punchi Dock Quickshell instance runs at a time across the source
  checkout and the user-local installation. Starting one while the other is
  running reports the active path and the restore script that stops it; it does
  not register a second window backend.
- The optional autostart entry is a per-user file owned by Punchi Dock Quickshell.
- Installation never uses `sudo` or writes system directories.

## Start with KDE Plasma

The **Start with KDE Plasma** switch writes or removes a Punchi-owned XDG
autostart entry. The entry takes effect at the next Plasma sign-in. An entry owned
by another tool is never overwritten or deleted. The switch is unavailable during
a trial run, whose profile Plasma never loads.

The entry is an installation-level integration: it is not part of a portable
profile export.

## KWin minimize effect

The dock context menu can select one of KWin's minimize effects. The change is
deliberately narrow:

- It happens only after an explicit user selection and only within KWin's
  `exclusiveGroup=minimize`.
- Before the first write, the presence and boolean value of every discovered
  `Plugins/<effect>Enabled` key are recorded in the user-owned recovery record.
- Only keys whose effective values differ from the requested state are written, and
  unrelated KWin settings are preserved.
- On clean shutdown and when `scripts-user/restore-kde.sh` runs, an owned key is
  restored only if its current value still matches the last state the dock wrote.
  A key changed outside the dock is preserved as an external user change.

The recovery-record format, migration and failure behavior are documented in
[Native backend](../architecture/native-backend.md#owned-kwin-settings).

## Restoring the KDE interface

`./scripts-user/restore-kde.sh` stops this project's Quickshell configuration and
runs the KWin recovery even when the dock is already stopped. It selects only this
project's configuration, restores owned KWin settings and leaves the rest of
Plasma untouched.

Uninstalling with `./scripts-user/setup.sh --uninstall` additionally removes a
Punchi-owned autostart entry, the window-state registration and the user-local
installation. It then asks once whether to keep the user's data or remove
everything. See [Install and run](../getting-started/install.md#uninstall).

## What is not owned

The dock does not implement a task manager, a notification server, a tray host, a
polkit agent or a session manager. Capabilities stay inside what Plasma already
provides through KDE Frameworks and supported KWin interfaces. Features that would
require replacing one of those services need a separate explicit decision and
their own validation.
