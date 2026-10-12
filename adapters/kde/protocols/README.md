# Edge protocol descriptions

Vendored upstream descriptions, retrieved on 2026-10-12, retain their full
copyright/license notices. `wayland-scanner` generates client/server declarations
and private wire metadata into the build directory.

- [KDE screen edge](https://github.com/KDE/plasma-wayland-protocols/blob/master/src/protocols/kde-screen-edge-v1.xml): desktop-internal auto-hide extension, version 1.
- [Layer shell](https://github.com/swaywm/wlr-protocols/blob/master/unstable/wlr-layer-shell-unstable-v1.xml): version 4 description; the sensor binds version 3. Its `namespace` argument is renamed `namespace_` solely to produce valid C++ headers.
- [XDG shell](https://github.com/wayland-mirror/wayland-protocols/blob/main/stable/xdg-shell/xdg-shell.xml): included for layer-shell's referenced `xdg_popup` interface metadata; the sensor creates no XDG windows or popups.

The adapter requires named `wl_output` version 4, pointer input, shared memory,
layer-shell and the KDE extension. Missing capabilities preserve local edge
activation. Updating these descriptions requires reviewing lifecycle and protocol
versions; their presence does not guarantee compositor support.
