---
name: testing
description: Validate QML interactions, Quickshell loading, reversible KDE coexistence, and real desktop behavior with isolated test state. Use when adding or running a test, reproducing a bug, or deciding which evidence a change needs.
license: GPL-3.0-or-later
---

# Testing

Read `docs/development.md` and the affected tests. Define observable behavior
before selecting tests: a test exists to catch a named regression.

## Procedure

1. State the observable behavior and the failure that must be caught.
2. Choose the cheapest level that can observe it: Qt Quick Test for Qt-only
   views, a Quickshell probe for registered shell types, C++ for native logic,
   a real session for KWin behavior.
3. Rebuild and configure the graph only when native code or build registration
   changed.
4. Run the scoped test first. Escalate to the complete suite only when the
   scoped result depends on it, and say which dependency required it.
5. Confirm isolation: each test owns temporary data and cleans processes,
   caches, and sockets on success, failure, signal, and timeout.
6. Record what could not be executed, and at which level it stays unverified.

## Commands

```bash
cmake --preset dev
cmake --build --preset dev
ctest --preset headless
ctest --test-dir build --output-on-failure
ctest --test-dir build --output-on-failure -R '^adapter_contract$'
```

## Rules

Use Qt Quick Test for Qt-only views and real Quickshell probes for registered
shell types. Lint requires matching type metadata. KWin behavior needs a real
session; visual approval requires inspection, not merely frame rendering.
Each test owns temporary data and cleans processes, caches, and sockets even
on signal/timeout. Preserve behavioral assertions and record unavailable checks.

A documentation-only change runs no test. READMEs, `docs/`, `AGENTS.md`, the
changelog and skill prose are observed by no test, so a green suite is not
evidence about them and an unbuilt tree is not a failure of the change. Add only
the check whose input you edited, such as `project_foundation` for a skill's
frontmatter or `component_naming` for `tests/naming-baseline.json`. Documentation
shipped with code is validated as code.
Always verify the scoped restore route when changing startup/window lifecycle.
Close every dock and settings window and stop every Punchi Dock Quickshell
process started for a test; leave no test instance running on success, failure,
signal, or timeout. Leave the user's own instance untouched.

## Gotchas

- Quickshell has no `PanelWindow` backend offscreen. A test that creates a
  `FloatingWindow` proves the content, not layer-shell placement or KWin stacking.
- Qt Quick Test cannot load adapters that import Quickshell; the runtime probe
  exists because of that boundary.
- Changing `XDG_DATA_HOME` does not isolate every mounted-volume trash location.
  Never run an automated `emptyTrash` against real `trash:/`.
- Tests fail on unexpected warnings in executed paths. The documented KIO
  systemd message is one exception, not permission to ignore a new warning.
- A passing offscreen test is neither visual approval nor a KDE capability check.
- Restoring owned KWin settings is verified through the scoped restore route, not
  by terminating the shell or Plasma.

## Synthetic contract checks after a modification

When a change adds or edits a view/service → adapter call, run the adapter
contract probe before the full suite:

```bash
ctest --test-dir build -R '^adapter_contract$' --output-on-failure
```

It loads the real adapters inside Quickshell and fails when a callable or
property consumed by a service is missing. QML mocks prove service behavior but
not that link. Extend `tests/adapter_contract_runtime_test.py` when adding a
consumer member; check `typeof` and property membership, never invoke
side-effecting actions (`openTrash`, launch, media commands).

Runtime probes must also assert that Quickshell output has no `WARN`, `Warning:`,
`ERROR`, or `Error:` lines; a warning on an unexecuted path needs its own
synthetic invocation.

## KDE capability and version tests

When a change uses a feature new to Plasma 6.8 or another newer KDE release,
first probe the installed capability and keep a fallback for every still-supported
version. Record the tested Plasma/KWin/Qt/KF6 versions and distinguish an optional
6.8 path from the project's declared minimum. Do not silently raise the minimum,
skip an existing behavioral test, or treat offscreen success as native-session
validation. Changing the minimum version requires explicit user authorization.
