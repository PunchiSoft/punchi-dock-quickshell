# Dock modes

Placement, visibility and the rules that decide where the dock may appear. The
saved profile stores these values; an explicit startup mode can override the
saved visibility mode for one run.

## Placement

- **Bottom** is the first-run edge. **Left** and **Right** are also supported; no
  custom top bar exists yet.
- Orientation follows the selected edge. A side dock presents a stored Fan
  container as Grid because the arc needs a top or bottom edge.
- The magnification wave, tooltips, context menus, arrow-key navigation, running
  indicators and the native auto-hide edge follow the selected edge.

Geometry and anchoring are explained in
[Dock runtime](../architecture/dock-runtime.md#placement-and-screens).

## Visibility

The settings and the start script expose four modes:

| Mode | Behavior |
| --- | --- |
| **Always visible** (`reserve`) | The dock reserves its base-space allocation |
| **Hide automatically** (`autohide`) | The dock reveals from the edge and collapses after its slide finishes |
| **Dodge windows** (`dodge-windows`) | The dock hides when a known window intersects it, outside Showing Desktop |
| **Windows go below** (`overlay`) | The dock stays above windows without reserving space; this is the first-run default |

All modes use the Top layer and declare scope `dock`, which KWin uses for
desktop-shell classification separately from the Top/Bottom layers. The default
reserves no space; reserve mode excludes the transparent top allocation.

`PunchiDockIpc` changes the policy live for every screen, so an explicit mode
switches a running instance. The dock accepts on-demand keyboard focus rather
than exclusive focus.

The start script accepts the mode as an argument:

```bash
./scripts-user/start.sh reserve
./scripts-user/start.sh dodge-windows
./scripts-user/start.sh overlay
./scripts-user/start.sh autohide
```

`autohide` reveals from the bottom edge and does not detect window overlap.
Window dodge and auto-hide keep separate policies; provider loss for window
geometry reveals the dock instead of hiding it permanently.

## Screens, desktops and activities

- One dock per connected screen, sharing one profile.
- **Screens and desktops** limits the dock to selected screens, virtual desktops
  and KDE activities.
- A selected screen is remembered across hot-plug. While none is connected, the
  policy falls back to the system primary screen.
- An auto-hiding dock stays visible when its edge borders another monitor.
- Running markers can follow the current desktop and activity while pinned items
  stay visible.

Changing the screen selection or switching desktops never recreates windows: the
policy keeps a disallowed window mapped without exclusive zone, input mask or edge
trigger. Unmapping every window would let the shell exit while a desktop is
excluded.

## Related settings

- **Updates** turns the Discover badge off without a restart; see
  [Media and updates](../features/media-and-updates.md#update-badge).
- **Start with KDE Plasma** writes a Punchi-owned autostart entry; see
  [Desktop integration](../features/desktop-integration.md#start-with-kde-plasma).
- **Reduced motion** and the appearance values are in
  [Appearance and motion](../features/appearance-and-motion.md).
