---
name: qml-ui-creation
description: Implement modular Quickshell windows and Qt-only views with native KDE styling, explicit inputs, intent signals, and reactive state.
---

# Qml Ui Creation

Inspect the owning module and installed Quickshell type metadata first.
Separate the window wrapper from views that can be tested with Qt Quick Test.
Use theme palettes, accessible controls, shared primitives, and explicit interfaces.
Keep process commands, persistence, and desktop work out of delegates. Preserve
reactive settings, keyboard operation, and separate interaction states. In
selection lists, selection/highlight is the single primary emphasis; do not
render pointer hover on another row while a current item is selected. Hover and
focus may differ, but they must not stack into competing backgrounds.

Default to native KDE presentation: enable `RespectSystemStyle`, use the
`org.kde.desktop` style and native `Menu`, `MenuItem`, `ItemDelegate` and
Kirigami controls before adding custom painting. Take colors, focus, hover,
radii, shadows and fonts from `Kirigami.Theme`/`Kirigami.Units`; never encode a
plausible-looking KDE color. When Plasma 6.8 Union is active, verify it as an
installed capability rather than assuming its beta behavior.

Run lint and component lifecycle tests; use Quickshell itself for its runtime types.
Do not assume Plasma-injected globals or map desktop-wide behavior to Hyprland.
