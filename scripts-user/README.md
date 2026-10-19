# Scripts User

- `setup.sh` opens the guided menu: install/update, build, start, dependency
  check, uninstall and instructions. It also accepts non-interactive options;
  run `./scripts-user/setup.sh --help`.
- `start.sh` runs this configuration in the foreground. Run
  `./scripts-user/start.sh --help` for panel modes.
- `restore-kde.sh` stops only this configuration and restores owned KWin settings.
- `settings.sh` opens the dock settings window while the dock is running.

The setup assistant installs for the current user under
`${XDG_DATA_HOME:-$HOME/.local/share}/punchi-dock-quickshell` and writes an
application-menu launcher. It never uses `sudo` for the installation, never
removes the source checkout and keeps personal preferences unless removal is
confirmed separately. Plasma stays running throughout setup and restoration.

Only one Punchi Dock Quickshell instance runs at a time across the checkout and
the user-local installation. Starting the other copy reports the active path and
its `restore-kde.sh` instead of registering a second window backend.
