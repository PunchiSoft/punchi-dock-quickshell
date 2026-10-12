---
name: kde-integration
description: Adapt shell services to KDE/KWin APIs and verify capabilities while preserving the active Plasma session.
---

# Kde Integration

Define the exact KDE capability and inspect official APIs, installed metadata,
local reference evidence, or available SDK sources. Keep platform logic in
`adapters/kde/` and shared coordination in services. Do not assume Hyprland APIs
or a generic Wayland protocol exists in KWin. Verify actual advertised capabilities
and the behavior in a real session. Do not claim notification/tray/polkit names,
replace panels, edit settings, or restart Plasma during prototype work.
A successful layer surface does not establish task or workspace management.
