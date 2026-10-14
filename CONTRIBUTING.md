# Contributing

Read [AGENTS.md](AGENTS.md) first and the local `docs/architecture.md` record.
Use English and keep changes scoped to one concrete behavior or responsibility.

Preserve safe coexistence with Plasma, theme adaptation, keyboard access, reactive
settings, and protected behavioral tests. Use the checks described in the local
`docs/development.md` record and describe the observable result, validation, and
limitations in pull requests.
Do not commit private evidence, credentials, generated packages, or local SDK trees.
Preserve attribution for reused code and assets.

Delivery commits use the project's padded counter (`0.1.00`, `0.1.01`, ...),
advancing once per delivery commit; a delivery split into one commit per feature
advances once per feature commit. Update the version declarations and the local
`docs/versioning.md` record together; configuration schema and QML module
versions have independent compatibility contracts.
