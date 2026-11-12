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

`CHANGELOG.md` is the public, curated record of user-visible behavior changes.
It uses the Keep a Changelog layout and the writing rules of Common Changelog.
Common Changelog has no `Unreleased` section and requires a tag per release, so
this project adopts its writing rules only.

The file starts with `# Changelog` and a preamble naming the convention and
Semantic Versioning. `## Unreleased` comes first, then dated published releases
in reverse order. Under each heading, include only categories with entries:
`Added`, `Changed`, `Fixed`, `Removed`, `Deprecated` and `Security`.

Entries are concise, self-describing list items in the imperative mood. One item
covers one user-visible behavior; merge related commits and reference a pull
request or issue when one exists. Markdown source lines may wrap, but an entry
stays one paragraph. Prefix breaking changes with `**Breaking:**`. Keep class
names, test names, paths, timings and validation output out of the changelog;
put implementation and validation detail in the pull request or release notes.

Documentation, tests, CI, skills and repository metadata do not get entries. Add
a version heading only when preparing a release; pending changes stay under
`## Unreleased`.

The heading remains `## <version> — <YYYY-MM-DD>` because
`scripts-dev/check-version.py` parses it. Adopt the bracketed Keep a Changelog
heading and comparison links only after tags exist, updating the checker and
version declarations together.

## Publication state

No version has been published: the repository has no tag or GitHub Release. The
tree prepares `0.2.0-beta.1` as its first pre-release; `0.1.47` remains the
legacy development baseline. The public changelog retains both.

The first release is a pre-release (`0.2.0-beta.1`), followed by `0.2.0` when the
menu base settles. `1.0.0` waits until the configuration schema, QML module API
and supported KDE, Quickshell and Qt versions are committed contracts. This is a
preparation, not an authorization to publish: creating the tag or the GitHub
Release needs a separate explicit request.

The dated heading carries the display version, including a pre-release suffix.
CMake keeps the numeric base in `PUNCHI_VERSION_BASE` for `project(VERSION)` and
the display string in `PUNCHI_DISPLAY_VERSION`; `scripts-dev/check-version.py`
verifies both. The base must match the part before the first `-`, and every
declaration must name the display version. Tags use the `v<display>` form, and the
GitHub Release links the changelog and the compare URL without binary assets; a
pre-release is marked as such on GitHub.

## Earlier development counter

The closed `0.1.00`–`0.1.47` counter advanced per behavior-changing commit. Those
numbers were development snapshots, not published releases; `0.1.47` is the
transition baseline for future release-based Semantic Versioning. Do not infer
the next release number from that counter. This development counter is not a
release history; future dated entries will correspond to actual releases.

| Declared baseline | Status |
| --- | --- |
| 0.2.0-beta.1 | Prepared first pre-release; not published |
| 0.1.47 | Final development snapshot; not published |

The next release must be explicitly requested. Move the pending `Unreleased`
entries under a dated heading, choose the Semantic Versioning number that matches
the included changes, and update `PUNCHI_VERSION_BASE` and
`PUNCHI_DISPLAY_VERSION` in [CMakeLists.txt](../CMakeLists.txt), the About page,
the version in both [READMEs](../README.md) and [README.es.md](../README.es.md),
the version instruction in [AGENTS.md](../AGENTS.md), the runtime settings test,
the dated entry in [CHANGELOG.md](../CHANGELOG.md), and this document.
Reconfigure and rebuild after changing build metadata; run the applicable checks
and record unavailable validation. Do not create a tag or publish a release
without separate authorization.

Configuration schema version `16` and QML module API version `1.0` are separate
contracts; do not increment either merely because the application version changes.
The project is still a prototype. A release version does not imply a packaged
release, a new compatibility guarantee, or permission to create tags or publish
release artifacts.
