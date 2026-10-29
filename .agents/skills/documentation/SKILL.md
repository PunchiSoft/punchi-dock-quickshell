---
name: documentation
description: Maintain the English GitHub README, the local development record, attribution, and honest project-stage descriptions. Use when changing public documentation, the changelog, the catalog, or a statement about what the project supports.
license: GPL-3.0-or-later
---

# Public documentation

Keep `README.md` the English source entry point, with recognizable Punchi Dock
branding, current status, architecture links, developer guidance, and license.

## Procedure

1. Identify the audience: README for evaluation, CHANGELOG for delivery,
   CONTRIBUTING for workflow, NOTICE for attribution, `docs/` for the local record.
2. State what is implemented, what is intended, and which versions were actually
   tested. Never merge the three into one claim.
3. Update the record the change makes stale in the same commit.
4. Run every command you write and open every link you add.
5. Re-read the claim as a skeptical stranger installing it for the first time.

## Rules

- Distinguish implemented behavior, intended scope, and validated environments.
- Use only working local links and real commands; no hypothetical release URLs,
  passing badges, screenshots, or build instructions presented as current.
- Keep `docs/` local and out of the published repository; publish only
  `README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `NOTICE.md` and the skills.
- Keep one record root: living documents at `docs/`, dated records under
  `docs/records/`, and their evidence in `docs/records/assets/`.
- Preserve historical records; update living architecture docs when rules change.
- Every documentation directory has an index README; repeatable local record
  workflows also have a template when that directory is introduced.

Check links, source language, attribution, and consistency with the roadmap.
Do not copy the original applet's installation or compatibility claims.

## Gotchas

- `docs/` is ignored by Git, so a public page must never link into it: the link
  works locally and breaks for every reader of the repository.
- `README.md` and `README.es.md` have no generator. A change to one is
  incomplete until the other matches.
- The release version appears in `CMakeLists.txt`,
  `modules/settings/PunchiSettingsAbout.qml`, both READMEs, `CHANGELOG.md`, `AGENTS.md`
  and `docs/versioning.md`. Updating only one declaration leaves the others
  stale.
- `tests/foundation_test.py` proves links resolve and headings are well formed,
  not that the text is true.
- A new `docs/` subdirectory needs an index `README.md`, and a repeatable
  workflow also needs a template; missing either is a documentation defect.

## Validation

```bash
python3 tests/foundation_test.py
python3 scripts-dev/check-version.py
rg -n '0\.1\.[0-9]{2}' README.md README.es.md CMakeLists.txt \
   modules/settings/PunchiSettingsAbout.qml CHANGELOG.md AGENTS.md docs/versioning.md
```

Report which claims were re-verified and which remain unverified.
