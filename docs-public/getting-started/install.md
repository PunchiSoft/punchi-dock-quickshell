# Install and run

Punchi Dock Quickshell is installed from a source checkout. The supported route is
the guided per-user installation; a CMake prefix installation is available for
packaging and advanced deployments.

## Requirements

- Linux with KDE Plasma/KWin on Wayland. X11 is out of scope and no support work is
  planned; other compositors and desktops are unsupported.
- Quickshell, matched to the Qt version it was built for. Quickshell is not
  packaged by this project.
- The KDE runtime libraries and QML modules listed under
  [Dependencies](#dependencies).
- Both compiled native components: the `Punchi.Kde` QML plugin and the
  `punchi-window-state` backend.
- `git` to clone. The setup assistant never installs it.

A complete installation is not just `shell.qml`. Sharing that file alone, or
copying a build directory to another distribution, does not provide a complete or
verified installation. This is not a `.plasmoid` package: Quickshell runs the QML
interface as a separate application alongside Plasma.

## Clone

```bash
git clone https://github.com/PunchiSoft/punchi-dock-quickshell.git
cd punchi-dock-quickshell
```

If `git` is missing, install it first:

```bash
sudo dnf install git        # Fedora
sudo apt-get install git    # Debian / Ubuntu
sudo pacman -S git          # Arch
```

## Guided setup

Run the assistant:

```bash
./scripts-user/setup.sh
```

Without arguments it opens a menu:

| Menu option | Non-interactive action | Effect |
|---|---|---|
| Install or update | `./scripts-user/setup.sh --install` | Checks dependencies, offers to install missing packages, builds the native components and installs the runtime for the current user. |
| Build only | `./scripts-user/setup.sh --build` | Checks dependencies, offers to install missing packages and builds `build/` without installing or running the dock. |
| Try without installing | `./scripts-user/setup.sh --try` (`--test` is an alias) | Checks dependencies, builds the checkout and runs the dock from the checkout. Nothing is installed and the installed copy is never used. The run uses its own trial profile, so it starts from the default dock items and never reads or writes your saved preferences. When the dock exits, one confirmation removes the build output, the trial profile, the window-state registration and the runtime lock. |
| Start the dock | `./scripts-user/setup.sh --start` | Runs an existing build or user-local installation. It builds nothing: use Try or Build first. |
| Check dependencies | `./scripts-user/setup.sh --check-deps` | Reports runtime, build, validation and KDE checks. Qt tools are also found outside `PATH` in the distribution Qt bin directory. Fedora package names are validated; Debian/Ubuntu and Arch mappings are best-effort. |
| Check for updates | `./scripts-user/setup.sh --check-updates` | Fetches the configured Git remote and reports ahead/behind counts, the upstream declared version and the installed copy version. It only reads unless `--pull` is passed. |
| Update the checkout | `./scripts-user/setup.sh --check-updates --pull` | Runs `git pull --ff-only` after the check when the checkout is behind. It refuses modified tracked files and never rebases, resets or stashes. The menu asks before pulling and then offers to rebuild and install; `--pull` never installs. |
| Uninstall | `./scripts-user/setup.sh --uninstall` | Stops this project, restores owned KWin settings, removes a Punchi-owned autostart entry, the window-state registration and the user-local installation. It then asks once whether to keep your data or remove everything; removing everything also deletes the preferences, the legacy `punchi-shell.json`, `build/` and the runtime lock. |
| Instructions and README | `./scripts-user/setup.sh --instructions` | Shows commands, paths and README locations. |

The assistant reports each action as a short phase list and runs the long steps
behind a single animated progress line that is rewritten in place. The complete
CMake output is still recorded, and a failed step prints its last lines and
attaches them to the failure log. The dependency check animates the same line
while it collects the report and then prints the captured listing, so the check is
visible before the result arrives.

On a terminal a step stays visible for at least 0.9 s and the completion line holds
for 0.4 s, so a fast action does not flash past;
`PUNCHI_PROGRESS_MIN_SECONDS` and `PUNCHI_PROGRESS_SETTLE_SECONDS` tune both, and
redirected output never waits. Colors are used on a terminal and are disabled by
`--no-color` or `NO_COLOR`. Redirected output, `TERM=dumb` and locales without
UTF-8 get plain ASCII lines instead of box drawing and a moving bar, so logs stay
readable.

Build concurrency defaults to the detected CPU count capped by installed memory
(one job below 4.5 GiB, two below 8.4 GiB, four below 16 GiB), so a small machine
does not swap during the native build. `-j/--jobs N` overrides the automatic
count, and `PUNCHI_NO_PROGRESS=1` keeps the raw command output.

`setup.sh` belongs to the repository and is not a standalone download: installing
or building needs the checkout's `CMakeLists.txt`, `modules/`, `adapters/` and
`services/`. Git is optional and only used by Check for updates. When it is
missing, the assistant prints the install command for the detected distribution and
never installs git by itself.

## Install location

The user-local installation is written to
`${XDG_DATA_HOME:-$HOME/.local/share}/punchi-dock-quickshell`, or to the path passed
with `--prefix`. The assistant also writes
`${XDG_DATA_HOME:-$HOME/.local/share}/applications/punchi-dock-quickshell.desktop`,
so the dock appears in the application menu.

The menu entry uses `scripts-user/launcher.sh`, which logs startup output to
`${XDG_STATE_HOME:-$HOME/.local/state}/punchi-dock-quickshell/start.log` and shows
a KDE notification if the dock cannot start. It also provides Stop and Settings
actions. Installation never uses `sudo` or writes system directories. The source
checkout remains the build source.

`./scripts-user/start.sh` remains the direct foreground launcher. `setup.sh` uses
the same build and restore scripts, so the existing start, panel-mode and restore
behavior is unchanged.

Install/update and build-only return to the menu and do not run the dock. Use Try
without installing, the Start action, `--install --start` or `--build --start` to
run it after the action finishes. The dock runs as a child of the assistant, so
closing it returns you to the menu.

## One instance

Only one Punchi Dock Quickshell instance runs at a time across the source checkout
and the user-local installation. Starting one while the other is running reports the
active path and the restore script that stops it; it does not register a second
window backend.

## Trial runs

A trial run keeps its own profile in the instance runtime directory
(`$XDG_RUNTIME_DIR/punchi-dock-quickshell-$UID/trial-profile`, or the temporary
directory when `XDG_RUNTIME_DIR` is unavailable) and exports it as
`PUNCHI_PROFILE_DIR`. The dock's preferences and its autostart entry live there, so
a trial starts from the default items, never changes the profile an installed copy
owns, and cannot leave an entry that Plasma would load at sign-in. Because the
session never reads that profile, **Start with KDE Plasma** stays disabled during a
trial and the settings window explains that the option needs an installed copy.

## Start and stop

Start the dock in the foreground:

```bash
./scripts-user/start.sh
```

The start script registers this build's hidden KDE window-state backend and
refreshes the application service cache. A themed dot marks pinned apps with open
windows. Running indicators and live-session behavior remain under validation; see
[Troubleshooting](../troubleshooting.md).

To try a visibility mode, pass it to the start script:

```bash
./scripts-user/start.sh reserve          # Always visible
./scripts-user/start.sh dodge-windows    # Hide on window overlap
./scripts-user/start.sh overlay          # Above windows without reservation
./scripts-user/start.sh autohide         # Automatic hiding and bottom-edge reveal
```

An explicit mode switches a running instance. See [Dock modes](../configuration/dock-modes.md).

Keep the foreground terminal open. To stop, press Ctrl+C there, or use another
terminal:

```bash
./scripts-user/restore-kde.sh
```

Plasma stays running. The restore script selects only this project's Quickshell
configuration and restores the KWin settings the dock owns. The dock coexists with
the existing desktop and does not replace Plasma panels, settings or session
services.

## CMake installation

For a prefix-based installation:

```bash
cmake -S . -B "build/build-$(. /etc/os-release && printf '%s' "$ID")" -G Ninja
cmake --build "build/build-$(. /etc/os-release && printf '%s' "$ID")"
cmake --install "build/build-$(. /etc/os-release && printf '%s' "$ID")" --prefix ~/.local
```

The setup assistant and the scripts group one build tree per distribution under
`build/`, as `build/build-debian` or `build/build-fedora`, and `cmake --preset dev`
writes the generic single-machine tree `build/dev`. The flat `build-<ID>` and plain
`build/` trees of the earlier layouts are still read when they are the only complete
ones. `PUNCHI_BUILD_DIR` overrides the location.

This installs `bin/punchi-dock-quickshell`, the QML tree under
`share/punchi-dock-quickshell`, the window backend under
`libexec/punchi-dock-quickshell`, a desktop entry and the hicolor icon. The entry
point resolves its prefix, so it also works with `/usr` or another
`CMAKE_INSTALL_PREFIX`. This route is intended for packaging and advanced
deployments; `scripts-user/setup.sh` remains the guided per-user installer.

```bash
cmake --build "build/build-$(. /etc/os-release && printf '%s' "$ID")" --target uninstall
cpack --config "build/build-$(. /etc/os-release && printf '%s' "$ID")/CPackConfig.cmake"
```

The first removes the files recorded in `install_manifest.txt`. The second creates a
portable TGZ archive. RPM and DEB packages are still future work, and the CMake
install rules do not declare distribution-level dependencies.

## Uninstall

`./scripts-user/setup.sh --uninstall` stops only configurations rooted at this
checkout and at the user-local install root, restores owned KWin settings, removes
only a Punchi-owned autostart entry, unregisters the window-state desktop entry, and
removes only manifest-listed files.

It then offers two ways to finish:

- **Keep my data** asks separately about `build/` and the preferences file.
- **Remove everything** deletes the preferences, the legacy `punchi-shell.json`
  backup, `build/`, the runtime lock and the window-state registration after one
  destructive confirmation.

Neither choice touches the source checkout or any KWin recovery record.
`--remove-settings` and `--remove-build` remain available for non-interactive use;
`--keep-build` is a compatibility alias for the default.

## Distribution packaging

The distribution approach discussed for future releases is:

- Publish source with reproducible build instructions.
- Prepare distribution-specific packages, such as RPM and DEB, with declared
  dependencies, installed paths and a tested uninstall.
- Make startup at login an explicit user preference; it is not installed today.
- Keep program updates separate from personal settings, and make uninstalling the
  program distinct from explicitly removing personal preferences.

These packages are planned, not available release artifacts. The repository does
not currently provide a validated cross-distribution binary package, tags or
releases.

## Dependencies

The setup assistant reports dependencies in two groups. Distribution-specific
package names and install commands stay in `scripts-user/`; this list names the
software each group needs.

**To run the dock:**

- Quickshell
- Kirigami
- Kirigami Addons
- QQC2 Desktop Style
- KSvg
- KService
- Plasma Workspace
- Plasma Activities
- Plasma Activities Stats

**To build the native components:**

- CMake
- Ninja
- A C++17 compiler
- Extra CMake Modules
- Qt 6 Base, Declarative and Tools development files
- KF6 KIO, Service, CoreAddons, Config and WindowSystem development files
- Plasma Activities and Plasma Activities Stats development files
- Wayland client development files, scanner and protocols

The runtime also needs `kbuildsycoca6` from KService. The update badge is optional
and needs none of these at build time: it reads PackageKit over the system bus,
fwupd over the system bus and `flatpak remote-ls` when those services exist.

Validation tests separately need Python 3, D-Bus Python bindings, PyGObject,
`dbus-daemon`, `desktop-file-utils` and `update-desktop-database`; these are not
runtime requirements.

Use `./scripts-user/setup.sh --check-deps` to inspect the current environment.
Adding `--install-missing` additionally offers the distribution-specific install
command for Fedora, Debian/Ubuntu or Arch and asks before running it. On Debian,
Quickshell is not part of the stable suite: when it has no apt candidate, the
assistant offers to enable the matching `<codename>-backports` source with an
explicit confirmation and installs `quickshell` from it. Declining that offer keeps
the other missing packages installable.

If the native build fails, the assistant writes a timestamped log under the user's
Documents directory (`punchi-dock-quickshell-setup-*.log`) with the version,
distribution, paths and captured compiler output.

### Other distributions

Quickshell uses private Qt APIs, so its binary must match the Qt version it was
built for. Other distributions need their own Quickshell/Qt package combination and
their own validation. The assistant checks the required commands (`qs`,
`kbuildsycoca6`, `plasmashell`, `kwin_wayland`, `cmake`, `ninja`, a C++ compiler,
`pkg-config`, `wayland-scanner`, `qtpaths6` and the Qt validation tools) and reports
what is missing. Fedora package names are validated. Debian/Ubuntu (including
Kubuntu) and Arch have best-effort package maps; verify the names with the
distribution before installing them.

See [Compatibility](compatibility.md) for the rows this project has actually
tested.
