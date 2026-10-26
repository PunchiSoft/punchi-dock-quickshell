# Scripts User

- `setup.sh` opens the guided menu: install/update, build, try without
  installing, start, dependency check, update check, uninstall and instructions.
  It also accepts non-interactive options; run
  `./scripts-user/setup.sh --help`. "Try it without installing" (`--try`, alias
  `--test`) builds the checkout and runs it from the checkout; it never installs
  and never runs the installed copy. "Start the dock" (`--start`) runs an
  existing build or installation and builds nothing.
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

Install and build report each phase (`[i/N] ✓ Label: State`) and run the long
steps behind one animated progress line that is rewritten in place. Output is
still captured, and a failed step prints its last lines before the failure log
is written. The dependency check uses the same line while it collects the
report, then replays the captured listing so the result stays on screen. The boxed header and the moving bar need a UTF-8 terminal; a
redirected stream, `TERM=dumb` or `NO_COLOR` gets plain ASCII lines. Colors are
used by default and disabled by `--no-color`/`NO_COLOR`. `PUNCHI_NO_PROGRESS=1`
skips the progress presentation and prints the raw command output.

The header shows RAM, CPU cores and the build job count. Automatic concurrency
is the detected CPU count capped by installed memory (1 job below 4.5 GiB, 2
below 8.4 GiB, 4 below 16 GiB); `-j/--jobs N` overrides it.

`lib/setup-terminal-ui.sh` holds the style codes, boxed header and phase lines,
`lib/setup-resources.sh` the RAM/CPU/job detection and `lib/setup-progress.sh`
the progress runner. Each library is self-contained and is loaded by the file
that needs it, so a single library can still be sourced on its own.

These scripts belong to the repository; downloading `setup.sh` alone cannot
install or build the dock because the checkout's CMake files, modules and native
sources are required. Git is optional: only Check for updates uses it. When it
is missing, the assistant prints the install command for the detected
distribution and never installs git automatically.

"Check for updates" (`--check-updates`) fetches the configured Git upstream,
reports ahead/behind counts, the upstream declared version and the installed
copy version, and then suggests `git pull --ff-only`. The menu asks before
pulling and, after a successful pull, asks whether to rebuild and install the
updated copy. `--pull` performs the same fast-forward pull non-interactively
and never rebuilds or installs. It refuses modified tracked files and never
rebases, resets or stashes. Qt tools (`qtpaths6`, `qmllint`,
`qmltestrunner`) are resolved from `PATH` and then from the distribution Qt bin
directory; `PUNCHI_QT_BIN_DIRS` adds colon-separated custom Qt prefixes.

The setup assistant installs for the current user under
`${XDG_DATA_HOME:-$HOME/.local/share}/punchi-dock-quickshell` and writes an
application-menu launcher with Stop and Settings actions. Install/update and
build-only return to the menu and do not run the dock; use Try, the Start
action or `--start` explicitly. The dock runs as a child process, so closing it
returns to the menu instead of ending the assistant. It never uses `sudo` for
the installation, never
removes the source checkout, keeps `build/` unless `--remove-build` is passed
and keeps personal preferences unless removal is confirmed separately. Plasma
stays running throughout setup and restoration.

Only one Punchi Dock Quickshell instance runs at a time across the checkout and
the user-local installation. Starting the other copy reports the active path and
its `restore-kde.sh` instead of registering a second window backend.
