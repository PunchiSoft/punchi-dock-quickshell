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

## Delivery branch

Never make the first change on `main`. Before editing, update `main` and create
one branch per modification from it, named `feat/<descriptor>`, or
`fix/<descriptor>`, `docs/<descriptor>` or `chore/<descriptor>` when the change
is a correction, documentation-only or repository-only. Do not reuse a branch
that was already merged, and record the branch name in the change note.

"Commit and push" approves the implemented work on that branch. It is not
authorization to merge into `main`, create a tag or release, or open a pull
request; each of those needs its own request. `commit-push-versioning` owns the
commit content and the delivery version once the user asks for it.
