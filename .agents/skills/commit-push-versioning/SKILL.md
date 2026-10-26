---
name: commit-push-versioning
description: Prepare an authorized commit and push, deciding the application version from the latest CHANGELOG delivery, reviewing the exact staged content, and handing the branch to pr-delivery.
---

# Commit and push

Use when the user asks to commit, push, or both. A request to commit and push
authorizes the requested Git operations on the current branch, its configured
upstream, and the delivery pull request that `pr-delivery` opens once the work is
approved; it does not authorize tags, releases, force pushes, unrelated remotes,
merges, or branch deletion.

## Branch first

Commit on a delivery branch, never on `main`. When the work still sits on
`main`, create `feat/<descriptor>`, `fix/<descriptor>`, `docs/<descriptor>` or
`chore/<descriptor>` from updated `main` before staging anything, then continue
on it. One branch per modification; never reuse a branch that was already
merged. Report the branch alongside the commit and let the user decide when to
merge.

## Determine the delivery version

Treat the newest delivery heading at the top of `CHANGELOG.md` as the source of
truth. Inspect the complete requested commit scope before deciding whether it
changes application behavior.

- If the commit changes behavior in `shell.qml`, `modules/`, `components/`,
  `services/`, `adapters/`, `config/`, `scripts-user/`, native application
  sources, or application build wiring in `CMakeLists.txt`, advance the latest
  changelog counter exactly once for this commit. Grouped changes still get one
  increment.
- Tests, documentation, skills, repository metadata, development tools, and
  comment-, formatting-, or wording-only changes do not advance the counter by
  themselves. Use the repository's `chore:` or `docs:` commit convention for
  those commits.
- Keep the padded decimal format with at least two digits in the final segment.
  Do not infer the next number from a stale About page, README, build directory,
  installed copy, Git tag, or `AGENTS.md`; reconcile those declarations to the
  latest changelog entry.

For a behavior-changing delivery, add its dated entry at the top of
`CHANGELOG.md`, then synchronize `project(... VERSION ...)` in `CMakeLists.txt`,
the About page, `README.md`, `README.es.md` when present, `AGENTS.md`, and the
local `docs/versioning.md` record. Keep configuration schema and QML module API
versions independent. For a non-behavior commit, leave the application version
unchanged and do not add a delivery entry just to create a version bump.

## Review and publish

1. Inspect `git status`, branch/upstream, and staged, unstaged, and untracked
   changes. Preserve existing work; never reset, clean, or discard user changes.
   Stop if the current branch is `main` and create the delivery branch first.
2. Identify the intended commit scope and review its full diff. Do not include
   ignored build output, credentials, private notes, diagnostics, or unrelated
   changes. Ask only if mixed changes cannot be safely separated.
3. Run the focused checks required by the changed behavior, then the repository's
   required full checks when available. Reconfigure and rebuild after changing
   CMake version/build metadata.
4. Stage only the reviewed files. Inspect the exact staged diff and run
   `git diff --cached --check` before committing.
5. Commit with the repository's message convention. Before pushing, confirm the
   branch and configured upstream still match the user's requested destination;
   push normally without force and verify the resulting branch state.
6. Hand the pushed branch to `pr-delivery`, which opens the delivery pull request
   unless the user asked to stop after the push.

If the requested upstream is missing, diverged, or unexpectedly different, stop
before pushing and report the specific blocker. Do not create tags or releases
unless the user separately requests them, and never merge on the strength of a
commit or push request.