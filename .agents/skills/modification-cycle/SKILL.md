---
name: modification-cycle
description: Record and implement a new feature in small reviewable stages with explicit scope, module ownership, validation, and future decisions.
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
Close only the completed scope and distinguish implementation from pending
runtime or user validation. No legacy plasmoid gate is implied by this workflow.
