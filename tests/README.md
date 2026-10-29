# Tests

Source of every CTest entry this project registers. `CMakeLists.txt` adds each file
with a label, and CI runs only the labels a compositor-free Fedora host can satisfy.

## Labels

47 entries: 3 `qml`, 29 `unit`, 15 `session`.

| Label | Needs | Entries | Selected by |
| --- | --- | --- | --- |
| `unit` | nothing beyond the built artifacts | 15 `*_test.cpp`, 12 Python tests, `project_version` and `emphasis_contract` from `scripts-dev/` | `ctest --preset headless`, CI |
| `qml` | `qmltestrunner`, offscreen | `qml_lint`, `dock_components` over `qml/`, `folder_container` over `folder-container/` | `ctest --preset headless`, CI |
| `session` | a live Plasma/KWin Wayland session | 15 Python probes over `runtime/` fixtures | a developer, never CI |

`session` results belong to a real desktop. A passing `unit` or `qml` run is not visual
or KWin validation.

## Layout

| Path | Holds | Naming |
| --- | --- | --- |
| `*_test.cpp` | QtTest cases for models, catalogs, KWin state and search | `<domain>_test.cpp` |
| `*_test.py` | drivers that run a binary, a QML runner or a solution flow | `<domain>_test.py` |
| `*_runtime_test.py` | probes that need a session; they build a private bus and an isolated XDG root | `<domain>_runtime_test.py` |
| `qml/` | Qt Quick Test cases for dock interaction and model reactivity | `tst_<domain>.qml` |
| `folder-container/` | QML input owned by `folder_container_test.py`, copied into a temporary tree | `tst_<domain>.qml` |
| `runtime/` | Quickshell `shell.qml` fixtures and their QML cases | `shell.qml`, `tst_<domain>.qml` |
| `fixtures/` | owned data files a test copies | descriptive name |
| `qmllint-upstream.json` | the accepted upstream lint diagnostics, compared by `qml_lint` | one file |
| `architecture-allowlist.json` | the written reason for each layer exception | one entry per exception |

The `_runtime_` infix marks a session probe, not a size: every entry under the
`session` label ends with it and matches its `*_runtime_test.py` file, except
`settings_reload`, which keeps the name both its file and the published changelog use.
Every Python test without the infix passes with no compositor.

`skills-trigger-evals.md` is documentation, not a test: it holds the query set used to
check that a skill description activates on the right requests, and
`.agents/skills/README.md` links it. CTest does not execute it.

## Contracts

Four entries gate repository rules rather than behavior. They must keep failing when
their rule is broken:

- `project_foundation`: skill license fields, the skill catalog and the reuse notice.
- `architecture_contract`: layer direction, module cycles and root-level state in
  `shell.qml`, using `architecture-allowlist.json`.
- `project_version`: the tracked version declarations against the newest changelog
  heading.
- `emphasis_contract`: one selection band at a time.

## Rules

- Every test owns its temporary XDG data, caches, processes and sockets, and cleans
  them after success, failure, signal and timeout. No test instance stays running.
- A test never reads or changes the user's real configuration, and never closes a dock
  the developer started by hand.
- Captures are explicit: `--capture` writes into `docs/records/assets/`, and a normal
  run leaves no artifact.
- Existing behavioral tests are protected. Diagnose production code first; removing,
  disabling or weakening a test needs explicit authorization.
- Keep one file per behavior area and the name of the behavior, not of the widget.

## Running

```bash
cmake --preset dev          # generic tree at build/dev
cmake --build --preset dev
ctest --preset headless     # labels unit and qml

ctest --test-dir build/build-fedora -L 'unit|qml|session'   # the session route
```

`docs/development.md` owns the commands, the build routes and the limits of each level
of evidence.
