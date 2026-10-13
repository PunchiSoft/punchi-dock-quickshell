# Contributing

Read [AGENTS.md](AGENTS.md) and [architecture](docs/architecture.md) first.
Use English and keep changes scoped to one concrete behavior or responsibility.

Preserve safe coexistence with Plasma, theme adaptation, keyboard access, reactive
settings, and protected behavioral tests. Use [the development checks](docs/development.md)
and describe the observable result, validation, and limitations in pull requests.
Do not commit private evidence, credentials, generated packages, or local SDK trees.
Preserve attribution for reused code and assets.

Delivery commits use the project's padded counter (`0.1.00`, `0.1.01`, ...),
advancing once per grouped delivery. Follow [versioning](docs/versioning.md) and
keep the application version declarations consistent; configuration schema and
QML module versions have independent compatibility contracts.
