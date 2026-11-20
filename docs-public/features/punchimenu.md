# PunchiMenu

The fullscreen application menu is its own layer surface per screen. The first
dock slot, labelled **Menu**, opens it. The menu takes the keyboard only while it
is open, so the desktop is never intercepted while it is closed.

A six-second recording of the menu opening from the dock and scrolling through the
installed applications is in
[the demo assets](../../assets/demo/README.md#menu-overviewwebp).

## Search

The query matches the desktop entry's name, its generic name and keywords, the
item's own title, its comment and its desktop id, ignoring case. The catalogue is
prepared once per revision instead of once per keystroke. This is why `gimp`
finds **GNU Image Manipulation Program**, whose display name does not contain the
word.

## Application order

- **Alphabetical** is the default. Names read the way a person counts, so "KDE 4"
  precedes "KDE 10".
- **Manual** keeps the configured order.
- **Categories** files every application under the family its desktop entry
  declares, in the reference order: Internet, Graphics, Multimedia, Office,
  Development, System, Utilities, Games and Education, with the entries that name
  no family last.

Alphabetical and Manual paint one list without headings. The **Application order**
setting switches the three.

## Scrolling and keyboard

- Seven columns and five rows follow the macOS reference; a narrow screen drops
  columns before the cells become unreadable, and the listing scrolls as one
  surface instead of turning pages.
- The wheel and a touchpad follow the KDE scroll amount and smooth-scroll
  preference, because the gesture goes through Kirigami's own handler.
- `Left`/`Right` move along the row and continue in the neighbouring section.
  `Up`/`Down` keep the column across sections. `PageUp`/`PageDown` move one
  viewport of rows. `Home`/`End` jump to the ends. `Return` launches.
- Only the rows on screen are built, so a catalogue of hundreds of applications
  keeps the same delegate count. A wheel gesture settles on the nearest row
  instead of leaving a cell cut in half.
- The scroll bar starts off. **Menu** settings turn it on, and it then appears only
  while the listing overflows.
- Opening always starts at the top. A pointer that enters a cell makes it current,
  and the next key press hands the single emphasis band back to the keyboard.

## Global shortcut

**Settings → Menu → Menu shortcut** assigns one global shortcut. It starts empty,
so the shell never takes a key combination until the user chooses one. The
assignment is registered through KGlobalAccel and also appears in the desktop's
own shortcut settings. KDE names the key **Meta**; the helper line in Settings
notes that most keyboards label it Super or Windows.

The shortcut closes the menu when it is open. Otherwise it opens on:

1. the only screen allowed by the screen policy;
2. the screen under the pointer, when that screen is allowed;
3. the last screen where the menu was opened;
4. the first selected screen, then the primary screen, then the first active
   screen.

The pointer screen never wins when it has no dock. A disconnected or forbidden
screen is skipped, and an unavailable compositor query falls back to the same
order. The dock's **Menu** button keeps opening on its own screen.

## Dock icon

The leading **Menu** icon in the dock has a balloon context menu. It lists the
installed applications, sorted by name; choosing one launches it. The balloon is
as wide as its content, capped at the same 24 grid units as the other dock
popups, and a name that does not fit is revealed with the label carousel on
hover or keyboard focus. At the bottom, **Remove from Dock** hides the icon,
**Show PunchiMenu** opens the fullscreen menu and **Configure PunchiDock** opens
Settings. The global shortcut and the IPC commands still open the menu, and
**Settings → Menu → Show menu button** restores the icon. The list reuses the
dock's balloon surface and shared popup rows, not a separate menu style.

## Application actions

Right-click a tile, or press the Menu key on the current cell, to open that
application's actions inside the menu surface. The actions use the same themed
balloon as the dock popups: the tail points at the cell, above or below the card
depending on the room. The entries follow KDE's own
launcher for the same desktop entry:

- the actions the `.desktop` file declares, such as **New Private Window**;
- **Open New Window** when KDE reports that the application supports another
  instance and defines no new-window action of its own;
- **Places**, grouped the way KDE reports them, for applications that open local
  locations;
- **Recent Files** with **Forget Recent Files**;
- **Pin to Dock** or **Unpin from Dock**;
- **Edit Application…**, which opens the same KMenuEdit entry as KDE.

A capability that KDE does not report for the application hides only that row.
The menu stays open behind the actions; launching one closes the whole menu,
while pinning or browsing Places keeps it open. Escape and a click outside close
the actions first and return the keyboard to the menu. Plasma's containment
entries, such as Add to Desktop or Add to Panel, are not offered because the
dock does not own a Plasma containment.

## Presentation

- A theme-washed backdrop with KWin blur behind it.
- The distribution name, with the same 0.25 theme-aware text shadow as the
  application labels.
- A close control drawn with the buttons of the user's window decoration, pinned
  to the right or left corner, or hidden. With **Hidden**, Escape, a click on the
  backdrop and the dock button still close the menu.

## Dock over the menu

With **Dock over the menu** enabled, the menu yields the overlay layer to the dock
while its surface is mapped. The dock stays visible, magnified and clickable over
the blurred backdrop, including the closing fade, and an edge-hidden dock slides in
for as long as the menu is open. A dock action closes the menu first; a launcher
click launches and returns to the desktop.

## Settings

The **Menu** category holds the background blur and opacity, icon size,
application labels, distribution name, application order, scroll bar,
close-button corner (Right, Left or Hidden), hover animation, the dock-over-menu
switch and the dock menu button. Every one applies to the
open menu without a restart.

## Compared with the parent project

Favourites, named folders, hiding applications and drag and drop inside the menu
are not implemented. See
[Features](README.md#not-implemented-yet).
