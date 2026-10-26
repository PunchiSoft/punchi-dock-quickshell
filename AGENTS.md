# Project instructions: Punchi Dock Quickshell

## Scope and product

This file is canonical for this repository. Scoped instructions may supplement
it. Skills live in `.agents/skills/`. User instructions take precedence.

Punchi Dock Quickshell is a modular desktop interface built with Quickshell and QML for
KDE Plasma/KWin, primarily on Wayland. The current stage is a dock with configured desktop-entry launchers, a continuous
magnification wave, and two-hop activation feedback. A native Qt/KDE QML module
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
Review cohesion at roughly 300–400 lines; extract responsibilities, not arbitrary
line quotas. Avoid empty feature implementations. Stub module directories are
not implemented capabilities. Keep QML interfaces explicit and small.

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
modification, recorded in the change note. Merging, tags, releases and pull
requests need their own explicit request.
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
then run relevant real-session checks. Lint/type metadata, component behavior,
real Quickshell loading, visual inspection, and desktop compatibility are separate
levels of evidence. Never present offscreen success as visual or KWin validation.

Tests own unique temporary XDG data, caches, processes, and sockets. Clean after
success, failure, signal, and timeout. Session probes isolate their runtime dir
and connect to the existing compositor without changing desktop configuration.

Public `README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `NOTICE.md`, skills and
tests are tracked. `docs/` is a local development record and is not published
with the repository; private `notes/`, SDK trees, build output, credentials and
local diagnostics are ignored. New record directories
have an index and a template when they host a repeatable workflow. Record durable
architecture changes in `CHANGELOG.md` and the local `docs/` record; no private
evidence goes in tracked files.

GitHub-ready files do not authorize a remote, commit, push, tag, or release.
Do not restart or terminate Plasma as part of testing or restoring this prototype.

## Delivery versioning

Use the user-approved padded delivery counter: `0.1.00`, `0.1.01`, and so on.
The original `0.1.0` snapshot is the `0.1.00` baseline; preserve its commit
history. Do not create tags or releases unless the user explicitly requests them.

Advance the counter once per commit that changes application behavior:
`shell.qml`, `modules/`, `components/`, `services/`, `adapters/`, `config/`,
`scripts-user/`, their native sources, or their build wiring in `CMakeLists.txt`.
Grouped functional changes share one increment. When such a delivery is
deliberately split into one commit per feature, each feature commit advances the
counter once.

Do not advance the counter for repository metadata or documentation-only commits:
`.gitattributes`, `.gitignore`, `README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`,
`NOTICE.md`, `LICENSE`, `.agents/`, the local `docs/`, `scripts-dev/`, `tests/`,
or comment-, formatting- and wording-only edits. Keep these commits marked as
`chore:` or `docs:`; the declared delivery version stays unchanged.

The current delivery is `0.1.43`. The newest delivery heading in `CHANGELOG.md`
is authoritative for the counter. Before a behavior-changing commit, advance it
once and update CMake, the About page, README, CHANGELOG and the local
`docs/versioning.md` record consistently. Keep configuration schema and QML
module API versions separate from the application delivery version.
