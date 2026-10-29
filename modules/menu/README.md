# Menu

The fullscreen application menu (PunchiMenu). It is an overlay layer surface per
screen: `PunchiMenuWindow` composes `PunchiMenuBackdrop`, `PunchiMenuHeader` and
`PunchiMenuGrid`, and `PunchiMenuController` in `services/` decides which screen
owns the open surface.

`PunchiMenuState` (in `services/`) owns the query, the page and the selection, so
the grid stays a view and the whole listing is testable without a compositor.
`PunchiMenuTile` carries the four hover modes ported from the original menu, and
`PunchiMenuHighlight` is their single owner.

The surface pre-exists per screen, so opening never constructs the menu inside
the click; the neighbouring pages are cached 600 ms after the first frame so the
opening gesture keeps its cost.

Settings are not embedded here. A Plasma applet had to host its own settings
view; this shell has a settings window, so the menu page lives in
`modules/settings/PunchiDockMenuSettings.qml` under its own category.
