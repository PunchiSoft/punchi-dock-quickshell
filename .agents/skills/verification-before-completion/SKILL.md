---
name: verification-before-completion
description: Decide whether the collected evidence is enough to declare a change finished, and report what remains unverified. Use when a task looks complete, before claiming success, closing a review, or opening a pull request.
license: GPL-3.0-or-later
---

# Verification before completion

"Done" is a claim about evidence, not about effort. Decide which levels the change
needed and which ones actually ran.

## Evidence levels

| Level | Shows | Cannot show |
|---|---|---|
| 1 Source reading | what the code says | that it runs |
| 2 Lint and type metadata | syntax, imports, documented metadata gaps | behavior |
| 3 Unit and Qt Quick Test | logic and view contracts offscreen | compositor behavior |
| 4 Full CTest | the configured graph is green | the desktop |
| 5 Quickshell load | QML types resolve at runtime | KWin placement or input |
| 6 Real session | KWin, layer-shell, activation, theme | how the result feels |
| 7 Visual inspection | what is on screen | unseen states |

## Procedure

1. Restate the request and its acceptance criteria.
2. List the levels the change cannot be validated without.
3. Mark each level executed, failed, or not executed, with the command that ran.
4. Re-run the scoped test after the final edit, never before it.
5. Clean temporary state and confirm nothing outside the scope changed.
6. State the residual risk in one sentence per unexecuted level.

## Required before claiming completion

- The scoped test covering the changed behavior passed after the last edit.
- The `ctest` result is quoted with its filter, not summarized as "all good".
- Every KDE or KWin claim names the session and versions it was observed on.
- Every removed or weakened test is called out with its authorization.
- The dock and settings window are closed and every test instance is stopped; no
  test process is left running for the user.

## Gotchas

- A test that passed before the last edit proves nothing about the final tree.
- Offscreen success is routinely mistaken for desktop behavior; Quickshell has no
  `PanelWindow` backend offscreen.
- `git diff` ignores untracked files. Check `git status --short` before saying the
  scope is clean.
- "Tests are green" without a count or filter can hide a suite that never ran
  because configuration failed.
- A documentation claim is part of the deliverable; an unverified README sentence
  is unfinished work.

## Coordination

`testing` chooses and runs the tests; this skill judges whether their evidence is
sufficient. `code-review` finds defects; this skill reports coverage.

## Validation

```bash
git status --short
ctest --test-dir build --output-on-failure
```

Close with what ran, what passed, what did not run, and the remaining risk.
