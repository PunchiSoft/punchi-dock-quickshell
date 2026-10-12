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
