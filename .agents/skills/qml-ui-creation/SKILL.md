---
name: qml-ui-creation
description: Implement modular Quickshell windows and Qt-only views with native KDE styling, explicit inputs, intent signals, and reactive state. Use when adding a window, a panel, a popup, or a reusable QML control.
license: GPL-3.0-or-later
---

# QML UI creation

Inspect the owning module and installed Quickshell type metadata before writing a
surface. A view that cannot be loaded without the shell runtime cannot be tested.

## Procedure

1. Name the module that owns the surface and the primitive it should reuse.
2. Split the window wrapper (Quickshell or `Window`, host, geometry) from the
   view (content, interaction), so the view loads in Qt Quick Test.
3. Declare inputs as properties, outputs as intent signals, and state as
   reactive reads; no commands, persistence, or desktop calls in delegates.
4. Use native KDE presentation before custom painting.
5. Separate selection, focus, hover, press, and disabled states.
6. Add the view to `tests/qml/` and run lint plus the component suite.

## Rules

Default to native KDE presentation: enable `RespectSystemStyle`, use the
`org.kde.desktop` style and native `Menu`, `MenuItem`, `ItemDelegate` and
Kirigami controls before adding custom painting. Take colors, focus, hover,
radii, shadows and fonts from `Kirigami.Theme`/`Kirigami.Units`; never encode a
plausible-looking KDE color. When Plasma 6.8 Union is active, verify it as an
installed capability rather than assuming its beta behavior.

Keep process commands, persistence, and desktop work out of delegates. Preserve
reactive settings, keyboard operation, and separate interaction states. In
selection lists, selection/highlight is the single primary emphasis; do not
render pointer hover on another row while a current item is selected. Hover and
focus may differ, but they must not stack into competing backgrounds.

A transient row in a popup, menu or arc has no durable selection, so one band is
shared: the owner publishes `pointerEmphasis`, real pointer motion takes it, a
Tab/Backtab/Shortcut focus reason releases it, and the row binds
`hovered && pointerEmphasis` and `visualFocus && !pointerEmphasis`. Forward the
opening focus reason from the caller instead of forcing `Qt.TabFocusReason`.

## Gotchas

- A view importing `Quickshell` or `Punchi.Kde` cannot be instantiated by Qt
  Quick Test; keep the wrapper thin and the view import-clean.
- `pragma ComponentBehavior: Bound` is already used across the dock and settings
  views; a delegate that reaches a free id without it breaks when the component
  is instantiated from a model.
- A hard-coded pixel size ignores `Kirigami.Units` scaling and breaks the dock on
  a scaled output.
- Two surfaces that both animate the same state fight each other; one owns the
  transition.
- A delegate cannot decide which input moved last; only the surface that receives
  both the pointer and the focus can own `pointerEmphasis`.
- `Window.window` and `Window.activeFocusItem` are attached properties: read them
  on an `Item` (`root.Window.window`). A `Window` object inside `Connections`
  warns and never updates.
- `onCompleted` that writes a property the view also binds hides a missing
  default rather than fixing it.
- Do not assume Plasma-injected globals, and do not map desktop-wide behavior to
  Hyprland.

## Validation

```bash
ctest --test-dir build --output-on-failure \
  -R '^(qml_lint|emphasis_contract|dock_components|folder_container)$'
python3 scripts-dev/validate-qml.py "$(command -v qmllint6 || command -v qmllint)"
```

Report lint, component test, runtime load, and visual inspection separately.
