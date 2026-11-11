# Menu

The fullscreen application menu (PunchiMenu). It is an overlay layer surface per
screen: `PunchiMenuWindow` composes `PunchiMenuBackdrop`, `PunchiMenuHeader` and
`PunchiMenuSections`, and `PunchiMenuController` in `services/` decides which
screen owns the open surface.

`PunchiMenuState` (in `services/`) owns the query, the order, the sections and
the selection, so the view stays a view and the whole listing is testable
without a compositor. The default order is alphabetical, one section without a
heading; the category order is one setting away, and
`services/PunchiMenuCategories.js` turns the desktop entry's categories into its
ordered sections. The adapter publishes the raw `categories` role, so a grouping
decision never depends on a KDE API in the view. The query matches the desktop entry's name, the item's own title and its
comment, and the lowercased text is prepared once per catalogue revision instead
of once per keystroke. `PunchiMenuTile` carries the four hover modes ported from
the original menu, and `PunchiMenuHighlight` is their single owner; the sections
view publishes `pointerEmphasis` down to the tiles, so the band is the pointer's
or the keyboard's and never both.

The surface pre-exists per screen, so opening never constructs the menu inside
the click. `PunchiMenuState.displayRows` prepares a heading row per named
section and rows of at most `columns` applications, and `PunchiMenuSections` is
one vertical `ListView` of those rows. The delegate count therefore follows the
viewport plus one row of cache, not the catalogue: a section with 500
applications is 72 row delegates in the model, and only the visible ones exist.
`displayRowFor()` maps the flat selection to its row, so the keyboard reveal is
one `positionViewAtIndex()` call. A wheel gesture settles on the nearest row
boundary so the resting view never shows half a cell; opening always starts at
the top and never reveals the previous selection.

Scrolling belongs to `Kirigami.WheelHandler` with the list as its target. That
handler applies the system's scroll lines and smooth-scroll preference, so a
high-resolution wheel and a touchpad keep their fine deltas instead of a local
notch constant. `PunchiMenuState` keeps the flat index of the current cell and
maps it to a section offset; `moveVertical()` keeps the column across sections
and `moveHorizontal()` continues in the neighbouring section.

A settings change to the application order rebuilds the sections; a search
collapses them to one flat list without headings, because the user asked for a
match rather than for the group it belongs to.

Settings are not embedded here. A Plasma applet had to host its own settings
view; this shell has a settings window, so the menu page lives in
`modules/settings/PunchiDockMenuSettings.qml` under its own category.
