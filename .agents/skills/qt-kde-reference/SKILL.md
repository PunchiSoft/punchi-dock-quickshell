---
name: qt-kde-reference
description: Verify Qt, Kirigami, KDE, compositor, and optional native adapter API behavior and version availability before introducing integrations.
---

# API evidence

Identify the exact symbol or behavior. Consult existing reference notes first,
then installed headers/type metadata or local upstream checkouts when available.
Use directed `rg` searches; this project does not bundle `kde-sdk/`.

If local material is unavailable or version-sensitive, use official Qt, KDE,
bridge, or compositor documentation. Distinguish public API, private implementation,
and development snapshot. Check availability against the agreed minimum version.

Record the relevant symbol, source/version, decision, and evidence limits.
Do not copy entire SDK trees or treat a tutorial as runtime compatibility proof.
Do not assume a Plasma-injected QML feature exists in a standalone application.
