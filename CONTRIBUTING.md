# Contributing

Read [AGENTS.md](AGENTS.md) first. Use English and keep changes scoped to one
concrete behavior or responsibility.

Preserve safe coexistence with Plasma, theme adaptation, keyboard access, reactive
settings, and protected behavioral tests. Describe the observable result,
validation, and limitations in pull requests. Run the validation commands in the
README and the relevant repository skills before submitting.
Do not commit private evidence, credentials, generated packages, or local SDK trees.
Preserve attribution for reused code and assets.

Delivery commits use the project's padded counter (`0.1.00`, `0.1.01`, ...). It
advances once per commit that changes application behavior, and once per feature
commit when such a delivery is split. Repository metadata and documentation-only
commits (`README.md`, `CHANGELOG.md`, `.gitattributes`, local `docs/`, skills) do
do not advance it. Update the version declarations consistently; maintainers also
update their local versioning record. Configuration schema and QML module versions
have independent compatibility contracts.
