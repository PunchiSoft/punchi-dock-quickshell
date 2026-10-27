---
name: requirements-capture
description: Turn a request into explicit scope, acceptance criteria, out-of-scope items, and risks before any code changes. Use when a request is ambiguous, spans several surfaces, or when a new feature, review, or delivery branch starts.
license: GPL-3.0-or-later
---

# Requirements capture

A requirement is a testable statement about observable behavior. Everything else
is an implementation choice, a preference, or a guess.

## Procedure

1. Quote the request verbatim and keep it as the source of scope.
2. Separate what the user asked for from what an implementation would imply.
3. Write acceptance criteria as observable outcomes, each one checkable.
4. Write the out-of-scope list explicitly, including tempting neighbours.
5. Ask only the questions that change the implementation, and offer the default
   you would choose.
6. Record risks, affected surfaces, and the evidence the change will need.
7. Hand the result to `modification-cycle` for staging.

## Acceptance criteria shape

```markdown
- [ ] Given <state>, when <action>, then <observable result>.
- [ ] When <failure condition>, then <explicit failure behavior>.
- [ ] Unchanged: <behavior that must not regress>.
```

## Rules

- Do not expand scope because an adjacent improvement looks cheap. Record it as
  future work.
- A preference about wording, motion, or emphasis in user-visible copy goes
  through `notice-copy-approval` before implementation.
- A request to review or investigate is not authorization to modify code.

## Gotchas

- "Make it better" is not a criterion. Restate it as the symptom the user sees.
- A question already answered earlier in the conversation is not ambiguous;
  re-read the thread before asking it again.
- Settings are user-visible contracts: renaming a stored key is a migration, not
  a refactor.
- Two criteria that cannot both hold indicate a product decision that belongs to
  the user, not to the implementation.
- An inferred detail recorded as a requirement silently expands the feature; mark
  it as an assumption until the user confirms it.

## Validation

- Every criterion names a state, an action, and an observable result.
- The out-of-scope list is non-empty and names what will not change.
- Open questions are resolved, or deferred with the chosen default recorded.
