# Project instructions: Punchi Shell

## Scope and product

This file is canonical for this repository. Scoped instructions may supplement
it. Skills live in `.agents/skills/`. User instructions take precedence.

Punchi Shell is a modular desktop interface built with Quickshell and QML for
KDE Plasma/KWin, primarily on Wayland. The current stage is a dock with configured desktop-entry launchers, a continuous
magnification wave, and two-hop activation feedback. A native Qt/KDE QML module
provides application launching. Rust remains optional.

## Safe coexistence — current operating contract

Keep Plasma running. Do not remove panels, alter Plasma configuration, claim
notification/tray/polkit ownership, install autostart, or replace the session.
`scripts-user/start.sh` runs this project's configuration in the foreground.
`scripts-user/restore-kde.sh` stops only that configuration. Closing Punchi Shell
reveals the unchanged KDE interface. Changes to this contract need explicit scope.

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
one machine. X11 and other compositors are unvalidated until tested.

## Work and security

Read instructions, inspect files and Git state when present, and preserve unrelated
work. Use `modification-cycle` for features and `review-cycle` for reported bugs.
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
The original `v0.1.0` snapshot is the `0.1.00` baseline; preserve its existing tag
and history.

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

The current delivery is `0.1.12`. Before a commit that advances the counter,
increment the latest declared counter once and update CMake, README, CHANGELOG and
the local `docs/versioning.md` record consistently. Keep configuration schema
and QML module API versions separate from the application delivery version.
