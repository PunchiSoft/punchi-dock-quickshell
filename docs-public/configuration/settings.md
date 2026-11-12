# Settings

The settings window is composed of a bounded category sidebar and a page per
category. **Apply** saves pending changes, **Accept** saves and closes, and
**Close** discards them.

## Categories

| Category | Holds |
| --- | --- |
| **Items** | The pinned item list, Add Item, ordering, item configuration and removal |
| **General** | Icon size, magnification, bounce, reduced motion, position, visibility, screens and desktops, updates and autostart |
| **Popups** | Popup size, height and icon size for the folder presentations |
| **Menu** | Fullscreen-menu blur, opacity, icon size, labels, distribution name, order, scroll bar, close-button corner, hover animation and dock-over-menu |
| **Profile** | Portable profile export and import with preview |
| **About** | Application version, website and issue links, license, authors and the **Made with love** dedication |

**Items** lists the pinned projection. **Add Item** opens a type selector for
applications, folder containers and Trash. Application search and selection never
launch an application; only accepting the modal adds it to the pending draft.
Removing a user folder removes its descriptor, never the directory or its
contents. Up/down keyboard navigation selects list entries, and action activation
changes the pending draft.

**Popups** applies size, height and icon size to the folder containers. The grid,
the list/detail rows and the fan keep independent glyph sizes.

**Menu** changes apply to the open fullscreen menu without a restart. See
[PunchiMenu](../features/punchimenu.md#settings).

**Profile** exports the pending values and previews an import before it replaces
the draft. See [Profiles](profiles.md).

**About** shows the version declared by this tree, the website and issue links,
the license and the authors. **Reset defaults** restores a fresh copy of
`config/PunchiDefaultProfile.js`; a first install and an explicit reset cannot
drift apart.

## First-run defaults

Without a saved file, the application uses the defaults in
`config/PunchiDefaultProfile.js`, which also supplies the first-run launcher
catalogue and the values restored by **Reset defaults**:

| Setting | Current first-run default |
|---|---|
| Surface | Bottom dock by default; Bottom, Left or Right; no custom top bar yet |
| Pinned items, in order | Dolphin, Konsole, Home, Browser, Kate, System Settings, Discover, Gwenview, Okular, Downloads, Trash |
| Size | 100% of the theme-derived base size |
| Pointer magnification | Enabled, with a maximum scale of 200% |
| Click bounce | Enabled |
| Screens | Every connected screen, one shared profile |
| Virtual desktops and activities | All desktops and activities |
| Visibility | Windows go below (`overlay`), without reserving screen space |
| Reduced motion | Local override off; KDE animation preferences still apply |
| Icons | The user's icon theme, including live KDE theme-change notifications |
| Fullscreen menu | Blur on, 60% background opacity, application labels on, distribution name on, alphabetical order, scroll bar off, dock over the menu, close button on the right |

These are prototype defaults, not a guarantee that every preset application is
installed. **Browser** names a role instead of an application: the item opens the
browser KDE has as the preferred handler for web links, so it follows the default
chosen in System Settings and never assumes Firefox is present.

## Persistence

Preferences persist independently of Plasma. Changing settings through Apply or
Accept persists the user's values, and later starts load them. An explicit startup
mode can override the saved visibility mode.

The current file format is version 16 and accepts versions 1 to 15 through
migration. The version history, migration rules, defaults for missing fields and
the portable-profile format are documented in
[Data and settings](../architecture/data-and-settings.md#persistence).

At first start, an existing `punchi-shell.json` is migrated to the new filename
only when the new file does not exist; the original file is kept as a backup. If
both files exist, the new filename takes precedence and neither is overwritten.

## Related pages

- [Dock modes](dock-modes.md): placement, visibility, screens and desktops.
- [Profiles](profiles.md): export, import and preview.
- [Desktop integration](../features/desktop-integration.md): autostart and the
  owned KWin minimize effect.
