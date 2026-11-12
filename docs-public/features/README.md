# Features

Reference for what the dock does today. Each page states the implemented
behavior and the validation that remains outstanding; a capability that is
planned but absent appears under **Not implemented yet** instead of being implied
by its absence.

Status vocabulary:

- **Implemented**: the code path exists and its component or headless checks pass.
- **In development**: the code path exists but a contract or surface is incomplete.
- **Pending validation**: implemented, with a real-session, visual or physical
  check still missing.
- **Planned**: scoped in the [roadmap](../roadmap.md), not implemented.

| Page | Covers | Status |
| --- | --- | --- |
| [Applications and windows](applications-and-windows.md) | Pinned launchers, launching, activation, context menus and running markers | Implemented; running markers in development, physical KDE checks pending |
| [Containers](containers.md) | Folder containers, Home and Downloads, recent applications and item icons | Implemented; desktop/theme visual validation pending |
| [PunchiMenu](punchimenu.md) | The fullscreen application menu | Implemented |
| [Media and updates](media-and-updates.md) | Media transport, Trash and the Discover update badge | Implemented; broader real-session media validation pending |
| [Appearance and motion](appearance-and-motion.md) | Magnification, bounce, tooltips, placement and keyboard navigation | Implemented; final visual review pending |
| [Desktop integration](desktop-integration.md) | Autostart, the owned KWin minimize effect and coexistence with Plasma | Implemented; physical KWin checks pending |

Configuration is documented separately: the settings window, dock modes and
portable profiles live under [Configuration](../configuration/README.md).

## Not implemented yet

- A separate second panel, or dock controls beyond the documented set.
- Drag and drop: reordering by dragging, pinning from the desktop or a menu, and
  dropping files onto a launcher or the Trash.
- PunchiMenu favourites, named folders, hiding applications, drag and drop inside
  the menu, and a configurable global shortcut.
- The parent project's media cards with artwork and track information, audio
  visualizer, calendar and clock, quick notes, separators and Control Center
  surfaces.

The parent project's README is the comparison point for these groups
([Punchi Dock Remastered](https://github.com/PunchiSoft/punchi-dock-remastered));
this tree documents a capability only after it exists and names the absence
instead of implying it.

## Validation status

Implementation and validation are separate claims. Fedora 44 with KDE Plasma
6.7.5 and KWin 6.7.5 on Wayland is the primary validated environment. Arch Linux
and Debian 13.7 KDE have passed a build and initial-start test. Physical KWin
activation, native cursor feedback, prolonged use and full visual inspection
remain pending; see [Compatibility](../getting-started/compatibility.md) and
[Troubleshooting](../troubleshooting.md).
