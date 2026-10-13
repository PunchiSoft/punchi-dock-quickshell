# Punchi Dock Shell

<p align="center"><img src="assets/icons/punchi-shell.svg" width="120" alt="Punchi Dock Shell logo"></p>

<p align="center"><strong>An animated, configurable dock for KDE Plasma, built with Quickshell and native Qt/KDE integration.</strong></p>

Punchi Dock Shell combines animated magnification, configurable application
launchers, KDE context actions, and persistent preferences. It runs alongside
Plasma through reversible start and stop scripts.

**Development status:** early prototype. Current delivery: **0.1.08**.
The first Git snapshot was published as `0.1.0`, equivalent to `0.1.00` under
the current delivery counter. Each delivery commit advances the counter once;
see [versioning](docs/versioning.md) and the [changelog](CHANGELOG.md).
Compatibility and validation limits are documented below.

[Architecture](docs/architecture.md) · [Development and testing](docs/development.md) ·
[Roadmap](docs/roadmap.md) · [Attribution](NOTICE.md) · [License](LICENSE)

## Current features

- Continuous hover magnification, themed tooltips, an expanding background and
  two-hop launch feedback, with reduced motion support.
- Configurable pinned applications: discover and search installed applications
  through KDE, add or reorder launchers, and save preferences. Eight preset
  launchers provide the initial configuration.
- Native application launching through KService and KIO, with Wayland activation
  integration. Normal clicks activate an existing KDE window or minimize an
  eligible active window before considering a launch; see
  [window activation](docs/window-activation.md) for validation limits.
- Startup launch coordination, window cycling, known running unpinned applications
  and middle-click New Window through KDE.
- Launcher context menus with KDE desktop actions, recent documents, unpinning
  and KDE Places navigation for eligible file-manager launchers.
- Dock settings for icon size, magnification, bounce, reduced motion and
  visibility: Always visible, Hide automatically, Dodge windows or Windows go below.
- Keyboard navigation and pending settings edits through Apply, Accept and Close.

Running-application indicators and existing-window activation are implemented
with isolated validation; physical KDE checks remain pending. A separate panel,
an application-launcher surface
and additional controls remain future work. See the [roadmap](docs/roadmap.md).

## Run and return to KDE

Install a Quickshell package compatible with its Qt libraries and the native
Qt/KDE build dependencies listed in the [development guide](docs/development.md).
Then run from the checkout directory:

```bash
cmake -S . -B build -G Ninja
cmake --build build
./scripts-user/start.sh
```

The start script registers this build's hidden KDE window-state backend and
refreshes the application service cache. A themed dot marks pinned apps with open
windows. See [running markers](docs/running-applications.md) for scope, cleanup and
live-session validation limits.

To try panel behavior, use `./scripts-user/start.sh reserve` (Always visible),
`./scripts-user/start.sh dodge-windows` (hide on window overlap), or
`./scripts-user/start.sh overlay` (above windows without reservation). An explicit
mode switches a running instance. See [panel modes](docs/panel-modes.md).

Use `./scripts-user/start.sh autohide` to try automatic hiding and bottom-edge
reveal. This mode does not detect window overlap.

Keep the foreground terminal open. To stop, press Ctrl+C there, or use another terminal:

```bash
./scripts-user/restore-kde.sh
```

Plasma stays running. The dock coexists with the existing desktop and does not
replace Plasma panels, settings, autostart, or session services. The restore
script selects only this project's Quickshell configuration.

## Dock configuration

Right-click the dock and choose Configure Dock to open its settings.
With Punchi Dock Shell running, `./scripts-user/settings.sh` also opens the window.
Apply saves pending changes without closing; Accept saves and closes; Close
discards pending changes. Preferences persist independently of Plasma. See
[dock settings](docs/settings.md) for controls and storage.

Preferences are stored separately for each operating-system user in
`$XDG_CONFIG_HOME/punchi-shell.json`, or `~/.config/punchi-shell.json` when
`XDG_CONFIG_HOME` is unset. They are not stored in the installed program files.
Without a saved file, the application uses the defaults in
[`ShellSettings.qml`](config/ShellSettings.qml):

| Setting | Current first-run default |
|---|---|
| Surface | Bottom dock; no custom top bar yet |
| Pinned items, in order | Dolphin, Konsole, Firefox, Kate, System Settings, Discover, Gwenview, Okular, Trash |
| Size | 100% of the theme-derived base size |
| Pointer magnification | Enabled, with a maximum scale of 200% |
| Click bounce | Enabled |
| Visibility | Windows go below (`overlay`), without reserving screen space |
| Reduced motion | Local override off; KDE animation preferences still apply |
| Icons | The user's icon theme, including live KDE theme-change notifications |

These are prototype defaults, not a guarantee that every preset application is
installed. Changing settings through Apply or Accept persists the user's values;
later starts load them. An explicit startup mode can override the saved visibility
mode. The current file format is version 2 and accepts version 1 through migration.

## Installation and sharing

The current installation route is the source-checkout workflow above. This is
not a `.plasmoid` package: Quickshell runs the QML interface as a separate
application alongside Plasma. Quickshell supports named configurations and
running a configuration directly from a directory with `--path`.
See its [configuration guide](https://quickshell.org/docs/v0.2.1/guide/introduction/).

A complete installation needs compatible Quickshell/Qt packages, the KDE runtime
libraries and QML modules used by the project, and both compiled native components:
the `Punchi.Kde` QML plugin and `punchi-window-state` backend. KDE integrations
include KIO, KService, KWindowSystem, Activities Stats, Kirigami, TaskManager and
the Plasma MPRIS module. Building from source also needs the development packages
and tools listed in the [development guide](docs/development.md).
Sharing only `shell.qml`, or copying a build directory to another distribution,
does not provide a complete, verified installation.

The distribution approach discussed for future releases is:

- Publish source with reproducible build instructions.
- Prepare distribution-specific packages, such as RPM and DEB, with declared
  dependencies, installed native modules and an application-menu launcher.
- Make startup at login an explicit user preference; it is not installed today.
- Keep program updates separate from personal settings, and make uninstalling
  the program distinct from explicitly removing personal preferences.

These packaging and launcher steps are planned, not available release artifacts.
The repository does not currently provide a finished end-user installer or a
validated cross-distribution binary package.

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

The initial target is Linux with KDE Plasma/KWin on Wayland. The observed
development environment is Fedora with Quickshell 0.2.1, Qt 6.11.2 and KDE
Frameworks 6.30.0. Quickshell and Qt must be ABI-compatible; other combinations,
distributions, X11 and other compositors require their own validation.

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
Punchi Shell's personal settings file; our own format updates must migrate it.
Broad update compatibility remains a maintenance goal, not an established
guarantee of this prototype.

For the 0.1.0 snapshot, configuration and compilation passed, as did 11 of 12
CTest groups. The enabled `settings_reload` test failed: the startup panel-mode
override was reapplied after an engine reload instead of preserving the changed
mode. This remains a known issue recorded in the [changelog](CHANGELOG.md).

An isolated Wayland session probe passed startup, duplicate prevention, rendering,
hide/reopen and scoped restoration. Automated checks do not establish final
visual quality, fractional scaling, multi-monitor behavior, screen-reader support,
or native KDE startup cursor feedback. See the [development guide](docs/development.md)
and the historical [stage 1](docs/stage-1.md), [stage 2](docs/stage-2.md) and
[stage 3](docs/stage-3.md) records for evidence and limits.

## Development

This QML configuration runs in Quickshell. CMake builds the native KDE adapters
and organizes validation. See the [development guide](docs/development.md)
for commands and [AGENTS.md](AGENTS.md) for project rules.

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

## Origins and attribution

The project draws on [Punchi Dock Remastered](https://github.com/PunchiSoft/punchi-dock-remastered)
and takes architectural and visual inspiration from
[Caelestia Shell](https://github.com/caelestia-dots/shell), while implementing
desktop integration for KDE/KWin. See [NOTICE.md](NOTICE.md) for reused code,
assets and attribution.

## License

GPL-3.0-or-later. See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).
