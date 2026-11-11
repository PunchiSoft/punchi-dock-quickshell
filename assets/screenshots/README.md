# Screenshots

Reference captures of Punchi Dock Quickshell running on the development machine.
They document the current interface, not a default theme or a compatibility claim
for another desktop.

Recorded on 2026-11-11 on Fedora 44 with `plasmashell 6.8.2`, `kwin 6.8.2`,
Qt 6.11.2, KDE Frameworks 6.31.0 and Quickshell 0.2.1 on Wayland. The wallpaper,
cursor and desktop theme are the maintainer's; the dock and its windows follow
the active Plasma theme through the configured palette.

## Published captures

| File | Shows |
| --- | --- |
| `settings-general.png` | Dock size, magnification, position, visibility, updates and recent applications. The profile header is blurred. |
| `settings-popups.png` | Popup appearance and behavior. The profile header is blurred. |
| `settings-menu.png` | Menu appearance and behavior, including **Application order** (Alphabetical) and the **Scroll bar** switch, off by default. The profile header is blurred. |
| `recent-applications-list.png` | Recent applications container in its first-run **List** presentation. |
| `recent-applications-grid.png` | The same container in **Grid** presentation. |
| `container-view-menu.png` | **View content as** with Grid, List, Detail and Fan. |
| `fan-view.png` | Home container as a fan of the standard XDG user folders. |
| `context-system-settings.png` | System Settings dock item with KDE actions. |
| `context-terminal.png` | Terminal dock item with new window and new tab actions. |

The small context menus are the dock's own menus. They are published as
references of the native KDE menu contents the dock reproduces, not as proof
that every KDE version renders them the same way.

## Privacy and capture notes

The settings captures blur the profile header before publication. A Downloads
container capture from the same session is not published because its labels show
personal file names; the grid presentation is represented by
`recent-applications-grid.png` instead.

Keep published captures under 10 MB. Scale them in the README with the `width`
attribute instead of rewriting the file, and avoid cropping the window so
tightly that the title or the close control disappears.
