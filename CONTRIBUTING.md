# Contributing

Read [AGENTS.md](AGENTS.md) first; it is canonical for this repository. Use
English and keep each change scoped to one concrete behavior or responsibility.
Punchi Dock Quickshell is alpha software: behavior, configuration and native APIs
may change without migration.

## Before you start

- Read the [README](README.md) and its Known limitations.
- Check the [compatibility table](README.md#compatibility-at-a-glance); X11 and
  non-KDE compositors are out of scope.
- Report security problems through [SECURITY.md](SECURITY.md), never in a public
  issue or pull request.
- Open a [bug report](.github/ISSUE_TEMPLATE/bug_report.yml) or a
  [feature request](.github/ISSUE_TEMPLATE/feature_request.yml). Blank issues are
  disabled; [SUPPORT.md](SUPPORT.md) lists the information a report needs.

## Branches and commits

- Update `main`, then create one branch per modification: `feat/`, `fix/`,
  `docs/` or `chore/`. Never start work on `main`.
- Keep unrelated work out of the branch. A review compares
  `git diff main...HEAD`.
- Subjects use `feat:`, `fix:`, `docs:` or `chore:` followed by the observable
  change. Do not put a version number in a normal commit subject; the version is
  assigned when a release is prepared.
- Add behavior changes under `## Unreleased` in `CHANGELOG.md`. Documentation,
  tests, CI, skills and repository metadata do not require a changelog entry or
  a version change.
- When the maintainer prepares a release, move the `Unreleased` entries under a
  dated version heading and update `CMakeLists.txt`,
  `modules/settings/PunchiSettingsAbout.qml`, `README.md`, `README.es.md`,
  `AGENTS.md` and the local `docs/versioning.md` record. The `project_version`
  test fails when those declarations disagree with the newest dated changelog
  heading.

## Repository tree

| Path | Owns | Never holds |
| --- | --- | --- |
| `shell.qml` | composition of the enabled top-level modules | state, logic, commands |
| `modules/<feature>/` | one surface and its own interaction | shared primitives |
| `components/` | visual primitives with two or more confirmed consumers | feature state, commands |
| `services/` | data and coordination | visual items |
| `adapters/kde/` | the KDE boundary: QML adapters, `native/` C++ grouped by domain, `protocols/`, `window-state/` | dock surfaces |
| `config/` | settings schema, defaults and shared design metrics | persistence side effects |
| `tests/` | every CTest entry; see [tests/README.md](tests/README.md) | shipped QML |
| `scripts-user/` | reversible user entry points and their `lib/` | developer-only tooling |
| `scripts-dev/` | developer tooling; see [scripts-dev/README.md](scripts-dev/README.md) | runtime dependencies |
| `assets/` | brand assets referenced by CMake and both READMEs | build output |
| `cmake/` | CMake modules and templates | generated files |
| `.agents/` | [AGENTS.md](AGENTS.md), the skills and their catalog | runtime code |
| `.github/` | workflows and issue/pull-request templates | credentials |
| `docs/` | local engineering record, ignored by Git | anything a build reads |

- Every layer directory carries a README that states what belongs to it, and a new
  subdirectory is added to that README's inventory.
- A new top-level directory needs a row in this table and a reason. If it changes the
  dependency direction, `tests/architecture_test.py` needs a matching rule or a written
  allowlist entry.
- Generated output, captures, credentials and build trees never live in a tracked
  directory.
- `docs/` and every other ignored path never appears as a link target from a tracked
  file, because a clone does not receive it.

## Local development

Install the dependencies once (`--install-missing` offers the distribution
command and asks before running it):

```bash
./scripts-user/setup.sh --check-deps
```

Configure, build and run the compositor-free graph:

```bash
cmake --preset dev
cmake --build --preset dev
ctest --preset headless
```

`ctest --preset headless` selects the `unit` and `qml` labels and needs no
graphical session. The complete graph adds the `session` label, which requires a
live KDE Plasma/KWin Wayland session:

```bash
ctest --test-dir build --output-on-failure
```

Run a single check with
`ctest --test-dir build -R '^<name>$' --output-on-failure`. Each test owns
temporary XDG data, caches, sockets and processes, and cleans them on success,
failure, signal and timeout.

Additional checks:

```bash
python3 tests/foundation_test.py
ruff check tests scripts-dev
```

`ruff` is a distribution package (Fedora: `ruff`) and is not a runtime
dependency; the CI job installs it and runs the same command.

## Quality and evidence

- `.editorconfig` and `.clang-format` record the shared style; existing files are
  not reformatted to satisfy them.
- CI runs `scripts-dev/ci-headless.sh` on Fedora 44: `ruff check`, then the
  `unit` and `qml` labels. A green CI run is not desktop validation.
- Lint, component behavior, real Quickshell loading, visual inspection and KDE
  compatibility are separate evidence levels. State which ones you ran.
- Do not remove, disable or weaken a behavioral test. Diagnose the production
  code first, and add a regression that observes the contract.
- Never present offscreen or lint success as visual or KWin validation.

## Pull requests

- Target `main` from your branch and follow the
  [pull request template](.github/PULL_REQUEST_TEMPLATE.md).
- Describe the observable result, the validation actually performed, and what
  remains unverified.
- Remove personal paths, usernames, tokens, logs and private file contents.
- Pull requests are squash-merged and the delivery branch is deleted afterwards.
- Draft the pull request while the change still awaits review or a real-session
  check.

## Licensing and attribution

The project is GPL-3.0-or-later. Preserve the license and copyright of reused
code and assets, and record new attribution in [NOTICE.md](NOTICE.md).

## Code of conduct

Participation follows [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
