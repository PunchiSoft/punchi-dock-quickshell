---
name: modification-cycle
description: Record and implement a new feature in small reviewable stages with explicit scope, module ownership, validation, future decisions, and a delivery branch created from updated main.
---

# Feature stages

Read the active stage and related decisions. Preserve the user's request as the
source of scope; inferred implementation details must not expand the feature.

Record context, request, included/excluded scope, risks, sequential plan,
implementation, validation, and next decisions. For substantial later changes,
use ignored `notes/changes/change-YYYY-MM-DD-descriptor.md`; create its index and
template when first needed. Stage boundaries live in the local `docs/roadmap.md`.

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

Never make the first change on `main`. Before editing, update `main` and create
one branch per modification from it, named `feat/<descriptor>`, or
`fix/<descriptor>`, `docs/<descriptor>` or `chore/<descriptor>` when the change
is a correction, documentation-only or repository-only. Do not reuse a branch
that was already merged, and record the branch name in the change note.

"Commit and push" approves the implemented work on that branch and, per
`commit-push-versioning` and `pr-delivery`, publishes it with its delivery pull
request. It is not authorization to merge into `main`, create a tag or release,
or delete the branch; each of those needs its own request.
