# Documentation

Published documentation for Punchi Dock Quickshell. These pages describe the code
as it is now; dated engineering evidence is kept outside the published tree.

English is the source language. Only English fallback strings are supported at this
stage, so the interface and these documents are English while
[README.es.md](../README.es.md) is the documentation translation.

## Document types

The tree separates four kinds of documentation, following
[Diátaxis](https://diataxis.fr/):

| Type | Answers | Where |
| --- | --- | --- |
| Tutorial | "How do I get it running for the first time?" | [Getting started](getting-started/README.md) |
| How-to | "How do I do this specific task?" | [Install and run](getting-started/install.md), [Troubleshooting](troubleshooting.md), [Development](development.md) |
| Reference | "What exactly does this option or capability do?" | [Features](features/README.md), [Configuration](configuration/README.md) |
| Explanation | "Why is it built this way?" | [Architecture](architecture/README.md), [Roadmap](roadmap.md) |

Each feature page states whether a behavior is implemented, in development,
pending validation or planned. Implementation is not validation: a passing headless check
does not prove a visual or KWin result.

## Map

| Section | Audience | Pages |
| --- | --- | --- |
| [Getting started](getting-started/README.md) | Someone evaluating or installing the dock | Install and run, compatibility |
| [Features](features/README.md) | A user or reviewer checking behavior | Applications and windows, containers, PunchiMenu, media and updates, appearance and motion, desktop integration |
| [Configuration](configuration/README.md) | A user changing the dock | Settings, dock modes, profiles |
| [Architecture](architecture/README.md) | A contributor changing the code | Overview, dock runtime, native backend, data and settings |
| [Development](development.md) | A contributor building and testing | Runtime, editor setup, developer checks, evidence levels |
| [Troubleshooting](troubleshooting.md) | A user with a failed start or a warning | Known limitations, diagnosis, recovery |
| [Roadmap](roadmap.md) | Anyone checking current scope | Stages and their status |
| [Versioning](versioning.md) | A maintainer preparing a release | Version declarations, changelog format, historical baseline |

## Related records

- [README.md](../README.md): project landing page and short feature summary.
- [CONTRIBUTING.md](../CONTRIBUTING.md): branch, evidence and repository-tree rules.
- [CHANGELOG.md](../CHANGELOG.md): delivered behavior and its validation.
- [NOTICE.md](../NOTICE.md): attribution for reused code and assets.

## Rules for this tree

- A behavior change updates the page that owns it, not only the README summary.
- Every section is a directory with an index README; every page is linked from
  that index.
- A published page never links into the ignored `docs-private/` record.
- Commands are copied from a working environment, and a link is checked before it
  is published. `tests/foundation_test.py` enforces the local links and the index
  coverage.
