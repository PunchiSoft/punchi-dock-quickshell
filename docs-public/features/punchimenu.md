# PunchiMenu

The fullscreen application menu is its own layer surface per screen. The first
dock slot, labelled **Menu**, opens it. The menu takes the keyboard only while it
is open, so the desktop is never intercepted while it is closed.

A six-second recording of the menu opening from the dock and scrolling through the
installed applications is in
[the demo assets](../../assets/demo/README.md#menu-overviewwebp).

## Search

The query matches the desktop entry's name, the item's own title and its comment,
ignoring case. The catalogue is prepared once per revision instead of once per
keystroke. Keywords are not searched.

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

## Presentation

- A theme-washed backdrop with KWin blur behind it.
- The distribution name, with the same 0.25 theme-aware text shadow as the
  application labels.
- A close control drawn with the buttons of the user's window decoration.

## Dock over the menu

With **Dock over the menu** enabled, the menu yields the overlay layer to the dock
while its surface is mapped. The dock stays visible, magnified and clickable over
the blurred backdrop, including the closing fade, and an edge-hidden dock slides in
for as long as the menu is open. A dock action closes the menu first; a launcher
click launches and returns to the desktop.

## Settings

The **Menu** category holds the background blur and opacity, icon size,
application labels, distribution name, application order, scroll bar, close-button
corner, hover animation and the dock-over-menu switch. Every one applies to the
open menu without a restart.

## Compared with the parent project

Favourites, named folders, hiding applications and drag and drop inside the menu
are not implemented. See
[Features](README.md#not-implemented-yet).
