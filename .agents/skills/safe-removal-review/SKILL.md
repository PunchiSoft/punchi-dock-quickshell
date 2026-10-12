---
name: safe-removal-review
description: Plan safe material deletion, unrecoverable overwrites, batch moves, and feature retirement with exact paths and consumer checks.
---

# Safe removal and moves

Resolve the exact authorized targets and inspect their consumers before mutation.
Git is not a backup for ignored or untracked files; create a recoverable copy
before destructive changes to such material.

For batch moves, build the complete source-to-destination map first. Validate
unique sources, nonempty unique destinations, containment, and no collisions.
Do not calculate names while moving or overwrite destinations by default.

After each small batch, verify content, references, and inventory. Stop on an
unexplained reduction or collision. Feature removal covers controls, settings,
bridge bindings, providers, localization, documentation, and tests; preserve
shared consumers and respect protected-test authorization. Report recoverability
and incomplete cleanup rather than claiming success from a command exit alone.
