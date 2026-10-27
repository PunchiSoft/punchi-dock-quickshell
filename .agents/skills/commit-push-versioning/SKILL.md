---
name: commit-push-versioning
description: Prepare an authorized commit and push, decide whether the work prepares a release, review the exact staged content, and hand the branch to pr-delivery. Use when the user asks to commit, push, or both.
license: GPL-3.0-or-later
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

## Version and changelog

Versions identify releases, not commits. Treat the newest dated heading in
`CHANGELOG.md` as the current released version and `## Unreleased` as pending
work. Do not advance the version for an ordinary commit.

- A behavior-changing commit adds its entry under `## Unreleased`. When the user
  explicitly asks to prepare a release, move the `Unreleased` entries under a new
  `## <version> — <YYYY-MM-DD>` heading, choose the next Semantic Versioning
  number, and synchronize `project(... VERSION ...)` in `CMakeLists.txt`, the
  About page, both READMEs, `AGENTS.md`, and the local `docs/versioning.md`
  record. Keep configuration schema and QML module API versions independent.
- Tests, documentation, skills, repository metadata, development tools, and
  comment-, formatting-, or wording-only changes do not require a version change
  or a changelog entry. Use the repository's `chore:` or `docs:` commit
  convention for those commits.
- Never infer the next version from a stale About page, README, build directory,
  installed copy, Git tag, or `AGENTS.md`; reconcile those declarations to the
  newest dated changelog entry.
- A release may contain many commits and several features. Its version advances
  once for the whole release, not once per commit.

## Review and publish

1. Inspect `git status`, branch/upstream, and staged, unstaged, and untracked
   changes. Preserve existing work; never reset, clean, or discard user changes.
   Stop if the current branch is `main` and create the delivery branch first.
2. Identify the intended commit scope and review its full diff, using
   `code-review` when it spans several files or changes behavior. Do not include
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