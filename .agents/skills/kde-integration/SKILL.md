---
name: kde-integration
description: Prefer native KDE/KWin mechanisms, adapt shell services to their APIs, and verify capabilities without disrupting the active Plasma session.
---

# Kde Integration

## Native-first rule

Every implementation must first follow the native KDE environment and the user's
active configuration. Prefer supported Qt, KDE Frameworks, KWin, Plasma,
Kirigami and Quickshell providers over custom substitutes. A successful window,
a drawn imitation or a shell command does not establish native behavior.

Apply this rule to the relevant layer:

- **Appearance:** use the active palette, `Kirigami.Theme` roles,
  `org.kde.desktop` and `RespectSystemStyle`; never hardcode accent, hover,
  focus, radius, shadow or font values. Treat Union styling as a capability to
  verify, not as an assumed default.
- **Launching and activation:** use KService, KIO and Wayland activation through
  the native adapter instead of reconstructing desktop-entry behavior in QML or
  shell commands.
- **Settings and persistence:** use KConfig/KConfigXT or the project's existing
  XDG storage contract; do not create a second settings system or duplicate KDE
  model rows.
- **Windows and compositor behavior:** use supported KWin APIs, rules, effects
  and protocols. Do not simulate cursor feedback, window actions or effects in
  QML when KWin owns them.
- **Displays, shortcuts, portals and accessibility:** use KScreen/`kscreenctl`,
  KGlobalAccel/Plasma shortcuts, XDG portals, Qt accessibility and native KDE
  controls where they exist. Do not reimplement desktop-wide services.
- **Autostart and session integration:** keep XDG/KDE entry ownership explicit;
  do not overwrite a foreign entry or claim session ownership.

When a native mechanism is unavailable, record the exact capability gap, the
installed version, the fallback and its evidence limits. Never silently raise the
minimum Qt/KDE version or present an offscreen test as native-session validation.

Define the exact KDE capability and inspect official APIs, installed metadata,
local reference evidence, or available SDK sources. Keep platform logic in
`adapters/kde/` and shared coordination in services. Do not assume Hyprland APIs
or a generic Wayland protocol exists in KWin. Verify actual advertised capabilities
and the behavior in a real session. Do not claim notification/tray/polkit names,
replace panels, edit settings, or restart Plasma during prototype work.
A successful layer surface does not establish task or workspace management.
