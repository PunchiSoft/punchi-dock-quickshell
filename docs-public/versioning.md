# Release versioning

Punchi Dock Quickshell uses release-based Semantic Versioning for the application
version: `MAJOR.MINOR.PATCH`. A version identifies a release, not a commit or a
feature.

Pending changes accumulate under `## Unreleased` at the top of `CHANGELOG.md`.
When a release is prepared, move those entries under a new
`## <version> — <YYYY-MM-DD>` heading and advance the version once for the whole
release. A release may contain many commits and several features; documentation,
tests, CI, skills and repository metadata alone do not justify a release or a
version change.

The newest dated heading in `CHANGELOG.md` is authoritative.
`scripts-dev/check-version.py` verifies every declaration against it. Do not
infer the next number from a stale About page, README, build directory, installed
copy, Git tag or other record. Before `1.0.0`, a MINOR release may contain
breaking changes; a PATCH release contains compatible fixes. Configuration schema
and QML module API versions are separate contracts.

## Changelog format

`CHANGELOG.md` is the public, curated record of behavior changes. It follows the
Keep a Changelog layout with the Common Changelog writing rules; the private
`docs-private/` record keeps the engineering detail. Common Changelog has no `Unreleased`
section and requires a tag per release, so the project takes its writing rules
only. The two records do not duplicate each other: the changelog states the
impact, the record states the evidence.

The file starts with `# Changelog` and a preamble that names the convention and
Semantic Versioning. `## Unreleased` comes first, then the dated releases in
reverse order. Under each heading, only the categories with content appear:
`### Added`, `### Changed`, `### Fixed`, `### Removed`, `### Deprecated` and
`### Security`.

Entries are imperative, one line and self-describing, so they read without their
heading. One entry covers one user-visible behavior, and related commits merge
into it. Each entry references the pull request or issue when one exists.
`**Breaking:**` opens its category for configuration schema, QML module API and
environment variable changes. Class names, test names, paths, timings and
validation notes belong in `docs-private/records/changes/`, not in the changelog.

Documentation, tests, CI, skills and repository metadata do not get an entry. A
version heading is added only when a release is prepared; unreleased work stays
under `## Unreleased`.

The heading keeps the form `## <version> — <YYYY-MM-DD>` because
`scripts-dev/check-version.py` parses it. The bracketed Keep a Changelog form and
compare links are adopted only when the first tag exists, together with the
script and every declaration.

## Publication state

No version has been published. The repository carries no tag and no GitHub
Release, so `0.1.47` is the version the tree declares rather than a download, and
`README.md`, `README.es.md`, `AGENTS.md`, `CHANGELOG.md` and the About page say so
in those words. The dated headings kept from the earlier development counter are
recorded as development snapshots instead of being rewritten.

The first published release can therefore be the number that describes a stable
base instead of the next patch of a sequence nobody installed. The intended shape
is a pre-release (`0.2.0-beta.1`, annotated tag `v0.2.0-beta.1`, published with
the GitHub pre-release flag) once the menu base is stable, `0.2.0` when it
settles, and `1.0.0` only when the configuration schema and the QML module API are
committed contracts and the supported KDE, Quickshell and Qt versions are
declared. At that first publication, collapse the `0.1.x` development headings
under a single pre-public note so a reader cannot mistake them for downloads.

## Earlier development counter

The padded counter `0.1.00` through `0.1.47` was the earlier development
convention: it advanced once per behavior-changing commit. The original `0.1.0`
snapshot is the `0.1.00` baseline; preserve its commit history. Its historical
tag `v0.1.0` was removed on 2026-10-14. Earlier construction work was bundled in
that snapshot and has no separate retrospective count. `0.1.47` is the
transition point: it is the latest release under the old numbering and the
baseline for release-based numbering. The table below records that history; the
counter is closed and no new heading uses the padded or per-commit form.

On 2026-10-19, the local documentation paths were removed from every commit before
publication, and the personal author/committer email was replaced with GitHub's
noreply address, both with explicit authorization. Commit messages and content
were preserved; commit hashes from the initial snapshot onward changed. The
pre-rewrite history remains in private archives outside this repository.

The resulting clean history was pushed to a new public repository. The previous
repository was renamed and remains private;
it contains the same cleaned history, not the removed local documentation or
personal email.

On 2026-10-28, with explicit authorization, the author of the single
Dependabot-authored commit on `main` was rewritten to the repository owner, so no
bot account appears in the contributors list. Content, messages, author dates and
trees were preserved; every commit from that one onward received a new SHA
(`98f7b85` → `fba448a` at the tip). The pre-rewrite tip is kept locally as
`backup/pre-dependabot-rewrite`, and the private repository was not rewritten.

| Counter | Existing commit | Release |
|---|---|---|
| 0.1.00 | `c24075e` | Initial project snapshot, originally versioned `0.1.0` |
| 0.1.01 | `4f68505` | Project introduction and capability documentation |
| 0.1.02 | `7bf2447` | Panel-mode, window-detection and running-app documentation |
| 0.1.03 | `a8acbb8` | Native edge, window-visibility and running-app adapters |
| 0.1.04 | `b3a8427` | Window dodge, edge handoff and running markers |
| 0.1.05 | `b90d5c6` | General visibility, zoom and motion settings |
| 0.1.06 | `310ec53` | Native build targets and validation suites |
| 0.1.07 | `4554374` | Scope-based settings persistence |
| 0.1.08 | `15be70a` | Task activation, media, Trash, icon refresh and distribution documentation |
| 0.1.09 | `c950da7` | Magnification profile and spacing correction, Quickshell editor guidance and tooling-diagnostic documentation |
| 0.1.10 | Commit declaring this version | Native KDE user header, responsive settings layout and magnification slider labels |
| 0.1.11 | Commit declaring this version | Folder containers, lateral dock positions and unified tooltip/menu theming |
| 0.1.12 | Commit declaring this version | Local-only development documentation outside the published repository |
| 0.1.13 | Commit declaring this version | Project rename, About page, recoverable KWin minimize effect and taskbar interaction fixes |
| 0.1.14 | Commit declaring this version | Running-window identity fallback and configurable dock item management |
| 0.1.15 | Commit declaring this version | In-page item adding, Plasma task-window actions, tolerant backend snapshots and restored Trash entry point |
| 0.1.16 | Commit declaring this version | PunchiSoft author metadata and About version refresh |
| 0.1.17 | Commit declaring this version | Single selection emphasis in settings lists |
| 0.1.18 | Commit declaring this version | Guided user setup menu, dependency checks and reversible user-local installation |
| 0.1.19 | Commit declaring this version | Setup hardening: explicit start, kept build output, active-instance restore, dependency prompts/maps, KDE requirement, failure logs, launcher actions, rollback, CMake install and packaging rules |
| 0.1.20 | Commit declaring this version | Read-only Git update check and Qt tool resolution outside `PATH` |
| 0.1.21 | Commit declaring this version | Contextual Items details pane with folder controls, responsive stacking, a neutral start without preselection, icon-above-label categories, single-emphasis navigation and an interactive post-pull rebuild prompt |
| 0.1.22 | Commit declaring this version | Optional `Start with KDE Plasma` autostart switch with an owned XDG entry, foreign-file preservation and safe uninstall |
| 0.1.23 | Commit declaring this version | Native KDE menu emphasis and body styling, isolated Places/recent bookmark stores and native-first skill policy |
| 0.1.24 | Commit declaring this version | Full-width Places hover rows and current Arch 6.8 compatibility data |
| 0.1.25 | Commit declaring this version | Recent KDE activity applications, shared settings surfaces, in-app license, native library install fixes and clarified compatibility scope |
| 0.1.26 | Commit declaring this version | KDE tracking detection, disabled recent-application controls with an explanatory note, and watched `kactivitymanagerd-pluginsrc` state |
| 0.1.27 | Commit declaring this version | Remember-history switch writing the two public `what-to-remember` states, KDE Recent Files shortcut and preserved per-application lists |
| 0.1.28 | Commit declaring this version | Folder fan presentation: an unfolding arc of entries with reserved lean, a closing open row and keyboard traversal |
| 0.1.29 | Commit declaring this version | Punchi Menu hover pulse in dock popups and folder presentations, plus the recovered motion skill pack |
| 0.1.30 | Commit declaring this version | Recent-applications switch decoupled from KDE tracking availability, with recording kept while the list is hidden |
| 0.1.31 | Commit declaring this version | Per-container subfolder exploration switch, with the fan kept as a leaf |
| 0.1.32 | Commit declaring this version | Dock-window activation anchor so folder entries and the location action reach KDE again |
| 0.1.33 | Commit declaring this version | Application picker gated behind typing, theme icon chooser for applications and containers, per-container popup entry selection, and a cached native icon-theme catalog |
| 0.1.34 | Commit declaring this version | Add-item editor grouped into the shared settings card, with the application result list overlaying the form |
| 0.1.35 | Commit declaring this version | Recent-applications history fallback to every activity when Plasma reports no current activity |
| 0.1.36 | Commit declaring this version | Setup presentation matching the main Punchi Dock project, RAM-capped build jobs, and the try-without-installing menu action with a child-process start |
| 0.1.37 | Commit declaring this version | Dependency check animated behind the progress line with its captured report replayed after the check |
| 0.1.38 | Commit declaring this version | Minimum visible duration and completion hold for terminal steps, with tuning variables and immediate redirected output |
| 0.1.39 | Commit declaring this version | Shared popup language: row states, slim fading indicator, cost-based folder arrangement, single Open row, entry menu with Copy Path and popup appearance settings |
| 0.1.40 | Commit declaring this version | Folder popup survives a listing change while delegating, and the recent dock item is documented and tested as applications only |
| 0.1.41 | Commit declaring this version | Popup size, popup height and popup icon size move into their own Popups category, and the grid, list/detail and fan glyphs get independent sizes with a stepped slider (schema 11) |
| 0.1.42 | Commit declaring this version | A folder list popup is sized from the name width its rows paint, plus the chevron column only while it is shown |
| 0.1.43 | Commit declaring this version | Pointing-hand cursor over the dock context menu rows, the folder container rows and header, the entry menu and the Empty Trash confirmation |
| 0.1.44 | Commit declaring this version | Read-only update badge from PackageKit, fwupd and Flatpak on the pinned update front-end (Discover first), Kirigami-sized on the icon corner with the notification colors, an accessible count, an Updates switch and a detected-sources note |
| 0.1.45 | Commit declaring this version | Badge on the lower-right corner, live PackageKit transaction state with `update-busy` while installing, re-check when the install ends, and the security info constant corrected to 8 |
| 0.1.46 | Commit declaring this version | Trial run isolated in its own profile with one cleanup confirmation, autostart switch unavailable during a trial, and uninstall reduced to one keep-or-remove-everything choice that also drops the window-state registration |
| 0.1.47 | Commit declaring this version | About page gains the approved "Made with love" dedication, with the link to the Punchi Dock Remastered plasmoid and the closing motto |

The latest release is `0.1.47`. When preparing the next release, move the
`Unreleased` entries under a dated heading and choose the next Semantic
Versioning number (for example `0.1.48` for a compatible patch). Update the
application's `project(... VERSION ...)` in [CMakeLists.txt](../CMakeLists.txt),
the current version in [README](../README.md) and [README.es.md](../README.es.md),
the latest-release instruction in [AGENTS.md](../AGENTS.md), the dated entry in
[CHANGELOG](../CHANGELOG.md), and this record. Reconfigure/rebuild when build metadata changes, run the applicable
checks and record unavailable validation. Commits that do not belong to a release
are not listed in the table.

Configuration schema version `11` and QML module API version `1.0` are separate
contracts; do not increment either merely because the application version changes.
The project is still a prototype. A release version does not imply a packaged
release, a new compatibility guarantee, or permission to create tags or publish
release artifacts.