---
name: qml-ui-creation
description: Implement modular Quickshell windows and Qt-only views with explicit inputs, intent signals, and reactive state.
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
Run lint and component lifecycle tests; use Quickshell itself for its runtime types.
Do not assume Plasma-injected globals or map desktop-wide behavior to Hyprland.
