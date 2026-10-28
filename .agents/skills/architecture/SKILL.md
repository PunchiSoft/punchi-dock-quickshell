---
name: architecture
description: Define modular Quickshell feature boundaries, services, shared QML components, and KDE adapter dependencies. Use when a change adds a service, a module, a shared component or an adapter, or when reviewing dependency direction.
license: GPL-3.0-or-later
---

# Architecture

Decide ownership before writing code: one behavior has one owner, one input, one
output, and an explicit consumer.

## Procedure

1. Name the behavior and the layer that must own it: shell composition, module,
   shared component, service, KDE adapter, config, or user script.
2. List inputs, outputs, consumers, side effects, and who reacts when the state
   changes.
3. Check whether Quickshell or KDE already provides it. A provider is not
   wrapped merely to reproduce the diagram.
4. Confirm the dependency direction you are about to add is already recorded in
   `docs/architecture.md`.
5. Add `adapters/kde/` only for a verified capability gap, and record the gap,
   the tested version, the fallback, and the evidence.
6. Extract by responsibility when a file passes roughly 300-400 lines, never by
   quota.
7. Update the architecture record in the same change.

## Boundaries

Keep root composition small, views declarative, providers independent of
visuals, and desktop integrations behind capability-aware adapters. Read
`docs/architecture.md`. Do not create unused layers or catch-all managers.
Document dependency changes and preserve safe coexistence with Plasma.

Apply the native-first boundary from `kde-integration`: use existing Quickshell
or KDE providers before adding a service or adapter. Do not duplicate KDE
theming, shortcuts, notifications, autostart, displays or compositor behavior in
project services.

## Gotchas

- `shell.qml` composes enabled modules. A `Loader`, a settings write, or a D-Bus
  call there is a boundary violation even when it is five lines.
- A service that imports a visual component cannot be loaded by a Qt Quick Test
  and couples data to presentation. Keep services QML-only and inert.
- Two modules writing the same settings key is a hidden dependency: one service
  owns persistence, the other consumes it.
- A component importing an adapter inverts the flow. The component emits intent;
  a service reaches the adapter.
- `components/` accepts a primitive only after a second confirmed consumer. A
  primitive with one user is a module detail wearing a shared name.

## Validation

```bash
ctest --test-dir build --output-on-failure -R 'architecture_contract|adapter_contract|dock_components'
```

`architecture_contract` parses the quoted relative imports of every layer
directory and fails on an upward import or a root-level declaration in
`shell.qml`. A deliberate exception goes in `tests/architecture-allowlist.json`
with a written reason; a stale entry fails too.

- The ownership statement names exactly one consumer per output.
- `docs/architecture.md` matches the tree; a stale record is a defect.
