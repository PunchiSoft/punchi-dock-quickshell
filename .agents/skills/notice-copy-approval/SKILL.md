---
name: notice-copy-approval
description: Propose explanatory runtime notices and end-user manual notes for explicit wording and emphasis approval before implementation. Use when a change would show a warning, tooltip, help text, cause, or recovery message to the user.
license: GPL-3.0-or-later
---

# Explanatory copy approval

Preserve the owner's preference for reviewing notes, warnings, explanatory
tooltips, help text, and cause/recovery messages before they become product
copy. Ordinary labels, internal logs, and engineering records are outside this
workflow.

## Procedure

1. Verify the behavior the notice describes. An unverified notice is a rumour.
2. Fill the proposal template below with concrete wording, not placeholders.
3. Present it and wait for explicit approval. Silence is not approval.
4. Implement the approved wording literally.
5. Run the localization workflow only after the wording is approved.
6. Record the approval in the active change or review note.

## Proposal template

```markdown
Location: <surface and control>
Trigger: <exact condition, including the failure case>
English: <final sentence, user-facing>
Spanish: <final sentence, user-facing>
Emphasis: <plain note | warning tone | destructive tone>
Length: <one line | one paragraph | tooltip>
Omitted: <cases deliberately left without a notice, and why>
```

## Rules

Verify actual behavior, then propose location, trigger, English source, Spanish
translation, emphasis, expected length, and omitted cases. Do not write runtime
copy, catalogs, or end-user manual notes before that approval. Implement
approved wording literally; propose later changes to tone, length, or emphasis
again. Existing explicit approval remains valid. The explicitly requested
project overview is authorized engineering documentation and does not introduce
runtime copy.

## Gotchas

- The approved string is the deliverable, not a draft. Rephrasing later needs a
  new approval even when the meaning is unchanged.
- A notice about a failure must say what the user can do next; a bare cause
  leaves them stuck.
- `docs/` text is engineering record, not runtime copy, and needs no approval.
- Wrapping approved copy in `qsTr` is expected. Translating it before approval is
  rework.
- A destructive confirmation cannot reuse a neutral note: emphasis is part of the
  approved wording.

## Validation

- The implemented string matches the approved English text character for
  character.
- The trigger fires in the stated condition, including the failure case.
- The proposal record keeps the Spanish text even while only English ships.
