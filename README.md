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
> 0.3.2) and Debian 13.7 KDE (checked 2026-10-30: Plasma/KWin 6.3.6, Qt 6.8.2,
> KF6 6.13.0, Quickshell 0.3.0) have a successful build and initial-start test;
> prolonged-use and full visual validation remain pending. X11 is out of scope
> and no support work is planned. Other distributions and compositors are
> unvalidated. There is no stable release, package, support commitment or
> compatibility guarantee yet.

Punchi Dock Quickshell combines animated magnification, configurable application
launchers, KDE context actions and media transport, a settings window and
persistent preferences. It runs alongside Plasma through reversible start and
stop scripts.

It was born from the limits of
[Punchi Dock Remastered](https://github.com/PunchiSoft/punchi-dock-remastered),
the original project and the Plasma applet that is its base. An applet lives
inside a Plasma panel and inherits the host's surface, edge and window behavior,
so the dock cannot have its own Wayland surface, choose its edge behavior in the
compositor, or keep a lifespan and input model independent from Plasma. This
project keeps that dock's visual language, magnification and launch feedback,
and rebuilds its launching, activation and compositor behavior as a standalone
Quickshell application with native KDE adapters.

**KDE Plasma/KWin is required.** Punchi Dock Quickshell is not a GNOME, XFCE,
Hyprland or generic Wayland dock. It will not run on another desktop: the setup
assistant refuses to install outside KDE Plasma on Wayland, and starting an
installed copy elsewhere names the session it found and shows a system dialog
instead of running.

**Current version:** **0.1.47** (development snapshot, not published — the
repository carries no tag or release). The [changelog](CHANGELOG.md) records the
delivered changes and their validation. Compatibility and validation limits are
documented below.

[Attribution](NOTICE.md) · [License](LICENSE) · [Changelog](CHANGELOG.md) ·
[Security](SECURITY.md) · [Contributing](CONTRIBUTING.md) · [Support](SUPPORT.md)

The source-checkout workflow below is the supported development installation.
On 2026-10-20, the automated setup and test suite were validated on Fedora 44
with Quickshell 0.2.1, Qt 6.11.2, KDE Frameworks 6.31.0, KDE Plasma 6.7.5 and
KWin 6.7.5. Other distributions need package-name adjustments and their own
validation.

## Current features

- Continuous hover magnification, themed tooltips, an expanding background and
  two-hop launch feedback, with reduced motion support.
- Bottom, left or right placement. The magnification wave, tooltips, context
  menus, arrow-key navigation, running indicators and the native auto-hide edge
  follow the selected edge, side popups open inward and icons stay upright.
- One dock on every connected screen, sharing one profile. **Screens and
  desktops** limits the dock to selected screens or virtual desktops and KDE
  activities, remembers a selected screen across hot-plug, falls back to the
  system primary screen while none is connected, and leaves an auto-hiding dock
  visible when its edge borders another monitor. Running markers can follow the
  current desktop and activity.
- Configurable pinned applications: discover and search installed applications
  through KDE, add or reorder launchers, and save preferences. Eight preset
  application launchers plus the Home and Downloads containers and Trash form the
  initial configuration.
- Native application launching through KService and KIO, with Wayland activation
  integration. Normal clicks activate an existing KDE window or minimize an
  eligible active window before considering a launch; activation remains
  limited to the validated environment described below.
- Startup launch coordination, window cycling, known running unpinned applications
  and middle-click New Window through KDE.
- Launcher context menus with KDE desktop actions, recent documents, unpinning,
  window actions such as Move to Desktop, Maximize and Fullscreen, and KDE
  Places navigation for eligible file-manager launchers.
- Media transport for the matching KDE MPRIS player: Previous Track, Play/Pause,
  Next Track and Stop appear only while a player exists, follow its live
  capabilities and close the menu after dispatch. The private Plasma MPRIS
  provider is isolated in one adapter.
- A Trash item backed by native KDE state. Left-click opens the Trash; its
  context menu offers **Open** and **Empty Trash** behind one themed
  confirmation, the destructive action stays disabled while the Trash is empty,
  unavailable or busy, and KDE supplies a fresh listing after the job instead of
  an assumed empty result.
- Dock settings for icon size, magnification, bounce, reduced motion, position
  and visibility: Always visible, Hide automatically, Dodge windows or Windows
  go below.
- Popup settings for size, height and icon size in their own **Popups**
  category, applied to the folder containers. The grid, the list/detail rows and
  the fan keep independent glyph sizes.
- Settings organized as **Items**, **General**, **Popups**, **Profile** and
  **About**, with **Reset defaults** and pending edits through Apply, Accept and
  Close. **Profile** imports and exports a JSON profile of the dock items,
  folder containers and preferences, with a preview and confirmation before the
  imported values replace the pending profile. **About** shows the application
  version, website and issue links, license, authors and the **Made with love**
  dedication.
- An optional KWin minimize effect selected from the dock context menu. Only
  KWin's `exclusiveGroup=minimize` keys are written, their original presence and
  values are recorded before the first write, and they are restored on clean
  exit or by `scripts-user/restore-kde.sh`; a key changed outside the dock is
  left untouched.
- An update badge on the Discover launcher while the machine has pending updates.
  The count is read only from PackageKit, fwupd and Flatpak through their native
  interfaces, so the dock never asks Discover, never installs anything, never
  refreshes package caches and never requests authorization. The number travels
  and scales with the icon and rests on its lower-right corner, where KDE paints
  its own update dots. The badge takes the color KDE paints its update
  notifications with: neutral orange while updates are pending and negative red
  once a security update is present. While PackageKit applies updates the disc
  shows the tray's `update-busy` glyph instead of the count and re-checks as soon
  as the install ends, so a just-applied count is not painted again. The
  **Updates** switch turns the badge off without a restart. The badge follows
  whichever supported update front-end is actually pinned (Discover first)
  rather than assuming a distribution, and a missing service simply contributes
  nothing. PackageKit reports its own backend (`dnf5`, `apt`, `alpm`, `zypper`
  ...), so distribution packages work wherever PackageKit is installed; AUR
  helpers and Snap are not queried yet.
- An optional **Start with KDE Plasma** switch that writes or removes a
  Punchi-owned XDG autostart entry. The entry takes effect at the next Plasma
  sign-in; an entry owned by another tool is never overwritten or deleted. The
  switch is unavailable during a trial run, whose profile Plasma never loads.
- Optional **recent applications** from KDE activity history with a configurable
  count. **Presentation** chooses the extra dock launchers or one container item
  with a fixed glyph, whose **Container view** offers Grid, List, Detail and Fan;
  the container is the first-run presentation with the List view. Pinned
  applications and applications with open windows are excluded in both
  presentations. Dock settings include a switch that writes KDE's
  remember-applications preference and a shortcut to KDE's Recent Files options;
  when KDE saves no application history a short note explains how to enable it.
- Keyboard navigation for the dock, its context menus and the settings window.
- Item editors that choose a theme icon for any pinned application or folder
  container and store it by name, falling back to the item's own icon.
- Folder containers for any local folder: Grid, List, Detail and Fan
  presentations, per-container sorting, subfolder browsing and a hidden-entry
  list. The built-in **Home** container opens as Fan and lists only the standard
  KDE/XDG user folders through their localized names; its first-run profile
  leaves subfolder browsing off, so a selected folder opens in the file manager.
  A side dock presents a stored fan as Grid because the arc needs a top or
  bottom edge.
- Downloads with Grid, List, Detail and Fan folder views, navigation inside a themed
  balloon, and native KDE file opening. Every presentation ends with an **Open**
  row and marks browsable folders with a chevron; a right-click on an entry
  offers **Open in File Manager** and **Copy Path**. Columns come from the space
  the popup really has, so scrolling appears only when the entries do not fit,
  with a slim indicator that fades while the listing rests.

Running-application indicators and existing-window activation are implemented
with isolated validation; physical KDE checks remain pending. A separate panel,
an application-launcher surface and additional controls remain future work.

## Known limitations

- Alpha software: behavior, configuration and native APIs may change without
  migration.
- Quickshell 0.3.0 logs one harmless `WARN: QSettings::value: Empty key passed`
  at startup in some distributions, including Debian 13. It appears before the
  shell loads and with an empty configuration, so this project does not produce
  it; it does not change behavior, and the full startup log keeps it for
  diagnosis.
- Requires KDE Plasma/KWin on Wayland. Other desktops and compositors are not
  supported. X11 is out of scope and no support work is planned.
- Fedora 44 with KDE Plasma 6.7.5 and KWin 6.7.5 on Wayland, checked
  2026-10-20, is the primary validated environment. Arch Linux and Debian 13.7
  KDE have passed a build and initial-start test; prolonged-use and full visual
  validation remain pending.
- English UI only for now; [README.es.md](README.es.md) is a documentation
  translation.
- Source and CMake prefix installs only; no RPM/DEB packages, tags or release
  binaries.
- Window activation, media transport and KWin cursor feedback still need broader
  real-session validation. A two-screen layout (eDP-1 + HDMI-A-1, Plasma 6.7.5)
  exercised per-screen docks, screen selection, primary fallback, virtual-desktop
  and activity filtering and shared-edge auto-hide on 2026-10-27; other layouts,
  physical hot-plug and fractional scaling remain unvalidated.

## Install, run and return to KDE

`git` is required to clone, and the setup assistant never installs it. Install
it first if it is missing:

```bash
sudo dnf install git        # Fedora
sudo apt-get install git    # Debian / Ubuntu
sudo pacman -S git          # Arch
```

Then clone the repository and enter the checkout:

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
while it collects the report and then prints the captured listing, so the check
is visible before the result arrives. On a terminal a step stays visible for at
least 0.9 s and the completion line holds for 0.4 s, so a fast action does not
flash past; `PUNCHI_PROGRESS_MIN_SECONDS` and `PUNCHI_PROGRESS_SETTLE_SECONDS`
tune both, and redirected output never waits. Colors are used on a terminal and are
disabled by `--no-color` or `NO_COLOR`. Redirected output, `TERM=dumb` and
locales without UTF-8 get plain ASCII lines instead of box drawing and a moving
bar, so logs stay readable.

Build concurrency defaults to the detected CPU count capped by installed memory
(one job below 4.5 GiB, two below 8.4 GiB, four below 16 GiB), so a small
machine does not swap during the native build. `-j/--jobs N` overrides the
automatic count, and `PUNCHI_NO_PROGRESS=1` keeps the raw command output.

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

Install/update and build-only return to the menu and do not run the dock. Use
Try without installing, the Start action, `--install --start` or
`--build --start` to run it after the action finishes. The dock runs as a child
of the assistant, so closing it returns you to the menu.

Only one Punchi Dock Quickshell instance runs at a time across the source
checkout and the user-local installation. Starting one while the other is
running reports the active path and the restore script that stops it; it does
not register a second window backend.

A trial run keeps its own profile in the instance runtime directory
(`$XDG_RUNTIME_DIR/punchi-dock-quickshell-$UID/trial-profile`, or the temporary
directory when `XDG_RUNTIME_DIR` is unavailable) and exports it as
`PUNCHI_PROFILE_DIR`. The dock's preferences and its autostart entry live there,
so a trial starts from the default items, never changes the profile an installed
copy owns, and cannot leave an entry that Plasma would load at sign-in. Because
the session never reads that profile, **Start with KDE Plasma** stays disabled
during a trial and the settings window explains that the option needs an
installed copy.

### Compatibility at a glance

| Status | KDE distributions / editions | Plasma | KWin | Qt | KF6 | Kirigami Addons | Quickshell | Checked |
|:---:|---|---|---|---|---|---|---|---|
| ✅ | Fedora 44 KDE | 6.7.5 | 6.7.5 | 6.11.2 | 6.31.0 | 1.13.1 | 0.2.1 | 2026-10-20 |
| 🟡 | Arch Linux (rolling, KDE Plasma) | 6.8.2 | 6.8.2 | 6.12.0 | 6.31.0 | 1.16.0 | 0.3.2 | 2026-10-31 · partial |
| 🟡 | CachyOS (rolling, KDE Plasma) | 6.8.2 | 6.8.2 | 6.12.0 | 6.31.0 | 1.16.0 | 0.3.2 | 2026-10-31 · partial |
| 🟡 | Debian 13.7 KDE (trixie) | 6.3.6 | 6.3.6 | 6.8.2 | 6.13.0 | 1.7.0 | 0.3.0 | 2026-10-30 · partial |
| ⚪ | Nobara KDE, Fedora Kinoite (immutable KDE Plasma), CentOS Stream 10 KDE (EPEL), Rocky Linux KDE, AlmaLinux Kitten KDE | — | — | — | — | — | — | — |
| ⚪ | KDE neon, Kubuntu KDE Plasma | — | — | — | — | — | — | — |
| ⚪ | Manjaro KDE, EndeavourOS KDE Plasma, Garuda KDE | — | — | — | — | — | — | — |
| ⚪ | openSUSE Tumbleweed KDE, openSUSE Leap KDE | — | — | — | — | — | — | — |
| ⚪ | KaOS KDE Plasma, Solus KDE | — | — | — | — | — | — | — |
| ❌ | — | — | — | — | — | — | — | — |

✅ validated · 🟡 builds/starts, validation pending · ⚪ untested, same family · ❌ unsupported · ⏳ pending · — not applicable. X11 is out of scope and non-KDE compositors are unsupported.

<details>
<summary>What each checked row was exercised against</summary>

- **Fedora 44 KDE** — the primary validated environment. It runs the complete
  automated validation graph on every change.
- **Arch Linux (rolling)** — install, trial, menu, folder containers and
  uninstall exercised on one machine on 2026-10-31. Prolonged use and full
  visual inspection remain pending, and Mesa/Zink warnings appear. Not a
  compatibility claim for every Arch installation.
- **CachyOS (rolling)** — on a fresh desktop install on 2026-10-31, the setup
  assistant installed the five missing packages in one step, the checkout built,
  and the trial printed `Configuration Loaded` before it was stopped. CachyOS
  serves optimized `cachyos-extra-v3` builds. The project test suite has not been
  run on CachyOS, and neither menu, container nor prolonged-use review has, so
  this is a compatibility claim for that install only.
- **Debian 13.7 KDE (trixie)** — the setup assistant installed every dependency
  and the dock then built and started on one machine on 2026-10-30. Prolonged
  use and full visual inspection remain pending. Quickshell comes from
  `trixie-backports`, not from the release suite, so the assistant offers to add
  that suite.

</details>

Only Fedora 44 has the complete automated validation graph. List based on the
[KDE Community wiki — Distributions](https://community.kde.org/Distributions).
Plasma 6.8.0 was released on 2026-10-14.

Kirigami Addons is listed on its own because its API moves within a KF6 major
series: 1.16.0 removed the avatar's `initialsColor` and the settings window
stopped loading on Arch, while Fedora 44 (1.13.1) and Debian 13 (1.7.0) kept
working. A rolling distribution can therefore reach an incompatible release
before a fixed one does, and the version belongs in this table next to Qt and
KF6.

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
Validation tests separately
need Python 3, D-Bus Python bindings, PyGObject, `dbus-daemon`,
`desktop-file-utils` and `update-desktop-database`; these are not runtime
requirements.

Use `./scripts-user/setup.sh --check-deps` to inspect the current environment.
Adding `--install-missing` additionally offers the distribution-specific install
command for Fedora, Debian/Ubuntu or Arch and asks before running it. On Debian,
Quickshell is not part of the stable suite: when it has no apt candidate, the
assistant offers to enable the matching `<codename>-backports` source with an
explicit confirmation and installs `quickshell` from it. Declining that offer
keeps the other missing packages installable.

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
A trial run reads and writes its own profile instead, and that profile is
deleted with the trial cleanup unless the confirmation is declined.
Without a saved file, the application uses the defaults in
[`config/PunchiDefaultProfile.js`](config/PunchiDefaultProfile.js), which also supplies the
first-run launcher catalogue and the values restored by **Reset defaults**:

| Setting | Current first-run default |
|---|---|
| Surface | Bottom dock by default; Bottom, Left or Right; no custom top bar yet |
| Pinned items, in order | Dolphin, Konsole, Home, Browser, Kate, System Settings, Discover, Gwenview, Okular, Downloads, Trash |
| Size | 100% of the theme-derived base size |
| Pointer magnification | Enabled, with a maximum scale of 200% |
| Click bounce | Enabled |
| Screens | Every connected screen, one shared profile |
| Virtual desktops and activities | All desktops and activities |
| Visibility | Windows go below (`overlay`), without reserving screen space |
| Reduced motion | Local override off; KDE animation preferences still apply |
| Icons | The user's icon theme, including live KDE theme-change notifications |

These are prototype defaults, not a guarantee that every preset application is
installed. **Browser** names the role instead of an application: the item opens
the browser KDE has as the preferred handler for web links, so it follows the
default chosen in System Settings and never assumes Firefox is present. Changing
settings through Apply or Accept persists the user's values;
later starts load them. An explicit startup mode can override the saved visibility
mode. The current file format is version 13 and accepts versions 1 to 12 through
migration. Version 7 adds the recent-applications switch and visible count,
version 8 stores the icon chosen for a pinned application, version 9 the
folder entries a container keeps out of its popup, version 10 the popup size,
height and icon size, version 11 separate grid, list/detail and fan glyph
sizes, version 12 screen, virtual-desktop and activity selection plus the
two placement switches, and version 13 the recent-applications presentation
and its container view; missing fields in older profiles default to enabled,
five applications, the container presentation with the List view, the
application icon, an unfiltered folder listing, the reference popup
proportions, the theme's glyph sizes, every screen and every desktop/activity.

The **Profile** category exports the pending values as a portable JSON document
with schema `punchi-dock-quickshell/profile` and format version 1. Import also
accepts a raw saved profile, validates every field, and previews the result
before the values become pending edits. A profile contains data only: it cannot
add commands, executable JavaScript, autostart entries, KDE configuration or
file contents. The selected file must be a regular UTF-8 file of at most
256 KiB. Exports are written atomically with owner-only permissions, and a
symbolic link is never overwritten. Autostart remains an installation-level
integration and is not part of a profile.

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
autostart entry, unregisters the window-state desktop entry, and removes only
manifest-listed files. It then offers two ways to finish: **Keep my data** asks
separately about `build/` and the preferences file, and **Remove everything**
deletes the preferences, the legacy `punchi-shell.json` backup, `build/`, the
runtime lock and the window-state registration after one destructive
confirmation. Neither choice touches the source checkout or any KWin recovery
record. `--remove-settings` and `--remove-build` remain available for
non-interactive use; `--keep-build` is a compatibility alias for the default.

### CMake installation

For a prefix-based installation:

```bash
cmake -S . -B "build/build-$(. /etc/os-release && printf '%s' "$ID")" -G Ninja
cmake --build "build/build-$(. /etc/os-release && printf '%s' "$ID")"
cmake --install "build/build-$(. /etc/os-release && printf '%s' "$ID")" --prefix ~/.local
```

The setup assistant and the scripts group one build tree per distribution under
`build/`, as `build/build-debian` or `build/build-fedora`, and `cmake --preset
dev` writes the generic single-machine tree `build/dev`. The flat `build-<ID>`
and plain `build/` trees of the earlier layouts are still read when they are the
only complete ones. `PUNCHI_BUILD_DIR` overrides the location.

This installs `bin/punchi-dock-quickshell`, the QML tree under
`share/punchi-dock-quickshell`, the window backend under
`libexec/punchi-dock-quickshell`, a desktop entry and the hicolor icon. The
entry point resolves its prefix, so it also works with `/usr` or another
`CMAKE_INSTALL_PREFIX`. This route is intended for packaging and advanced
deployments; `scripts-user/setup.sh` remains the guided per-user installer.

`cmake --build "build/build-$(. /etc/os-release && printf '%s' "$ID")" --target uninstall`
removes the files recorded in `install_manifest.txt`.
`cpack --config "build/build-$(. /etc/os-release && printf '%s' "$ID")/CPackConfig.cmake"` creates a
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

The current saved settings describe one shared dock profile applied to every
allowed screen. Per-screen profiles, independent placement or item sets per
monitor, and instance-level storage remain future work; they need stable
instance IDs and a migration that preserves the shared profile.

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
`org.kde.plasma.private.mpris`, the internal Plasma module behind the context
menu's media transport. Window/task integrations and KDE screen-edge behavior
also need testing against the target Plasma/KWin version. Prefer public APIs,
keep internal integrations isolated, and provide graceful unavailability where
a capability can be optional.
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
visual quality, fractional scaling, screen-reader support, physical monitor
hot-plug, other screen layouts or native KDE startup cursor feedback. A
two-screen real-session check covered per-screen docks, screen selection,
primary fallback, virtual-desktop and activity filtering and shared-edge
auto-hide; automated fullscreen capture does not include layer-shell surfaces,
so visual inspection remains manual. The changelog records the current
validation scope and known gaps.

## Development

This QML configuration runs in Quickshell. CMake builds the native KDE adapters
and organizes validation. See [AGENTS.md](AGENTS.md) for project rules and
[CONTRIBUTING.md](CONTRIBUTING.md) for the branch and evidence workflow. Configure
and build with the shared preset, then run the compositor-free graph:

```bash
cmake --preset dev
cmake --build --preset dev
ctest --preset headless
```

`ctest --preset headless` runs the `unit` and `qml` labels without a graphical
session; GitHub Actions runs the same script, `scripts-dev/ci-headless.sh`, on
Fedora 44. The complete graph adds the `session` label, which needs a live KDE
Plasma/KWin Wayland session:

```bash
ctest --test-dir build --output-on-failure
```

## Modular structure

| Directory | Responsibility |
|---|---|
| `shell.qml` | Compose shell modules |
| `modules/dock/` | Dock window, view, context menus and Trash confirmation |
| `modules/folders/` | Folder container popups, layouts and navigation |
| `modules/settings/` | Settings window, categories, item editors and profile exchange |
| `components/` | Shared visual interaction primitives |
| `services/` | Model data, profile exchange and coordination |
| `config/` | First-run profile, reactive settings, document validation and shared metrics |
| `adapters/kde/` | KDE adapters for launching, media, updates, Trash, motion and window state |
| `tests/` | Component, foundation, and real-session checks |
| `.agents/skills/` | Repository-scoped development workflows |

English is the source language. Only English fallback strings are supported at
this stage. Settings update existing surfaces through reactive state.

## Author and development assistance

Punchi Dock Quickshell is developed by PunchiSoft. AI coding agents are used as
development support for implementation, review and documentation. The maintainer
remains responsible for all changes, validation and published content.

## Origins and attribution

The base of this project is [Punchi Dock Remastered](https://github.com/PunchiSoft/punchi-dock-remastered),
the Plasma applet whose dock, item model, motion and interaction this port
rebuilds. It also takes architectural and visual inspiration from
[Caelestia Shell](https://github.com/caelestia-dots/shell), while implementing
desktop integration for KDE/KWin. See [NOTICE.md](NOTICE.md) for reused code,
assets and attribution.

## Made with love

Made with love, for the community. A native port of the [Punchi Dock
Remastered](https://github.com/PunchiSoft/punchi-dock-remastered) plasmoid,
built to go past what a plasmoid can do in KDE Plasma. Some say docks went out
of fashion, like the punchi punchi; only Windows forgot about them, and Linux
never will.

**Linux for everyone!**

## License

GPL-3.0-or-later. See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).

The agent skills under [`.agents/skills/`](.agents/skills/README.md) may be reused
and adapted. Keep their `license` field, the copyright notice and any
`metadata.source` entry that names the project they came from, and citing this
repository with the commit you took them from is appreciated. The skill catalog
states the exact conditions.
