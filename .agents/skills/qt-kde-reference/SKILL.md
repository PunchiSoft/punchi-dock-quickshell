---
name: qt-kde-reference
description: Verify Qt, Kirigami, KDE, compositor, and native adapter API behavior and version availability, including Plasma capabilities. Use when a symbol, signal, or property is new, unfamiliar, or version-sensitive and must be confirmed before relying on it.
license: GPL-3.0-or-later
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

## Plasma 6.8 capability review

Plasma 6.8 was announced on 2026-10-14. Treat it as an upstream opportunity, not
as this project's automatic minimum. Before adopting a 6.8 feature, verify the
installed Plasma/KWin/Qt/KF6 versions, the public API or metadata, and the actual
behavior in the target session. Keep the declared minimum unchanged unless the
user explicitly approves a version change. An upstream announcement is not
evidence that this project supports that release; record the actually tested
versions separately.

Relevant capabilities to investigate, without adding them merely because they
exist:

- **Union theming beta:** Plasma 6.8 extends Union toward Qt Quick and Qt Widgets
  styling. It is optional and not the default. Verify the active application
  style and palette; do not depend on Union or hardcode its output.
- **Wayland-first session:** Plasma 6.8 retires starting X11 Plasma sessions, while
  XWayland remains available. Do not infer that the dock supports X11 or every
  Wayland compositor from this change.
- **KWin window rules for client-side decorations:** rules can add shadows,
  outlines and rounded corners to CSD windows that cannot provide them. Use KWin
  rules when the behavior belongs to the compositor; do not fake it in QML.
- **Task Manager global shortcuts:** new shortcuts cycle and move tasks. If the
  dock exposes equivalent actions, use KGlobalAccel/Plasma shortcut facilities
  and respect conflicts rather than inventing a global key grab.
- **Display and autostart tooling:** `kscreenctl` and the System Settings autostart
  toggle are useful for verification and user workflows. Use KScreen APIs where
  the application owns display behavior, and keep the project's owned XDG
  autostart entry compatible with KDE's toggle.
- **Accessibility and graphics:** native dwell-click support, HDR/HLG handling and
  compositor triple buffering belong to Plasma/KWin/Qt. Do not reimplement them
  in the dock or add GPU-specific hacks.

See the official announcement:
https://kde.org/announcements/plasma/6/6.8.0/

For every 6.8-related decision, record the symbol or behavior, the tested version,
whether it is required or optional, the fallback for older supported versions, and
what remains unvalidated.
