---
name: qml-ui-creation
description: Implement modular Quickshell windows and Qt-only views with explicit inputs, intent signals, and reactive state.
---

# Qml Ui Creation

Inspect the owning module and installed Quickshell type metadata first.
Separate the window wrapper from views that can be tested with Qt Quick Test.
Use theme palettes, accessible controls, shared primitives, and explicit interfaces.
Keep process commands, persistence, and desktop work out of delegates. Preserve
reactive settings, keyboard operation, and separate interaction states.
Run lint and component lifecycle tests; use Quickshell itself for its runtime types.
Do not assume Plasma-injected globals or map desktop-wide behavior to Hyprland.
