---
name: code-review
description: Review the change before it ships, reading the exact diff and classifying each finding as blocking or non-blocking against the project's domain rules. Use when a change is about to be committed or opened as a pull request, or when the user asks for a review of their own work.
license: GPL-3.0-or-later
---

# Code review

Review the change, not the intent behind it. A finding needs a `file:line` and an
observable consequence; preferences without one are noise.

## Procedure

1. Establish the exact range: `git diff` for unstaged work, `git diff --cached`
   for staged work, `git diff main...HEAD` for a delivery branch.
2. Read the whole diff before commenting. A later hunk often explains an earlier
   one.
3. Walk the domains the diff touches, using the table below.
4. Reproduce each risky path with a scoped test instead of reasoning alone.
5. Classify every finding as blocking or non-blocking, and never mix the lists.
6. Hand the result to `commit-push-versioning`. Do not stage, commit, or push
   from inside a review.

## Domain checklist

| Area | Look for |
|---|---|
| QML bindings | an assignment that breaks a `Binding`; a value cached in a local; hover writing focus |
| Services | desktop or persistence work in a visual component; swallowed error; unbounded loop |
| KDE adapters | a new path without a capability probe or fallback; missing ownership record |
| Layout and motion | relayout instead of transform; duration not taken from theme units |
| Settings | schema change without migration; one key written by two owners |
| i18n | runtime string without `qsTr`; concatenated translated fragments |
| Tests | assertion weakened or removed; owned temporary state not cleaned |
| Docs and version | version bumped inconsistently; claim not verified |

## Blocking criteria

- Behavior differs from the request or the documented contract.
- A protected test is removed, disabled, or weakened.
- KWin or Plasma state can stay modified after an unclean exit.
- Untrusted input reaches a path, command, or shell without bounds.
- A public interface or setting name changes silently.

## Gotchas

- A green run after editing a test may mean the assertion disappeared. Read the
  test diff before trusting the result.
- Reformatting hides logic changes. A `git diff -w` pass is a second pass, never
  the only one.
- A new default in `config/` reaches every consumer: check the settings schema,
  the fixture models, and the tests that encode the old value.
- Reviewing only added lines misses deleted guards; read the `-` hunks.
- Adding a rule to `AGENTS.md` is not a review of the code; the rule also needs a
  consumer.

## Validation

```bash
git --no-pager diff --stat
ctest --test-dir build --output-on-failure -R '<scoped>'
```

Report the range reviewed, findings by class, the test evidence, and what was not
reviewed.
