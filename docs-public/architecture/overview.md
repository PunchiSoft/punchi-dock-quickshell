# Overview

Punchi Dock Quickshell is a Quickshell configuration with a native Qt/KDE QML
module. Quickshell hosts the QML surfaces; KDE Frameworks and supported KWin
interfaces own desktop integration. The application is not a Plasma applet: it
runs as a separate Wayland client alongside Plasma and never replaces panels,
settings or session services.

## Composition

`shell.qml` only composes the enabled top-level modules. `ShellRoot` builds them
from independent module trees; each feature has a small window wrapper and a
Qt/Kirigami view. A shared component receives its inputs and emits intents, so
neither a delegate nor a popup host reaches a service or an adapter directly.

The preferred flow is:

```text
view intent → service → adapter → desktop
                  ↑                    │
                  └── reactive state ──┘
```

Services never import visual components, and settings update existing surfaces
through bindings and notifications rather than a restart. The root configuration
declares no state or logic of its own; `tests/architecture_test.py` fails when it
does.

## Layers

| Directory | Owns | Never holds |
| --- | --- | --- |
| `shell.qml` | composition of the enabled top-level modules | state, logic, commands |
| `modules/<feature>/` | one surface and its own interaction | shared primitives |
| `components/` | visual primitives with two or more confirmed consumers | feature state, commands |
| `services/` | data and coordination | visual items |
| `adapters/kde/` | the KDE boundary: QML adapters, `native/` C++ grouped by domain, `protocols/`, `window-state/` | dock surfaces |
| `config/` | settings schema, defaults and shared design metrics | persistence side effects |
| `tests/` | every CTest entry | shipped QML |
| `scripts-user/` | reversible user entry points and their `lib/` | developer-only tooling |
| `scripts-dev/` | developer tooling | runtime dependencies |

No circular dependencies, catch-all managers or business logic in `shell.qml` are
allowed. A layer exception needs a written reason in
`tests/architecture-allowlist.json`, and a stale entry fails the test too.

## Modules

| Module | Surface |
| --- | --- |
| `modules/dock/` | Dock window, view, context menus and Trash confirmation |
| `modules/menu/` | Fullscreen application menu surface, header, category sections and backdrop |
| `modules/recent/` | Recent-applications container popup |
| `modules/folders/` | Folder container popups, layouts and navigation |
| `modules/settings/` | Settings window, categories, item editors and profile exchange |

A future top bar belongs in its own `modules/topbar/` module, sharing confirmed
components and services, including media controls, rather than requiring a second
project. Quickshell supplies window hosting; KDE integration is connected
explicitly through the adapters.

## Startup configuration

The root configuration opts into Quickshell's `UseQApplication` and
`RespectSystemStyle` startup pragmas. KDE QQC2 Desktop Style needs `QApplication`
for its QStyle-backed controls, and respecting the system avoids Quickshell's
default Fusion override, preserving explicit user style choices. The settings
view owns a Kirigami Window color set plus native font and palette role bindings
instead of inheriting the scroll container's View colors. These startup options
require a Punchi Dock Quickshell process restart; ordinary settings stay live.

The shell does not import Plasma Core's Dialog QML type, which removes its
duplicate visible-property cache and localization-context thread mismatch from
the startup path. KDE application behavior remains in Frameworks adapters, and
popup hosting uses Quickshell's public API rather than PlasmaQuick's private C++
window API. The pragmas were verified with the installed Quickshell 0.2.1
revision. No private style imports or system configuration writes are needed.

## Testing split

`tests/` separates three kinds of evidence:

- Qt Quick Test exercises interaction and model reactivity without loading
  Quickshell's statically registered runtime types.
- Real-session probes load the same Dock window through Quickshell, then check
  rendering and lifecycle in an isolated runtime directory.
- Repository contracts check layer direction, names, versions and emphasis.

A passing offscreen test is not visual or KWin validation. The labels and the
commands live in [Development](../development.md).

## Where files live

The physical map is the **Repository tree** section of
[CONTRIBUTING.md](../../CONTRIBUTING.md). Generated and machine-local paths are
ignored:

| Ignored path | Purpose |
| --- | --- |
| `build/build-<ID>/` | one build tree per distribution; `build/dev` for the preset |
| `scratch/`, `backup/` | disposable local work and safety copies |
| `.qmlls.ini` | editor QML language-server metadata, regenerated on demand |

## Future structure

The current saved settings describe one shared dock profile applied to every
allowed screen. Per-screen profiles, independent placement or item sets per
monitor, and instance-level storage remain future work; they need stable instance
IDs and a migration that preserves the shared profile. KConfig is the recommended
native KDE storage option to evaluate as configuration expands. The current
implementation still uses JSON, and any migration must preserve existing
preferences.
