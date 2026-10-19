---
name: accessibility
description: Implement or audit QML keyboard navigation, accessible semantics, focus continuity, scaling, and reduced motion.
---

# Accessible interaction

Inventory interactive controls and the complete keyboard path for the affected
view. Prefer controls with built-in roles and states.

- Preserve visible focus and meaningful names independent of icons or color.
- Selection, focus and hover must not produce competing emphasis. A list shows
  one primary highlight; hover never adds a second frame on another row.
- Hover must not assign focus. Enter/Space activates the focused launcher.
- Use arrow navigation appropriate to row or grid geometry; preserve the nearest
  valid item when models change, rather than resetting selection accidentally.
- Popups have a predictable initial focus, Escape behavior, and focus restoration.
- Modal Tab/Shift+Tab stays in the modal; ordinary windows retain normal traversal.
- Check text expansion, scaling, themes, target size, and reduced motion.

Report keyboard and screen-reader execution separately from static semantics.
Do not claim assistive-technology compatibility without a real check.
