# Menu

The fullscreen application menu (PunchiMenu). It is an overlay layer surface per
screen: `PunchiMenuWindow` composes `PunchiMenuBackdrop`, `PunchiMenuHeader` and
`PunchiMenuGrid`, and `PunchiMenuController` in `services/` decides which screen
owns the open surface.

`PunchiMenuState` (in `services/`) owns the query, the page and the selection, so
the grid stays a view and the whole listing is testable without a compositor. The
query matches the desktop entry's name, the item's own title and its comment, and
the lowercased text is prepared once per catalogue revision instead of once per
keystroke. `PunchiMenuTile` carries the four hover modes ported from the original
menu, and `PunchiMenuHighlight` is their single owner; the grid publishes
`pointerEmphasis` down to the tiles, so the band is the pointer's or the
keyboard's and never both.

The surface pre-exists per screen, so opening never constructs the menu inside
the click; the neighbouring pages are cached 600 ms after the first frame so the
opening gesture keeps its cost.

A page change is the page view's own range move: `syncPage()` assigns
`currentIndex` and Qt animates the content over `highlightMoveDuration`, which is
`0` under reduced motion. A notch that arrives mid-flight retargets that move
instead of restarting it, and `positionViewAtIndex()` is reserved for the case
where the index already matches and only the content position is stale, because
the call cancels the transition when it runs right after the assignment.

Settings are not embedded here. A Plasma applet had to host its own settings
view; this shell has a settings window, so the menu page lives in
`modules/settings/PunchiDockMenuSettings.qml` under its own category.
