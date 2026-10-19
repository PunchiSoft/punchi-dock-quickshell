# Scripts User

- `setup.sh` opens the guided menu: install/update, build, start, dependency
  check, update check, uninstall and instructions. It also accepts
  non-interactive options; run `./scripts-user/setup.sh --help`.
- `start.sh` runs this configuration in the foreground. Run
  `./scripts-user/start.sh --help` for panel modes.
- `launcher.sh` is used by the application-menu entry. It writes startup output
  to `${XDG_STATE_HOME:-$HOME/.local/state}/punchi-dock-quickshell/start.log`
  and shows a KDE notification if the dock cannot start. It also accepts `stop`
  and `settings`.
- `restore-kde.sh` stops this configuration, including the active Punchi Dock
  checkout or installed copy recorded by the runtime lock, and restores owned
  KWin settings.
- `settings.sh` opens the dock settings window while the dock is running.
- `installed-launcher.sh` is installed by CMake as `bin/punchi-dock-quickshell`
  and resolves the installed data root.
- `punchi-dock-quickshell.desktop` is the CMake-installed desktop entry.

KDE Plasma/KWin on Wayland is required. `start.sh` refuses to run outside an
active KDE session. Install/build offer to install missing dependencies for the
detected distribution and write a timestamped build-failure log under the user's
Documents directory.

These scripts belong to the repository; downloading `setup.sh` alone cannot
install or build the dock because the checkout's CMake files, modules and native
sources are required. Git is optional: only Check for updates uses it. When it
is missing, the assistant prints the install command for the detected
distribution and never installs git automatically.

"Check for updates" (`--check-updates`) fetches the configured Git upstream,
reports ahead/behind counts, the upstream declared version and the installed
copy version, and then suggests `git pull --ff-only`. The menu asks before
pulling; `--pull` performs the same fast-forward pull non-interactively. It
refuses modified tracked files and never rebases, resets or stashes, and it does
not rebuild or reinstall on its own. Qt tools (`qtpaths6`, `qmllint`,
`qmltestrunner`) are resolved from `PATH` and then from the distribution Qt bin
directory; `PUNCHI_QT_BIN_DIRS` adds colon-separated custom Qt prefixes.

The setup assistant installs for the current user under
`${XDG_DATA_HOME:-$HOME/.local/share}/punchi-dock-quickshell` and writes an
application-menu launcher with Stop and Settings actions. Install/update and
build-only return to the menu and do not start the dock; use the Start action
or `--start` explicitly. It never uses `sudo` for the installation, never
removes the source checkout, keeps `build/` unless `--remove-build` is passed
and keeps personal preferences unless removal is confirmed separately. Plasma
stays running throughout setup and restoration.

Only one Punchi Dock Quickshell instance runs at a time across the checkout and
the user-local installation. Starting the other copy reports the active path and
its `restore-kde.sh` instead of registering a second window backend.
