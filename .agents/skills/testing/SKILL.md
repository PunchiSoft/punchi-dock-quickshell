---
name: testing
description: Validate QML interactions, Quickshell loading, reversible KDE coexistence, and actual desktop behavior with isolated test state.
---

# Testing

Read `docs/development.md` and the affected tests. Define observable behavior
before selecting tests. Rebuild/configure the graph before complete CTest.
Use Qt Quick Test for Qt-only views and real Quickshell probes for registered
shell types. Lint requires matching type metadata. KWin behavior needs a real
session; visual approval requires inspection, not merely frame rendering.
Each test owns temporary data and cleans processes, caches, and sockets even
on signal/timeout. Preserve behavioral assertions and record unavailable checks.
Always verify the scoped restore route when changing startup/window lifecycle.

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
side-effecting actions (`openTrash`, launch, media commands). Qt Quick Test
cannot load adapters that import Quickshell, so keep this check in a `qs` probe.

Qt Quick Tests fail on warnings in executed paths. Runtime probes must also
assert that Quickshell output has no `WARN`, `Warning:`, `ERROR`, or `Error:`
lines; a warning on an unexecuted path needs its own synthetic invocation.
