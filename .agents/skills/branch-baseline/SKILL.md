---
name: branch-baseline
description: Create every work branch from an updated main after verifying the base, and justify a sub-branch explicitly. Use when starting a change, creating or switching a branch, or checking whether the current tree is the right base.
license: GPL-3.0-or-later
---

# Branch baseline

A branch name says nothing about its base. Verify the base from Git, not from
memory: a branch created from another feature branch or from a stale local `main`
attaches work that is not yours, and the mistake stays invisible until review or
rebase.

## Rule

Work branches come from an updated `main`. A sub-branch is the exception, and it
needs a stated reason:

- the parent is unpublished and cannot merge without this change, or
- two independent changes must be reviewed separately before either merges.

Without one of those, create the branch from `main` directly. Never stack silently.

## Procedure

1. Read the state before touching anything:

   ```bash
   git --no-pager status --short
   git --no-pager branch --show-current
   git --no-pager log --oneline -1
   ```

   Uncommitted changes that are not yours stop the procedure: ask before
   switching, because a switch carries them to the new branch.

2. Refresh the remote and compare the three references:

   ```bash
   git fetch origin --quiet
   git --no-pager rev-list --left-right --count main...origin/main
   git --no-pager rev-list --left-right --count main...HEAD
   ```

   The first count is `behind ahead` for local `main`: a nonzero left number means
   `main` is stale. An empty second count means `HEAD` is `main` itself.

3. Update `main` by fast-forward only, then branch from it:

   ```bash
   git switch main && git merge --ff-only origin/main
   git switch -c feat/<descriptor>          # or fix/, docs/, chore/
   ```

   A fast-forward that fails means local `main` has commits of its own: resolve
   that first instead of branching from a divergent base.

4. Prove the base is `main` and not something else:

   ```bash
   git --no-pager rev-list --left-right --count main...HEAD   # expect: 0 0
   git --no-pager log --oneline origin/main..HEAD             # expect: empty
   ```

5. For a sub-branch, record the parent and the justification, then confirm it:

   ```bash
   git switch -c <prefix>/<descriptor> <parent-branch>
   git --no-pager log --oneline main..HEAD    # the parent's commits, reviewed once
   ```

   Moving it onto `main` later is `git rebase --onto origin/main <parent-tip>`.

6. Record the branch name in the change note before editing.

## Gotchas

- A local `main` behind `origin/main` produces a "new" branch from stale content;
  only step 2 exposes it.
- A local branch whose commits were squash-merged is duplicated work, not a base.
  Compare before trusting it: `git --no-pager log --oneline origin/main..HEAD`, and
  `git --no-pager diff --stat HEAD origin/main -- <the files you will touch>`.
- Starting from a colleague's or a previous feature branch adds unrelated commits
  that appear in the pull request; step 4 catches it in one line.
- A clean `git status` says nothing about the base; it only says nothing is
  uncommitted.
- Switching branches with pending edits moves them silently. That is the second
  reason to read `git status` first.

## Coordination

`modification-cycle` owns the change itself and defers branch creation to this
skill. `commit-push-versioning` reviews staged content on the branch this skill
created.

## Validation

```bash
git --no-pager rev-list --left-right --count main...HEAD
git --no-pager log --oneline origin/main..HEAD
git --no-pager status --short
```

Report the three reference counts, the branch name, and whether it was created
from `main` or from a justified parent. The first check afterwards depends on
what the change edits, not on the branch.
