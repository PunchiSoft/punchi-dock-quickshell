---
name: publication-review
description: Audit repository content, history, identity, documentation and GitHub settings before changing visibility or creating a public mirror.
---

# Publication review

Use this before changing a repository from private to public, or before creating
a clean public repository from a private working history. Publication is a
one-way exposure of tracked content and reachable history.

## Scope and strategy

Resolve the exact source repository, intended public name, target visibility and
whether the private history must remain private. Choose one:

- Publish the existing history after removing private paths.
- Create a clean public repository and keep the old repository private.
- Publish as-is only after confirming every historical path is acceptable.

Never assume that deleting a path in the current tree hides it from history.
Do not create, rename or change visibility without explicit authorization.

## Audit before mutation

- Search tracked files and every commit for secrets, credentials, personal
  paths, hostnames, private URLs and author emails.
- List every path ever tracked; ignored directories may still exist in history.
- Check large files, binaries, generated output, licensed assets and attribution.
- Check for telemetry, unexpected network calls and privileged system changes.
- Confirm the README states the project stage explicitly (for alpha projects,
  "under construction"), its validated environment and known limitations.
- Remove public links to documents that will not be published.
- Run the configured tests and confirm the declared delivery version.

## Protect and rewrite

Create a verified bundle and mirror before rewriting. For a clean public mirror,
keep the private repository as the archive and push only the reviewed history.
For a rewrite, remove exact paths from every commit, then expire reflogs and
prune unreachable objects. Replace personal commit emails with the provider's
noreply address when required.

Verify after mutation: no commits or objects for excluded paths, no personal
emails, no unreachable sensitive objects, and a clean working tree.

## Publication and settings

Publish the reviewed tree, then configure description, topics, issues, wiki,
projects and security reporting. Enable private vulnerability reporting only
when the provider exposes it for the new visibility. Remember that force-push
does not guarantee immediate deletion of provider-cached commits; request a
purge when zero trace is required.

Record the strategy, backup location, verification commands and any pending
provider-side purge. Do not tag or release unless separately requested.
