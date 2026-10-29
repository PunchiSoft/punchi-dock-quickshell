---
name: modification-cycle
description: Record and implement a feature in small reviewable stages with explicit scope, module ownership, validation, and future decisions on a branch created from updated main. Use when starting a new feature or a multi-commit change.
license: GPL-3.0-or-later
---

# Feature stages

Read the active stage and related decisions. Preserve the user's request as the
source of scope; inferred implementation details must not expand the feature.

Record context, request, included/excluded scope, risks, sequential plan,
implementation, validation, and next decisions. For substantial later changes,
use the ignored `docs/records/changes/change-YYYY-MM-DD-descriptor.md` with
`docs/records/changes/template.md`. Stage boundaries live in the local
`docs/roadmap.md`.

Start from `requirements-capture` when the scope or the acceptance criteria are
not already explicit in the request.

Proceed with already authorized work; ask only for missing decisions that affect
the result. Apply domain skills when their implementation stage begins.
Validate after editing, without running a full suite merely to open a record.
When the change adds or edits a service → adapter call, run the `testing`
skill's synthetic adapter contract probe before other checks. Close only the
completed scope and distinguish implementation from pending runtime or user
validation. No legacy plasmoid gate is implied by this workflow.

## Reference gate

Establish the API evidence before editing, not after. Apply `qt-kde-reference`
for the exact symbol, version availability and source, and `kde-integration` for
the native mechanism that should own the behavior.

The authoritative sources, in order, are the local reference notes, the installed
headers and QML type metadata, and the official documentation for the installed
release. An upstream checkout such as `kde-sdk/` is optional local evidence: it is
not bundled here and never replaces the installed metadata.

Record the symbol, version, source and evidence limits before implementing, and
prefer an existing Quickshell or KDE provider over a new service or adapter. When
the evidence is missing or version-sensitive, say so instead of assuming that
upstream behavior applies to this session.

## Delivery branch

Never make the first change on `main`. Apply `branch-baseline` before creating the
branch: it verifies local `main` against `origin/main`, proves the new branch
starts from `main`, and requires a stated reason for the exceptional sub-branch.
The name is `feat/<descriptor>`, or `fix/<descriptor>`, `docs/<descriptor>` or
`chore/<descriptor>` when the change is a correction, documentation-only or
repository-only. Do not reuse a branch that was already merged, and record the
branch name in the change note.

"Commit and push" approves the implemented work on that branch and, per
`commit-push-versioning` and `pr-delivery`, publishes it with its delivery pull
request. It is not authorization to merge into `main`, create a tag or release,
or delete the branch; each of those needs its own request.
