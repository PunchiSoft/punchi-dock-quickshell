# Project instructions: Punchi Dock Quickshell

## Scope and product

This file is canonical for this repository. Scoped instructions may supplement
it. Skills live in `.agents/skills/`. User instructions take precedence.

Punchi Dock Quickshell is a modular desktop interface built with Quickshell and QML for
KDE Plasma/KWin, primarily on Wayland. The current stage is a dock with configured desktop-entry launchers, a continuous
magnification wave, two-hop activation feedback, and an update badge on
Discover read from PackageKit, fwupd and Flatpak. A native Qt/KDE QML module
provides application launching. Rust remains optional.

## Safe coexistence — current operating contract

Keep Plasma running. Do not remove panels, claim notification/tray/polkit
ownership, install autostart, or replace the session. `scripts-user/start.sh`
runs this project's configuration in the foreground.

Punchi Dock Quickshell may change the global KWin minimize effect only after an explicit
user selection, and only within KWin's `exclusiveGroup=minimize`. Before its
first write, capture the presence and boolean value of every discovered
`Plugins/<effect>Enabled` key in the user-owned
`$XDG_STATE_HOME/punchi-dock-quickshell/owned-settings.json` recovery record
(fallback: `$HOME/.local/state/punchi-dock-quickshell/owned-settings.json`).
Read a legacy record from the former `punchi-shell/` directory only when the
new record does not exist, and preserve the original snapshot during migration.
Write that record
atomically with owner-only permissions before changing `kwinrc`. Preserve the
original snapshot while Punchi Dock Quickshell continues running; a later selection may
update the recorded values Punchi Dock Quickshell wrote, but must not replace that original
snapshot. Write only keys whose effective values differ from the requested
state, and preserve unrelated KWin settings.

On clean shutdown and when `scripts-user/restore-kde.sh` runs, restore each
owned key only if its current presence and value still match the last state
Punchi Dock Quickshell wrote. Restore the original value when it was present, or delete
the key when it was originally absent. If a key no longer matches Punchi
Quickshell's recorded write, preserve the current value as an external user change
and discard its ownership entry. Keep the recovery record when restoration or
its durable write fails, so the restore script can retry after an unclean exit.
The restore script must run this recovery even when Punchi Dock Quickshell is already
stopped. Closing Punchi Dock Quickshell reveals the KDE interface with Punchi-owned KWin
settings restored; other Plasma configuration remains untouched.

## Modularization — primary requirement

- `shell.qml` only composes enabled top-level modules.
- `modules/<feature>/` owns a surface and its feature-specific interaction.
- `components/` owns visual primitives shared by confirmed consumers.
- `services/` owns data and coordination; no dependency on visual components.
- `adapters/kde/` is the boundary for KDE APIs when an integration needs them.
- `config/` owns settings and shared design metrics.
- `scripts-user/` contains reversible user entry points.
- `scripts-dev/` contains development tooling only, never runtime dependencies.

Preferred flow: view intent → service → adapter → desktop, with reactive state
flowing back to the view. Do not put commands, persistence, or desktop calls in
visual delegates. Quickshell already supplies providers: wrap them only when
there is a concrete responsibility, not merely to reproduce the diagram.

No circular dependencies, catch-all managers, or business logic in `shell.qml`.
`tests/architecture_test.py` (`architecture_contract`) fails the build when a layer
imports upwards or when `shell.qml` declares root-level state or logic; an
exception needs an entry with a written reason in
`tests/architecture-allowlist.json`, and a stale entry fails the test too.
Review cohesion at roughly 300–400 lines; extract responsibilities, not arbitrary
line quotas. Avoid empty feature implementations. Stub module directories are
not implemented capabilities. Keep QML interfaces explicit and small.

## Component naming

A QML type's name is its file name and each layer directory is flat, so the
prefix is the namespace. The prefix states whose concept the type is before it
states what the type does. A name that states only a function is ambiguous once a
second surface performs it: a dock item that launches applications is not the
application launcher.

- Every QML type under `components/`, `config/`, `services/`, `modules/` and
  `adapters/` starts with `Punchi`.
- When more than one surface owns the concept, a second level names the surface:
  `PunchiDock*` for the dock and its items, `PunchiMenu*` for the application
  menu.
- A primitive shared by several surfaces keeps the product prefix and names its
  form: `PunchiBalloonSurface`, `PunchiFanView`, `PunchiEntryButton`.
- `menu` means the application menu. Context menus and popups are
  `PunchiDockContext*` and `PunchiPopup*`.
- Never create a local type named after a Qt or KDE type it would shadow, such as
  `Menu`, `MenuItem`, `MenuBar`, `MenuSeparator` or `MenuBarItem`.
- The native QML module stays `Punchi.Kde`; a type name never repeats it.

`tests/naming_test.py` (`component_naming`) enforces the prefix and the reserved
names. Every type already complies, and `tests/naming-baseline.json` is empty and
stays empty: a naming failure is fixed by renaming the type, never by recording it
in the baseline, and the test rejects both a recorded name and a stale entry. A new
type must carry the prefix before it lands. Renaming a type is its own mechanical
change, never a side effect of another feature.

## UI and state

Use Qt Quick Controls, theme palettes, and verified Kirigami components when
appropriate. One shared visual primitive per role owns its interaction profile.
Keep hover, focus, press, selection, and drop intent distinct. Hover never steals
keyboard focus. Preserve accessible names, keyboard navigation, focus restoration,
scaling, clear disabled states, and reduced motion.

Settings update existing surfaces through bindings/notifications without restart.
Keep native model semantics, and avoid duplicate mirrors of Qt/KDE model rows.
Use reactive Qt models for asynchronous data when a real provider is added.

Motion uses Qt primitives with interruption and correct final state. Never build
animation engines with timers or per-frame service/FFI calls. Magnification is a
bounded continuous function of pointer distance in one coordinate space. Keep
layout centers stable and reserve visual room for enlargement. Closing fades
finish before hiding surfaces; tests may use bounded observation timers.

## Language and copy

English is the source language for code, identifiers, comments, logs, tests,
scripts, skills, README, and public docs. Runtime strings use Qt QML translation
functions (`qsTr`/`qsTranslate`) in this initial stage. Only English fallback is
currently supported; choose catalog loading/packaging before adding languages.
Do not assume Plasma-injected `i18n` globals in Quickshell.

Preserve explanatory-copy approval: propose English/Spanish wording, location,
trigger, emphasis, and length for runtime explanatory notices before implementing
them. Labels and internal engineering records do not require that workflow.
The requested project overview and operational start/restore documentation are
within the user's authorized setup scope.

## KDE integration and compatibility

Native KDE integration is a product requirement. Quickshell provides QML surface
hosting; desktop behavior must use supported KDE Frameworks/KWin integrations
and respect KDE preferences. Introduce native Qt/KDE adapters when Quickshell
providers do not preserve the required KDE contract. Rust remains optional.
Application launching uses KService, KIO, and Wayland activation through the
native QML module. Native KDE cursor feedback remains subject to real-session
validation. Do not simulate KDE cursor feedback in QML.

Target Linux/KDE/Wayland first. Inspect installed headers, QML metadata, local
references, and official Qt/KDE/Quickshell APIs before new integrations. Isolate
Hyprland-specific assumptions when studying Caelestia. A successful panel window
is not proof of task management, workspace control, or global shortcut support.

Record the actual versions tested. Do not inherit plasmoid compatibility claims,
ABI proxies, package commands, version sequence, or lint baselines. Quickshell
uses private Qt APIs; pair its binary with the Qt version it was built for.
Do not silently raise an agreed minimum or claim distro/compositor support from
one machine. X11 is out of scope and no support work is planned; other
compositors remain unvalidated until tested.

## Work and security

Read instructions, inspect files and Git state when present, and preserve unrelated
work. Use `modification-cycle` for features and `review-cycle` for reported bugs.
Use `commit-push-versioning` whenever a commit or push is requested; derive
application version changes from the newest delivery in `CHANGELOG.md`.
Start every modification on a branch created from updated `main` (`feat/`,
`fix/`, `docs/` or `chore/` prefix), never on `main` itself; one branch per
modification, recorded in the change note. Apply `branch-baseline` first: verify
local `main` against `origin/main`, create the branch from `main`, and confirm the
base with `git rev-list --left-right --count main...HEAD` (`0 0`) and an empty
`git log origin/main..HEAD`. A sub-branch is the exception and needs a stated
reason; a branch stacked on unpublished work by habit attaches commits that are
not yours. Merging, tags, releases and pull requests need their own explicit
request.
Record scope and evidence before changing code; do not start with a full suite.
Apply domain skills as their stages begin, then validate after implementation.

Treat paths, desktop entries, URLs, JSON, and external metadata as untrusted.
Use argument-based process APIs, explicit errors, bounded work, and cancellation.
No telemetry or unrelated privilege/network/system changes. Native FFI must
isolate unsafe code, define ownership and threads, and prevent unwinding across FFI.

Use `safe-removal-review` for material deletion, unrecoverable overwrite, or batch
moves: resolve exact targets, check consumers/collisions, back up ignored or
untracked material, and verify inventory afterward. Do not assume Git can recover
local notes. Preserve license/copyright on reused files and code.

Existing behavioral tests are protected against removal, disabling, or weakening
without explicit authorization. Diagnose production code first. Add regressions
that observe contracts; do not raise baselines or hide new diagnostics.

## Validation and records

The actual developer workflow is documented in the local `docs/development.md`.
After implementation, configure/build the validation graph, run complete CTest,
then run relevant real-session checks. `cmake --preset dev` and
`ctest --preset headless` are the compositor-free route; every CTest entry carries
the `unit`, `qml` or `session` label, and CI runs `scripts-dev/ci-headless.sh` on
Fedora 44 selecting `unit|qml` only. Lint/type metadata, component behavior,
real Quickshell loading, visual inspection, and desktop compatibility are separate
levels of evidence. Never present offscreen success as visual or KWin validation.

Classify the change before validating it. A change that edits only prose —
READMEs, `CHANGELOG.md`, `docs/`, `AGENTS.md`, skill text, code comments — runs no
build, lint or test: no test observes prose, so a result proves nothing about the
change and running one only spends time. Run the single check whose input you
actually touched, for example `project_foundation` after a skill's frontmatter or
`component_naming` after `tests/naming-baseline.json`, and nothing more. A change
that alters code, build registration or a file a test parses follows the normal
route, and a documentation update shipped with code follows the code.

Tests own unique temporary XDG data, caches, processes, and sockets. Clean after
success, failure, signal, and timeout. Session probes isolate their runtime dir
and connect to the existing compositor without changing desktop configuration.
Close every dock and settings window and stop every Punchi Dock Quickshell
process started for a test on success, failure, signal, or timeout; leave no test
instance running. An instance the user started before the test is not a test
instance and must be left untouched.

Public `README.md`, `README.es.md`, `CHANGELOG.md`, `CONTRIBUTING.md`,
`SUPPORT.md`, `CODE_OF_CONDUCT.md`, `NOTICE.md`, skills and tests are tracked.
`docs/` is the local development record and is not published with the repository;
it is also its own single record root, with dated records under `docs/records/`.
SDK trees, build output, credentials and local diagnostics stay ignored. New record directories
have an index and a template when they host a repeatable workflow. Record durable
architecture changes in `CHANGELOG.md` and the local `docs/` record; no private
evidence goes in tracked files.

GitHub-ready files do not authorize a remote, commit, push, tag, or release.
Do not restart or terminate Plasma as part of testing or restoring this prototype.

## Release versioning

Versions identify releases, not commits. Pending work accumulates under
`## Unreleased` at the top of `CHANGELOG.md`; the declared version changes only
when a release is prepared.

Prepare a release when the user requests one: move the `Unreleased` entries under
a new `## <version> — <YYYY-MM-DD>` heading, choose the next Semantic Versioning
number (`MAJOR.MINOR.PATCH`), and update `CMakeLists.txt`, the About page, both
READMEs, `AGENTS.md` and the local `docs/versioning.md` record consistently.
Every release advances the version once, regardless of how many commits or
features it contains. Before `1.0.0`, a MINOR release may contain breaking
changes; a PATCH release contains compatible fixes.

Documentation, tests, CI, skills and repository metadata alone never justify a
release or a version change. Keep those commits marked as `chore:` or `docs:`
and leave the version unchanged. The `project_version` test fails when the
tracked declarations disagree with the newest dated changelog heading.

The declared version is `0.1.47`, and it has no tag or release: no version has
been published yet. Do not create tags or releases unless
the user explicitly requests them. Keep configuration schema and QML module API
versions separate from the application version.
