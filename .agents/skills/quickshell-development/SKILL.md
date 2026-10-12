---
name: quickshell-development
description: Develop Quickshell QML modules using the installed API version, reload lifecycle, and reversible configuration entry points.
---

# Quickshell Development

Check `qs --version`, `qs --help`, and installed QML type metadata before using
online examples. Keep `shell.qml` a composition root and feature windows modular.
Static type metadata is not proof that ordinary Qt runners can load Quickshell's
statically registered modules. Test actual shell loading and clean shutdown.
Keep module state reactive across reloads and check resource ownership.
Pair the Quickshell binary with its Qt ABI; do not copy arbitrary development
branch dependencies from Caelestia. Preserve foreground start, no duplicate
instances, and the exact-configuration restore path.
