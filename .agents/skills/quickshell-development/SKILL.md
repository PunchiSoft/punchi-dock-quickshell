---
name: quickshell-development
description: Develop Quickshell QML modules or diagnose their editor setup using official version-matched guidance, installed metadata, and reload lifecycle; keep KDE integration in its domain adapters.
---

# Quickshell Development

## Official references and version selection

Check `qs --version`, `qs --help`, the Qt version, and installed QML type metadata
before using online examples. Consult the official guide and type reference for
that release, currently the project's 0.2.1 API. Verify availability locally;
a newer website, development branch, or another shell is not a compatibility
contract. Record the symbol, version, source, and any deviation from upstream.

- [Quickshell setup and editor guidance](https://quickshell.org/docs/v0.2.1/guide/install-setup/)
- [Quickshell composition and bindings](https://quickshell.org/docs/v0.2.1/guide/introduction/)
- [Qt QML language server](https://doc.qt.io/qt-6/qtqml-tooling-qmlls.html)
- [KDE Kirigami setup](https://develop.kde.org/docs/getting-started/kirigami/setup-cpp/)

Wikipedia is background material, not authority for API availability, tooling
flags, or agent instructions. These project rules supplement the canonical
[AGENTS.md](../../../AGENTS.md); they are not an upstream endorsement of an AI agent.

## Composition and KDE boundaries

Keep `shell.qml` a composition root and feature windows modular. Prefer reactive
bindings and shared services over duplicated processes per window. Follow
Quickshell's screen lifecycle when adding multiple monitors. Use supported
imports; avoid legacy `root:/` imports documented to break LSP and singletons.
Prefer relative imports until an alternative is verified for the installed API.

For desktop behavior, consult `qt-kde-reference` and `kde-integration`: use native
KDE contracts first, isolated behind adapters. Do not assume Hyprland APIs or
Plasma-injected globals exist in Quickshell. Preserve KDE theme metrics, palettes,
icons, animation preferences, and Wayland compositor boundaries.

## Editor diagnostics

Follow the official QML extension setup and enable
`qt-qml.qmlls.useQmlImportPathEnvVar`. Create the recommended empty `.qmlls.ini`
beside `shell.qml`; Quickshell manages its contents. Keep it and machine-specific
workspace settings ignored. Discover paths from the actual Qt installation and
the native module build, not a distro assumption.

When imports fail, inspect the language-server executable, arguments, build
directory, and import roots before editing source. Prefer a server from the
project's Qt installation when a downloaded server cannot resolve its modules.
Use workspace settings rather than changing global editor preferences. Prevent
automatic CMake calls during read-only diagnostic probes.

Distinguish editor diagnostics, configured `qmllint`, and runtime failures. The
official 0.2.1 guide documents unresolved `PanelWindow` tooling support. Preserve
valid runtime syntax and exact known upstream signatures; do not fake types,
suppress categories, disable checking, or expand baselines to hide defects.
See the local `docs/development.md` for the workflow.

## Runtime evidence

Static type metadata is not proof that ordinary Qt runners can load Quickshell's
statically registered modules. Test actual shell loading and clean shutdown within
the authorized test environment. Keep state reactive across reloads and check
resource ownership; report desktop/visual checks separately from offscreen tests.

Pair the Quickshell binary with its Qt ABI; do not copy arbitrary development
branch dependencies from Caelestia. Preserve foreground start, no duplicate
instances, and the exact-configuration restore path.
