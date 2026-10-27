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
  change. A behavior-changing commit also names its delivery version, for
  example `feat: deliver 0.1.46 ...`.
- The padded delivery counter (`0.1.00`, `0.1.01`, ...) advances once per commit
  that changes application behavior. Repository metadata and documentation-only
  commits keep it unchanged.
- A behavior change updates the counter in `CMakeLists.txt`,
  `modules/settings/SettingsAbout.qml`, `README.md`, `README.es.md`,
  `CHANGELOG.md` and the local `docs/versioning.md` record. The
  `project_version` test fails when the tracked declarations disagree with the
  newest changelog heading.

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
