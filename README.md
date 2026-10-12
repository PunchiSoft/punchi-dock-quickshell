# Punchi Dock Shell

<p align="center"><img src="assets/icons/punchi-shell.svg" width="120" alt="Punchi Dock Shell logo"></p>

<p align="center"><strong>An animated, configurable dock for KDE Plasma, built with Quickshell and native Qt/KDE integration.</strong></p>

Punchi Dock Shell combines animated magnification, configurable application
launchers, KDE context actions, and persistent preferences. It runs alongside
Plasma through reversible start and stop scripts.

**Development status:** early prototype. Version **0.1.0** is the first versioned
snapshot. Compatibility and validation limits are documented below; see the
[changelog](CHANGELOG.md) for recorded progress and known issues.

[Architecture](docs/architecture.md) · [Development and testing](docs/development.md) ·
[Roadmap](docs/roadmap.md) · [Attribution](NOTICE.md) · [License](LICENSE)

## Current features

- Continuous hover magnification, themed tooltips, an expanding background and
  two-hop launch feedback, with reduced motion support.
- Configurable pinned applications: discover and search installed applications
  through KDE, add or reorder launchers, and save preferences. Eight preset
  launchers provide the initial configuration.
- Native application launching through KService and KIO, with Wayland activation
  integration.
- Launcher context menus with KDE desktop actions, recent documents, unpinning
  and KDE Places navigation for eligible file-manager launchers.
- Dock settings for icon size, magnification, bounce, reduced motion and
  visibility: Always visible, Hide automatically, Dodge windows or Windows go below.
- Keyboard navigation and pending settings edits through Apply, Accept and Close.

Running-application indicators are under development. Existing-window activation,
a separate panel, an application-launcher surface
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

## Compatibility and validation

The initial target is Linux with KDE Plasma/KWin on Wayland. The observed
development environment is Fedora with Quickshell 0.2.1, Qt 6.11.2 and KDE
Frameworks 6.30.0. Quickshell and Qt must be ABI-compatible; other combinations,
distributions, X11 and other compositors require their own validation.

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
