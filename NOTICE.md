# Attribution

The logo is copied unchanged from Punchi Dock Remastered, preserving its
2026 Punchi Dock Contributors copyright and GPL-3.0-or-later SPDX declaration.
The license text is preserved in [LICENSE](LICENSE).

Instructions and workflows are adapted from Punchi Dock Remastered and the
Punchi Dock Rust foundation. The horizontal cosine wave, displacement integral, upward lift, and high-resolution
icon sizing are adapted from Punchi Dock Remastered `DockItem.qml` (GPL-3.0-or-later).
Its background MSAA pattern informs the shared antialiasing surface.
`PunchiTwoHopBounce.qml` is reused with attribution, and `PunchiDockClickFeedback.qml`
adapts the bounce branch of `DockItemClickFeedback.qml` under GPL-3.0-or-later. The original
rounded-image shader was reviewed but is not bundled: this stage uses named theme
icons and geometric backgrounds, not image clipping.

Caelestia Shell is an architectural and visual inspiration:
<https://github.com/caelestia-dots/shell>. Its implementation targets Hyprland;
KDE-specific behavior must be researched and implemented separately. No Caelestia
source or assets are copied in this stage.

The motion curve catalogue in `.agents/skills/animations/references/curves.md`
adapts the UI easing values and timing guidance from Emil Kowalski's skills
(<https://github.com/emilkowalski/skills>, MIT License, Copyright (c) 2026 Emil
Kowalski). The paired-element timing, the sorted curve families and the
frequency/spring guidance were checked against the Vercel open-agents
web-animation-design skill (<https://github.com/vercel-labs/open-agents>, MIT
License, Copyright (c) 2026 Vercel, Inc.). The values are expressed for Qt Quick;
no web implementation is copied.

The `morph-transition` skill and its pattern catalogue adapt concepts, not source
code, from the Material Design 3 container transform
(<https://m3.material.io/styles/motion/transitions/transition-patterns>), the
`container-transform` skill in soilmass/motion-design-agent (MIT License,
Copyright (c) 2025 edox1), the LiquidMorph description in the `fluid_glass`
package (<https://pub.dev/packages/fluid_glass>, Apache-2.0), and the SDF morph
field in StatIndet/quickshell (<https://github.com/StatIndet/quickshell>,
GPL-3.0). The timing proportions, the clip-from-origin model, the path morph and
the smooth-minimum are rewritten for Qt Quick; no upstream implementation is
bundled.

Quickshell is an external runtime dependency:
<https://quickshell.org/>. The project does not bundle or fork it.

The native edge sensor uses protocol descriptions from KDE
`plasma-wayland-protocols` (`kde-screen-edge-v1.xml`, MIT-CMU), wlr-protocols
(`wlr-layer-shell-unstable-v1.xml`, its permissive license), and Wayland protocols
(`xdg-shell.xml`, its MIT-style license). Their complete upstream copyright and
license notices remain in `adapters/kde/protocols/`. Generated bindings are build
artifacts. Only a layer-shell argument name is adapted for C++ compilation;
protocol wire semantics are unchanged.
