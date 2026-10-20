# Punchi Dock Quickshell

<p align="center"><img src="assets/icons/punchi-dock-quickshell.svg" width="120" alt="Punchi Dock Quickshell logo"></p>

<p align="center"><strong>An animated, configurable dock for KDE Plasma, built with Quickshell and native Qt/KDE integration.</strong></p>

[English](README.md) · [Español](README.es.md)

> [!WARNING]
> **Under construction — actively changing.**
>
> Punchi Dock Quickshell is under constant development. Expect breaking changes
> to behavior, configuration, native APIs and documentation without migration.
> Fedora 44 with KDE Plasma 6.7.5 and KWin 6.7.5 on Wayland, checked
> 2026-10-20, is the primary validated environment. Arch Linux (rolling,
> checked 2026-10-19: Plasma/KWin 6.8.0, Qt 6.12.0, KF6 6.31.0, Quickshell
> 0.3.2) has a successful build and initial-start test; prolonged-use and full
> visual validation remain pending. X11 is out of scope and no support work is
> planned. Other distributions and compositors are unvalidated. There is no
> stable release, package, support commitment or compatibility guarantee yet.

Punchi Dock Quickshell combines animated magnification, configurable application
launchers, KDE context actions, and persistent preferences. It runs alongside
Plasma through reversible start and stop scripts.

**KDE Plasma/KWin is required.** Punchi Dock Quickshell is not a GNOME, XFCE,
Hyprland or generic Wayland dock. It will not run on another desktop, and
starting it outside an active KDE Plasma/KWin session exits with an explicit
error.

**Current delivery:** **0.1.25**. The first Git snapshot was published as
`0.1.0`, equivalent to `0.1.00` under the current delivery counter. Each
delivery commit advances the counter once; see the [changelog](CHANGELOG.md).
Compatibility and validation limits are documented below.

[Attribution](NOTICE.md) · [License](LICENSE) · [Changelog](CHANGELOG.md) · [Security](SECURITY.md)

The source-checkout workflow below is the supported development installation.
On 2026-10-20, the automated setup and test suite were validated on Fedora 44
with Quickshell 0.2.1, Qt 6.11.2, KDE Frameworks 6.31.0, KDE Plasma 6.7.5 and
KWin 6.7.5. Other distributions need package-name adjustments and their own
validation.

## Current features

- Continuous hover magnification, themed tooltips, an expanding background and
  two-hop launch feedback, with reduced motion support.
- Configurable pinned applications: discover and search installed applications
  through KDE, add or reorder launchers, and save preferences. Eight preset
  launchers provide the initial configuration.
- Native application launching through KService and KIO, with Wayland activation
  integration. Normal clicks activate an existing KDE window or minimize an
  eligible active window before considering a launch; activation remains
  limited to the validated environment described below.
- Startup launch coordination, window cycling, known running unpinned applications
  and middle-click New Window through KDE.
- Launcher context menus with KDE desktop actions, recent documents, unpinning
  and KDE Places navigation for eligible file-manager launchers.
- Dock settings for icon size, magnification, bounce, reduced motion and
  visibility: Always visible, Hide automatically, Dodge windows or Windows go below.
- An optional **Start with KDE Plasma** switch that writes or removes a
  Punchi-owned XDG autostart entry. The entry takes effect at the next Plasma
  sign-in; an entry owned by another tool is never overwritten or deleted.
- Optional **recent applications** from KDE activity history, shown as extra
  dock launchers with a configurable count. Pinned applications and
  applications with open windows are excluded.
- Keyboard navigation and pending settings edits through Apply, Accept and Close.
- Downloads with Grid, List and Detail folder views, navigation inside a themed
  balloon, and native KDE file opening.

Running-application indicators and existing-window activation are implemented
with isolated validation; physical KDE checks remain pending. A separate panel,
an application-launcher surface and additional controls remain future work.

## Known limitations

- Alpha software: behavior, configuration and native APIs may change without
  migration.
- Requires KDE Plasma/KWin on Wayland. Other desktops and compositors are not
  supported. X11 is out of scope and no support work is planned.
- Fedora 44 with KDE Plasma 6.7.5 and KWin 6.7.5 on Wayland, checked
  2026-10-20, is the primary validated environment. Arch Linux has passed a
  build and initial-start test; prolonged-use and full visual validation remain
  pending.
- English UI only for now; [README.es.md](README.es.md) is a documentation
  translation.
- Source and CMake prefix installs only; no RPM/DEB packages, tags or release
  binaries.
- Window activation, KWin cursor feedback and multi-monitor behavior still need
  broader real-session validation.

## Install, run and return to KDE

Clone the repository and enter the checkout:

```bash
git clone https://github.com/PunchiSoft/punchi-dock-quickshell.git
cd punchi-dock-quickshell
```

### Guided setup

Run the setup assistant:

```bash
./scripts-user/setup.sh
```

Without arguments it opens a menu:

| Menu option | Non-interactive action | Effect |
|---|---|---|
| Install or update | `./scripts-user/setup.sh --install` | Checks dependencies, offers to install missing packages, builds the native components and installs the runtime for the current user. |
| Build only | `./scripts-user/setup.sh --build` | Checks dependencies, offers to install missing packages and builds `build/` without installing. |
| Start the dock | `./scripts-user/setup.sh --start` | Starts the installed copy, or the source checkout when no installation exists. |
| Check dependencies | `./scripts-user/setup.sh --check-deps` | Reports runtime, build, validation and KDE checks. Qt tools are also found outside `PATH` in the distribution Qt bin directory. Fedora package names are validated; Debian/Ubuntu and Arch mappings are best-effort. |
| Check for updates | `./scripts-user/setup.sh --check-updates` | Fetches the configured Git remote and reports ahead/behind counts, the upstream declared version and the installed copy version. It only reads unless `--pull` is passed. |
| Update the checkout | `./scripts-user/setup.sh --check-updates --pull` | Runs `git pull --ff-only` after the check when the checkout is behind. It refuses modified tracked files and never rebases, resets or stashes. The menu asks before pulling and then offers to rebuild and install; `--pull` never installs. |
| Uninstall | `./scripts-user/setup.sh --uninstall` | Stops this project, restores owned KWin settings, removes a Punchi-owned autostart entry and removes the user-local installation. `build/` is kept unless `--remove-build` is passed. |
| Instructions and README | `./scripts-user/setup.sh --instructions` | Shows commands, paths and README locations. |

`setup.sh` belongs to the repository and is not a standalone download:
installing or building needs the checkout's `CMakeLists.txt`, `modules/`,
`adapters/` and `services/`. Git is optional and only used by Check for
updates. When it is missing, the assistant prints the install command for the
detected distribution and never installs git by itself.

The user-local installation is written to
`${XDG_DATA_HOME:-$HOME/.local/share}/punchi-dock-quickshell`, or to the path
passed with `--prefix`. The assistant also writes
`${XDG_DATA_HOME:-$HOME/.local/share}/applications/punchi-dock-quickshell.desktop`,
so the dock appears in the application menu. The menu entry uses
`scripts-user/launcher.sh`, which logs startup output to
`${XDG_STATE_HOME:-$HOME/.local/state}/punchi-dock-quickshell/start.log` and
shows a KDE notification if the dock cannot start. It also provides Stop and
Settings actions. Installation never uses `sudo` or writes system directories.
The source checkout remains the build source.

`./scripts-user/start.sh` remains the direct foreground launcher. `setup.sh`
uses the same build and restore scripts, so the existing start, panel-mode and
restore behavior is unchanged.

Install/update and build-only return to the menu and do not start the dock. Use
the Start action, `--install --start` or `--build --start` to launch it after
the action finishes.

Only one Punchi Dock Quickshell instance runs at a time across the source
checkout and the user-local installation. Starting one while the other is
running reports the active path and the restore script that stops it; it does
not register a second window backend.

### Compatibility at a glance

| Status | Environment / family | Plasma | KWin | Qt | KF6 | Quickshell | Distributions / notes |
|:---:|---|---|---|---|---|---|---|
| ✅ | Fedora KDE 44 | 6.7.5 | 6.7.5 | 6.11.2 | 6.31.0 | 0.2.1 | Versions checked 2026-10-20 |
| 🟡 | Arch Linux (rolling) | 6.8.0 | 6.8.0 | 6.12.0 | 6.31.0 | 0.3.2 | Arch repository versions checked 2026-10-19; build and initial start tested; prolonged-use and full visual validation pending; Mesa/Zink warnings; not a compatibility claim for this exact set |
| ⚪ | Fedora/RHEL family | — | — | — | — | — | Nobara KDE, Fedora Kinoite, CentOS Stream 10 KDE (EPEL), Rocky Linux KDE, AlmaLinux Kitten KDE |
| ⚪ | Debian/Ubuntu family | — | — | — | — | — | Debian KDE, Kubuntu, KDE neon, Tuxedo OS, MX Linux KDE |
| ⚪ | Arch family | — | — | — | — | — | Manjaro KDE, EndeavourOS, CachyOS, Garuda KDE |
| ⚪ | openSUSE | — | — | — | — | — | Tumbleweed, Leap |
| ⚪ | Independent | — | — | — | — | — | KaOS, Solus KDE |
| ❌ | X11 / non-KDE compositors | — | — | — | — | — | X11 is out of scope; no support work is planned |

✅ validated · 🟡 builds/starts, validation pending · ⚪ untested, same family · ❌ unsupported · ⏳ pending · — not applicable.

Only Fedora 44 has the complete automated validation graph. List based on the
[KDE Community wiki — Distributions](https://community.kde.org/Distributions).
Plasma 6.8.0 was released on 2026-10-14. Arch was confirmed to build and start,
but prolonged use and visual behavior still need validation; this is not a
compatibility claim for every Arch installation.

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

The runtime also needs `kbuildsycoca6` from KService. Validation tests separately
need Python 3, D-Bus Python bindings, PyGObject, `dbus-daemon`,
`desktop-file-utils` and `update-desktop-database`; these are not runtime
requirements.

Use `./scripts-user/setup.sh --check-deps` to inspect the current environment.
Adding `--install-missing` additionally offers the distribution-specific install
command for Fedora, Debian/Ubuntu or Arch and asks before running it.

If the native build fails, the assistant writes a timestamped log under the
user's Documents directory (`punchi-dock-quickshell-setup-*.log`) with the
version, distribution, paths and captured compiler output.

### Other distributions

Quickshell uses private Qt APIs, so its binary must match the Qt version it was
built for. Other distributions need their own Quickshell/Qt package combination
and their own validation. The assistant checks the required commands
(`qs`, `kbuildsycoca6`, `plasmashell`, `kwin_wayland`, `cmake`, `ninja`, a C++
compiler, `pkg-config`, `wayland-scanner`, `qtpaths6` and the Qt validation
tools) and reports what is missing. Fedora package names are validated.
Debian/Ubuntu (including Kubuntu) and Arch have best-effort package maps; verify
the names with the distribution before installing them.

KDE Plasma/KWin on Wayland is required. X11 is out of scope and no support work
is planned; other compositors are unsupported.

### Start and stop

Start the dock in the foreground:

```bash
./scripts-user/start.sh
```

The start script registers this build's hidden KDE window-state backend and
refreshes the application service cache. A themed dot marks pinned apps with open
windows. Running indicators and live-session behavior remain under validation;
see [Known limitations](#known-limitations).

To try panel behavior, use `./scripts-user/start.sh reserve` (Always visible),
`./scripts-user/start.sh dodge-windows` (hide on window overlap), or
`./scripts-user/start.sh overlay` (above windows without reservation). An explicit
mode switches a running instance.

Use `./scripts-user/start.sh autohide` to try automatic hiding and bottom-edge
reveal. This mode does not detect window overlap.

Keep the foreground terminal open. To stop, press Ctrl+C there, or use another terminal:

```bash
./scripts-user/restore-kde.sh
```

Plasma stays running. The dock coexists with the existing desktop and does not
replace Plasma panels, settings, or session services. Its optional autostart
entry is a per-user file owned by Punchi Dock Quickshell. The restore script
selects only this project's Quickshell configuration.

## Dock configuration

Right-click the dock and choose Configure Dock to open its settings.
With Punchi Dock Quickshell running, `./scripts-user/settings.sh` also opens the window.
Apply saves pending changes without closing; Accept saves and closes; Close
discards pending changes. Preferences persist independently of Plasma.

Preferences are stored separately for each operating-system user in
`$XDG_CONFIG_HOME/punchi-dock-quickshell.json`, or `~/.config/punchi-dock-quickshell.json` when
`XDG_CONFIG_HOME` is unset. They are not stored in the installed program files.
At first start, an existing `punchi-shell.json` is migrated to the new filename
only when the new file does not exist; the original file is kept as a backup.
If both files exist, the new filename takes precedence and neither is overwritten.
Without a saved file, the application uses the defaults in
[`ShellSettings.qml`](config/ShellSettings.qml):

| Setting | Current first-run default |
|---|---|
| Surface | Bottom dock; no custom top bar yet |
| Pinned items, in order | Dolphin, Konsole, Firefox, Kate, System Settings, Discover, Gwenview, Okular, Downloads, Trash |
| Size | 100% of the theme-derived base size |
| Pointer magnification | Enabled, with a maximum scale of 200% |
| Click bounce | Enabled |
| Visibility | Windows go below (`overlay`), without reserving screen space |
| Reduced motion | Local override off; KDE animation preferences still apply |
| Icons | The user's icon theme, including live KDE theme-change notifications |

These are prototype defaults, not a guarantee that every preset application is
installed. Changing settings through Apply or Accept persists the user's values;
later starts load them. An explicit startup mode can override the saved visibility
mode. The current file format is version 7 and accepts versions 1 to 6 through
migration. Version 7 adds the recent-applications switch and visible count;
missing fields in older profiles default to enabled with five applications.

## Installation and sharing

The supported development route is the source checkout plus the guided
user-local installation above. A CMake prefix installation is also available
for packaging and advanced deployments. This is not a `.plasmoid` package:
Quickshell runs the QML interface as a separate application alongside Plasma.
Quickshell supports named configurations and running a configuration directly
from a directory with `--path`.
See its [configuration guide](https://quickshell.org/docs/v0.2.1/guide/introduction/).

A complete installation needs compatible Quickshell/Qt packages, the KDE runtime
libraries and QML modules used by the project, and both compiled native components:
the `Punchi.Kde` QML plugin and `punchi-window-state` backend. KDE integrations
include KIO, KService, KWindowSystem, Activities Stats, Kirigami, TaskManager and
the Plasma MPRIS module. Building from source also needs the development packages
listed above.
Sharing only `shell.qml`, or copying a build directory to another distribution,
does not provide a complete, verified installation.

The setup assistant writes an install manifest and a marker file inside the
install root. `--uninstall` stops only configurations rooted at this checkout and
at that install root, restores owned KWin settings, removes only a Punchi-owned
autostart entry, and removes only manifest-listed files. It keeps the source
checkout, `build/`, the legacy `punchi-shell.json` backup and any KWin recovery
record. The current preferences file is deleted only after a separate
confirmation or an explicit
`--remove-settings`. `--remove-build` also deletes `build/`; `--keep-build`
remains as a compatibility alias for the default.

### CMake installation

For a prefix-based installation:

```bash
cmake -S . -B build -G Ninja
cmake --build build
cmake --install build --prefix ~/.local
```

This installs `bin/punchi-dock-quickshell`, the QML tree under
`share/punchi-dock-quickshell`, the window backend under
`libexec/punchi-dock-quickshell`, a desktop entry and the hicolor icon. The
entry point resolves its prefix, so it also works with `/usr` or another
`CMAKE_INSTALL_PREFIX`. This route is intended for packaging and advanced
deployments; `scripts-user/setup.sh` remains the guided per-user installer.

`cmake --build build --target uninstall` removes the files recorded in
`install_manifest.txt`. `cpack --config build/CPackConfig.cmake` creates a
portable TGZ archive. RPM and DEB packages are still future work; the CMake
install rules do not declare distribution-level dependencies.

The distribution approach discussed for future releases is:

- Publish source with reproducible build instructions.
- Prepare distribution-specific packages, such as RPM and DEB, with declared
  dependencies, installed native modules and an application-menu launcher.
- Make startup at login an explicit user preference; it is not installed today.
- Keep program updates separate from personal settings, and make uninstalling
  the program distinct from explicitly removing personal preferences.

These distribution packages are planned, not available release artifacts. The
repository does not currently provide a validated cross-distribution binary
package, tags or releases.

## Growing into a modular shell

The same project and Quickshell configuration can host the dock, a future top bar,
settings windows and other surfaces. Each surface has its own window and module;
`shell.qml` composes them. A top bar belongs in a future `modules/topbar/` module,
sharing confirmed components and services, including media controls, rather than
requiring a separate project or duplicating the dock's implementation.
Quickshell supplies window hosting; KDE integration is connected explicitly
through the adapters. A Plasma applet is instead hosted by Plasma itself.

The current saved settings describe one dock. Before supporting multiple docks
or panels, extend storage with stable instance IDs, each instance's screen and
placement, ordered items and behavior, plus shared preferences and enabled
modules. Define behavior for disconnected monitors and migrate existing settings
without overwriting user choices. This multi-instance configuration is future work.

KConfig is the recommended native KDE storage option to evaluate as configuration
expands. The current implementation still uses JSON; any migration must preserve
existing preferences. See [KConfig](https://api.kde.org/kconfig-index.html).

## Compatibility and validation

The initial target is Linux with KDE Plasma/KWin on Wayland. See
[Compatibility at a glance](#compatibility-at-a-glance) for the validated
versions and candidate distributions. Quickshell and Qt must be ABI-compatible;
other combinations, distributions and compositors require their own validation.
X11 is out of scope and no support work is planned.

Updates to Plasma, KWin, KDE Frameworks, Qt or Quickshell can affect compatibility.
The risk differs between maintenance updates and changes to major versions or
internal interfaces; native KDE integration does not guarantee compatibility
with every future release. Quickshell documents breaking changes before 1.0 and
Qt-update issues with some package builds in its
[installation guide](https://quickshell.org/docs/v0.2.1/guide/install-setup/).

One current dependency needing particular attention is
`org.kde.plasma.private.mpris`, an internal Plasma module used for media controls.
Window/task integrations and KDE screen-edge behavior also need testing against
the target Plasma/KWin version. Prefer public APIs, keep internal integrations
isolated, and provide graceful unavailability where a capability can be optional.
Rebuilding can address a binary mismatch; changed API contracts require code
adaptation and regression checks.

Before claiming support for a release, declare required versions and test the
actual packages together, including launching, activation/minimization, menus,
Trash and hiding behavior. A normal KDE update does not intentionally manage
Punchi Dock Quickshell's personal settings file; our own format updates must migrate it.
Broad update compatibility remains a maintenance goal, not an established
guarantee of this prototype.

Automated checks can be timing-sensitive. During one complete-suite run the
`settings_reload` probe timed out and then passed when run alone. The changelog
records the current validation scope and known gaps.

An isolated Wayland session probe passed startup, duplicate prevention, rendering,
hide/reopen and scoped restoration. Automated checks do not establish final
visual quality, fractional scaling, multi-monitor behavior, screen-reader support,
or native KDE startup cursor feedback. The changelog records the current
validation scope and known gaps.

## Development

This QML configuration runs in Quickshell. CMake builds the native KDE adapters
and organizes validation. See [AGENTS.md](AGENTS.md) for project rules. After
configuring the project, run the complete validation graph with:

```bash
ctest --test-dir build --output-on-failure
```

## Modular structure

| Directory | Responsibility |
|---|---|
| `shell.qml` | Compose shell modules |
| `modules/dock/` | Dock window and view |
| `components/` | Shared visual interaction primitives |
| `services/` | Model data and coordination |
| `config/` | Reactive settings and shared metrics |
| `adapters/kde/` | KDE motion preferences and native application launching |
| `tests/` | Component, foundation, and real-session checks |
| `.agents/skills/` | Repository-scoped development workflows |

English is the source language. Only English fallback strings are supported at
this stage. Settings update existing surfaces through reactive state.

## Author and development assistance

Punchi Dock Quickshell is developed by PunchiSoft. AI coding agents are used as
development support for implementation, review and documentation. The maintainer
remains responsible for all changes, validation and published content.

## Origins and attribution

The project draws on [Punchi Dock Remastered](https://github.com/PunchiSoft/punchi-dock-remastered)
and takes architectural and visual inspiration from
[Caelestia Shell](https://github.com/caelestia-dots/shell), while implementing
desktop integration for KDE/KWin. See [NOTICE.md](NOTICE.md) for reused code,
assets and attribution.

## License

GPL-3.0-or-later. See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).
