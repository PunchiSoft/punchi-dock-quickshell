# Development scripts

Tooling that never reaches a user installation. Python is not a runtime dependency of
the shell, and nothing here is imported by `shell.qml`.

## Gates

| Script | Purpose | Used by |
| --- | --- | --- |
| `ci-headless.sh` | Installs the Fedora packages and runs the `unit`/`qml` presets on a compositor-free host | CI |
| `check-version.py` | Compares every tracked version declaration with the newest dated changelog heading | `project_version` |
| `check-emphasis.py` | Verifies the one-emphasis-band contract on every row that paints a band | `emphasis_contract` |
| `validate-qml.py` | Lints the QML tree and compares the result with the accepted upstream diagnostics in `tests/qmllint-upstream.json` | `qml_lint` |

## Isolated harnesses

| Script | Purpose |
| --- | --- |
| `run-isolated.py` | Runs one test command with parent-owned temporary XDG directories and cleans them afterwards |
| `run-private-bus.py` | Runs model tests on a bus with no host service auto-activation directory |
| `build_dir.py` | Resolves the build tree through `scripts-user/lib/build-dir.sh` so scripts and tests never repeat the rule |

## Session probes

Each one needs a live Plasma/KWin Wayland session and passes `--isolated` or `--capture`
only when asked. They connect to the running compositor; they never restart Plasma.

| Script | Purpose |
| --- | --- |
| `verify-session.py` | Exercises the real entry point, the scoped restore and the dock surface lifecycle |
| `verify-settings.py` | Checks settings persistence and window lifecycle in an isolated Wayland session |
| `verify-panel-modes.py` | Confirms live panel modes and the actual layer-shell requests |
| `probe-kde-windows.py` | Read-only KDE window-access diagnostic; not a runtime backend |

## Records

| Script | Purpose |
| --- | --- |
| `prune-evidence.py` | Reports record evidence no record cites that outlives the retention window, and deletes it with `--apply` |

## Rules

- A script here may fail loudly, but it must not modify the developer's configuration,
  desktop settings or a running dock.
- Anything that starts a dock, a bus or a directory tree owns it and cleans it on
  success, failure, signal and timeout.
- A check that a CTest entry runs keeps its name in `CMakeLists.txt`; a standalone
  diagnostic is never presented as validation.
