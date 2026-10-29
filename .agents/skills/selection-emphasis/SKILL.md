---
name: selection-emphasis
description: Prevent competing selection and hover fills in QML lists, sidebars, and delegates while preserving keyboard focus and the active Plasma or Kirigami theme. Use when a list, grid, tab, or sidebar shows a current item that also reacts to the pointer.
license: GPL-3.0-or-later
---

# Selection emphasis

Use this skill for QML surfaces that show selected or current rows, categories,
tabs, launcher entries, or delegates that also react to the pointer.

## Rule

Each selection set has exactly one primary emphasis. A selected/current item may
use the theme highlight fill plus highlighted text and icon colors. While any
selection is active, pointer hover must not paint a second filled background on
another item. Hover may still provide a tooltip or a pointer cursor change; it
must not compete with the selection fill.

Keep the states distinct:

- **Selection** is durable until another item is chosen.
- **Hover** is transient pointer presence, never steals focus, and never adds a
  second fill while a selection exists.
- **Focus** must remain visible independently; never use hover styling as the
  focus indicator.
- **Press** and **drop** express separate intents, not selection.

Failure signs: two adjacent rows/categories filled at once, the selection losing
contrast while the pointer moves, icon or text colors flipping on hover, or a
hardcoded accent color that ignores the user's scheme.

## Native behavior and theme

1. Inspect the installed Qt Quick Controls style and, for Plasma work, the local
   reference checkout when present:
   - Punchi Dock Remastered declares its settings categories with
     `ConfigModel`/`ConfigCategory` in `contents/config/config.qml`; Plasma's
     configuration dialog owns sidebar hover, selection and focus painting. Do
     not reimplement those states in plasmoid QML.
   - Its `kde-sdk/` tree contains the matching Qt/Plasma sources for checking
     the native behavior.
2. Prefer native `ItemDelegate`, `ListView`, Kirigami controls and the user's
   QQC2 Desktop Style. Let the style paint checked, highlighted and focus states.
3. In menus, follow the installed `org.kde.desktop` `MenuItem` contract: hover and
   highlight use `Kirigami.Theme.focusColor` at 0.3 with a 1px focus border,
   press uses solid `focusColor`, and text/icon switch to highlighted colors on
   press. Keep keyboard focus as a separate outline; do not turn focus into a
   hover fill. Verify against the installed style because Union may differ.
4. Never hardcode colors. Use the active theme roles:
   `Kirigami.Theme.highlightColor`, `highlightedTextColor`, `textColor`,
   `backgroundColor`, `focusColor` and `disabledTextColor`. For symbolic icons,
   use `Kirigami.Icon.color`.
5. Preserve `Kirigami.Theme.colorSet` and `Kirigami.Theme.inherit`; do not reset
   the theme on a child to force a specific look.
6. Verify the user's light and dark schemes and a non-default accent color.
   Check selected text/icon contrast and that keyboard focus remains visible.

## Implementation patterns

Lists that can have no selection (for example the dock-items list):

```qml
ItemDelegate {
    property bool selectionActive: false
    hoverEnabled: !root.selectionActive
    highlighted: root.selected
    // ...
}
```

The view passes `selectionActive: selectedId.length > 0`, so hover works only
while the list has no current item. This is the existing `PunchiApplicationListRow`
contract.

Navigation where an item is always current (settings categories, tabs):

```qml
ItemDelegate {
    // The selected fill is the only emphasis while a page is current.
    hoverEnabled: false
    checkable: true
    checked: ...
    highlighted: checked
    // ...
}
```

Do not use `hovered` to drive the same background, icon color or text color as
selection. If a non-fill hover affordance is required, make it visually
subordinate and confirm it cannot be mistaken for selection.

## Transient rows: the pointer and the keyboard share one band

Menus, context menus and folder arcs have no durable selection, so the pointer
and the keyboard paint the same band. The exact owner is the input modality that
moved last, and only the owner may show it:

- The row declares `property bool pointerEmphasis: true`.
- Real pointer motion over the surface sets it to `true`.
- A focus reason of `Qt.TabFocusReason`, `Qt.BacktabFocusReason` or
  `Qt.ShortcutFocusReason` sets it to `false`.
- Every band binding consults it: `hovered: root.hovered && root.pointerEmphasis`
  and `focused: root.visualFocus && !root.pointerEmphasis`.

The owner is the surface that receives the pointer and the focus, never the
delegate: a delegate cannot know which modality moved last. When the surface is
a popup, connect to `root.Window.window` and `Window.activeFocusItem`; a
`Window` object inside `Connections` warns and does not observe anything.

Opening a popup with the pointer must forward `Qt.MouseFocusReason` so the first
row holds focus without painting a band. Hardcoding `Qt.TabFocusReason` at open
paints a keyboard band under a still pointer, which is the double hover this
contract exists to prevent. Forward the caller's reason instead:
`openFocusReason = fromKeyboard ? Qt.TabFocusReason : Qt.MouseFocusReason`.

`scripts-dev/check-emphasis.py` (`emphasis_contract`) enforces the gate on every
`PunchiPopupRowHighlight`, the owner declaration, and that `requestInitialFocus` never
hardcodes `Qt.TabFocusReason`. Run it before touching a row component.

## Checklist

- One filled selection at a time; no second hover fill.
- Hover never steals keyboard focus; focus remains visible.
- All colors come from the active theme; accent changes follow.
- Native style and components are preferred; custom backgrounds use theme roles.
- Keyboard activation, `Accessible.name` and existing object names are preserved.
- A component test asserts `hoverEnabled === false` while selection is active.
- A transient row has one band: keyboard focus after a pointer open paints none,
  and a keyboard move removes the pointer band.
- `qml_lint`, `emphasis_contract`, component tests and a light/dark visual check
  pass.

## Validation

```bash
ctest --test-dir build --output-on-failure \
  -R '^(qml_lint|emphasis_contract|dock_components|folder_container)$'
```

Offscreen tests prove state contracts, not theme fidelity. Inspect the real
window with light and dark schemes and the user's accent color before declaring
visual validation.
