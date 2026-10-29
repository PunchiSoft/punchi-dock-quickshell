---
name: safe-removal-review
description: Plan safe deletion, unrecoverable overwrite, batch moves, and feature retirement with exact paths and consumer checks. Use when files, directories, settings, or a whole feature would be deleted, moved, or rewritten.
license: GPL-3.0-or-later
---

# Safe removal and moves

Resolve the exact authorized targets and inspect their consumers before mutation.
Git is not a backup for ignored or untracked files.

## Procedure

1. Write the exact path list and the reason for each entry.
2. Find consumers: imports, QML type names, settings keys, tests, docs, install
   rules in `CMakeLists.txt`, and packaging lists.
3. For anything ignored or untracked, create a recoverable copy outside the tree
   and record where it went.
4. Build the complete source-to-destination map before a batch move, then
   validate unique sources, nonempty unique destinations, containment, and no
   collisions.
5. Execute in small batches and verify content, references, and inventory after
   each one.
6. Remove the dead wiring: settings schema, bridge bindings, providers,
   localization, documentation, and tests.
7. Report recoverability and any incomplete cleanup.

## Rules

For batch moves, build the complete source-to-destination map first. Do not
calculate names while moving and do not overwrite destinations by default.
Stop on an unexplained reduction or collision. Preserve shared consumers and
respect protected-test authorization.

## Gotchas

- Deleting an untracked or ignored file leaves no reachable object. `backup/`,
  `scratch/`, `build/` and `docs/` are ignored in this repository.
- Deleting a QML file leaves stale CMake lists and import paths that fail only
  when the shell loads, not when it builds.
- Removing a setting without a schema migration leaves the stored JSON key
  behind; re-adding the setting later silently restores the old value.
- A shared component with one remaining consumer belongs in that module, not
  deleted with the feature that motivated it.
- Behavioral tests are protected: remove one only with explicit authorization,
  and never to make a deletion pass.

## Validation

```bash
rg -n '<removed-name>' --glob '!build/**' --glob '!backup/**'
ctest --test-dir build --output-on-failure
```

Report the inventory before and after, and state what is not recoverable.
