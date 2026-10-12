# Punchi Shell

<p align="center"><img src="assets/icons/punchi-shell.svg" width="120" alt="Punchi Shell logo"></p>

<p align="center"><strong>A modular desktop interface for KDE, built with Quickshell and QML.</strong></p>

**Version: 0.1.0** — initial development snapshot. See the
[changelog](CHANGELOG.md) for the recorded progress.

Punchi Shell explores a unified desktop interface with a dock, panel, launcher,
and control surfaces. It draws on
[Punchi Dock Remastered](https://github.com/PunchiSoft/punchi-dock-remastered) and
[Caelestia Shell](https://github.com/caelestia-dots/shell), while targeting KDE/KWin.

**Current stage:** an eight-launcher dock with a continuous zoom wave, themed speech
balloons, and a background that expands horizontally. Click or Enter/Space launches
the configured application with a two-hop bounce; arrow keys navigate and Escape
hides the surface. Files opens Dolphin, Terminal opens Konsole, and Browser opens
Firefox. Window tracking and activation of existing windows are future stages.

[Architecture](docs/architecture.md) · [Development and testing](docs/development.md) ·
[Roadmap](docs/roadmap.md) · [Attribution](NOTICE.md) · [License](LICENSE)

## Run and return to KDE

With a compatible Quickshell package installed, run from this directory:

```bash
cmake -S . -B build -G Ninja
cmake --build build
./scripts-user/start.sh
```

To try panel behavior, use `./scripts-user/start.sh desktop` (below windows),
`./scripts-user/start.sh reserve` (reserve base space), or
`./scripts-user/start.sh overlay` (above windows without reservation). An explicit
mode switches a running instance. See [panel modes](docs/panel-modes.md).

Keep the foreground terminal open. To stop, press Ctrl+C there, or use another terminal:

```bash
./scripts-user/restore-kde.sh
```

Plasma stays running. This stage adds a surface above the existing desktop and
does not modify panels, settings, autostart, or session services. The restore
script selects only this project's Quickshell configuration.

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
this stage. Modularity, reactive updates, keyboard access, and reversible desktop
coexistence are core project requirements.

## Development

This QML configuration runs in Quickshell. CMake builds the native KDE launch
module and organizes validation. See [the development guide](docs/development.md)
for exact commands and evidence limits, and [AGENTS.md](AGENTS.md) for project rules.

Quickshell and Qt must be ABI-compatible. Other distributions and compositor
features need their own tests before support is claimed. The initial tested
environment and results are recorded in [stage 1](docs/stage-1.md) and [stage 2](docs/stage-2.md), and [stage 3](docs/stage-3.md).

## License

GPL-3.0-or-later. See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).

## Dock configuration

Right-click the dock and choose Configure Dock to open its settings.
With Punchi Shell running, `./scripts-user/settings.sh` also opens the window.
Apply saves pending changes without closing; Accept saves and closes; Close
discards pending changes. Preferences persist independently of Plasma. See
[dock settings](docs/settings.md) for controls and storage.
