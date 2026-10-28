---
name: accessibility
description: Implement or audit QML keyboard navigation, accessible names, focus continuity, scaling, and reduced motion in dock views. Use when adding or reviewing an interactive surface, a focus path, or an accessibility claim.
license: GPL-3.0-or-later
---

# Accessible interaction

A surface is accessible when the whole path works without a pointer: discover,
focus, activate, escape, and an announcement that matches what is drawn.

## Procedure

1. List every interactive control in the affected view and the role it exposes.
2. Write the keyboard path in order: initial focus, traversal, arrow keys,
   Enter or Space, Escape, and where focus returns.
3. Give each control a name that survives icon-only rendering.
4. Apply one primary emphasis rule across selection, focus, and hover.
5. Replace the model while an item is focused and confirm focus continuity.
6. Check text scaling, target size, high contrast, and reduced motion.
7. Separate static semantics from executed keyboard and assistive-technology
   evidence in the report.

## Rules

- Preserve visible focus and meaningful names independent of icons or color.
- Selection, focus and hover must not produce competing emphasis. A list shows
  one primary highlight; hover never adds a second frame on another row.
- Hover must not assign focus. Enter/Space activates the focused launcher.
- Use arrow navigation appropriate to row or grid geometry; preserve the nearest
  valid item when models change, rather than resetting selection accidentally.
- Popups have a predictable initial focus, Escape behavior, and focus restoration.
- The opening input decides the focus reason. A pointer open forwards
  `Qt.MouseFocusReason`; only a keyboard open forwards `Qt.TabFocusReason`. A
  forced Tab reason paints a keyboard band under a pointer that never moved.
- Moving rows have one emphasis owner: pointer motion takes the band, a Tab,
  Backtab or Shortcut focus reason releases it, and the row binds both through
  `pointerEmphasis`. `emphasis_contract` guards the pattern.
- Modal Tab/Shift+Tab stays in the modal; ordinary windows retain normal traversal.
- Check text expansion, scaling, themes, target size, and reduced motion.

## Gotchas

- A custom `Rectangle` delegate with a `MouseArea` exposes `Accessible.NoRole`,
  so assistive clients cannot reach it. Prefer `ItemDelegate` or `Button`, which
  already publish role, name, and activation.
- A `Keys.onPressed` handler that accepts the event consumes Space or Enter
  before the control activates. Observe without accepting, or do not add one.
- `forceActiveFocus()` in a hover handler moves focus for keyboard users. Hover
  may change emphasis only.
- `Qt.TabFocusReason` passed at popup open makes `visualFocus` true while the
  pointer is still, so the row paints hover and focus bands together. Pass the
  caller's reason instead of a constant.
- Focus reason is not visible state by itself: `visualFocus` is false for
  Mouse, Popup, Other and ActiveWindow reasons and true for Tab, Backtab and
  Shortcut. Do not infer keyboard presence from `activeFocus` alone.
- Replacing the model resets the current index unless it is restored explicitly.
- `closePolicy: Popup.NoAutoClose` stops Escape from closing a popup; that
  surface then needs its own handler and explicit focus restoration.
- Reduced motion must reach the same final state. Removing a `Behavior` is not
  enough if the state was only ever applied by the animation.

## Validation

```bash
ctest --test-dir build --output-on-failure \
  -R '^(qml_lint|emphasis_contract|dock_components)$'
```

- Walk the path with the pointer untouched; every action stays reachable.
- Open and close a popup twice: focus returns to the control that opened it.
- Report keyboard execution separately from static semantics. Do not claim
  assistive-technology compatibility without a real check.
