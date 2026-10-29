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

Quickshell is an external runtime dependency:
<https://quickshell.org/>. The project does not bundle or fork it.

The native edge sensor uses protocol descriptions from KDE
`plasma-wayland-protocols` (`kde-screen-edge-v1.xml`, MIT-CMU), wlr-protocols
(`wlr-layer-shell-unstable-v1.xml`, its permissive license), and Wayland protocols
(`xdg-shell.xml`, its MIT-style license). Their complete upstream copyright and
license notices remain in `adapters/kde/protocols/`. Generated bindings are build
artifacts. Only a layer-shell argument name is adapted for C++ compilation;
protocol wire semantics are unchanged.
