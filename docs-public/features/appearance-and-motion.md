# Appearance and motion

The dock's visual behavior: magnification, launch feedback, placement and the
input that follows them. Theme colors, fonts and icon sizes come from the active
Plasma/Kirigami theme.

## Magnification

- Continuous hover magnification with a themed expanding background and tooltips.
- The magnification wave, tooltips, context menus, arrow-key navigation, running
  indicators and the native auto-hide edge follow the selected screen edge.
  Side popups open inward and icons stay upright.
- The wave is a bounded continuous function of pointer distance: three neighbours
  on each side receive graded magnification, and the full amplitude follows the
  selected zoom without a separately capped shoulder.
- Pointer coordinates and cell centers stay stable during the wave, so the icon
  under the pointer does not drift.
- The 100–300% zoom preference selects the interval from the theme-derived base
  size (100%, no enlargement) to three times that base. Larger base sizes are never
  shrunk.
- Tooltips remain unscaled and follow the rendered icon top or the inward-facing
  side. Running markers stay below the icon in every orientation.

The geometry and cosine formulas are described in
[Dock runtime](../architecture/dock-runtime.md#magnification).

## Text shadow

- The fullscreen menu, folder and recent containers, Fan rows and their labels
  keep the 0.25 theme-aware text shadow.
- **Settings → Menu → Right-click menu text shadow** controls only the dock's
  right-click menu. It is on by default and can be turned off for readers who
  find the doubled edge harder to read, including some with astigmatism.
- The Fan rows keep their shadow independently of that switch.

## Launch feedback

- A two-hop bounce preserves the original peaks and easing.
- Repeated clicks coalesce their feedback without suppressing activation intents.
- The bounce offset adds to the wave lift, while the frame, hit target and balloon
  remain tied to the control transform.
- The window reserves room for the maximum bounce amplitude.
- Disabled motion, hidden surfaces or disabled controls reset feedback immediately.

## Window minimize reaction

- Off by default. **Settings → General → Minimize reaction** offers **None**,
  **Slow bounce** and **Lateral ripple**.
- The dock observes each window that minimizes and reacts on the icon of its
  application, not on a guessed neighbour.
- **Slow bounce** moves only the target icon; **Lateral ripple** also moves up to
  two neighbours, later ones with less amplitude.
- A vertical dock bounces sideways; a horizontal dock bounces vertically. A ripple
  travels along the dock's main axis.
- The reaction uses transforms and theme durations, coalesces repeated minimizes,
  and settles at rest. Reduced motion disables it entirely.
- The count comes from KDE's window model, so grouping and multiple windows keep
  one icon.

## Minimize to the icon

- The dock publishes the resting rectangle of every launcher to KWin, so the
  compositor's minimize effect animates a window to the icon of its application.
- The path is the window helper's `org_kde_plasma_window_management` integration.
  A missing helper or protocol leaves the compositor's default animation and never
  blocks the click.
- This is independent of the **Minimize reaction** switch: the window travels to
  the icon even when the icon itself stays still.
- KWin chooses the closest published task geometry, so a Plasma panel or another
  dock that publishes the same window can receive the animation instead.
- Only the resting dock is published; a hidden dock does not claim a target.

## Reduced motion

- The dock reads Kirigami durations and detects disabled system animations.
- Settings expose a separate explicit reduced-motion override.
- Reduced motion removes displacement and animated entry, retaining at most an
  instant 8% active-item emphasis.

Closing surfaces finish their fade before hiding; a test may use a bounded
observation timer, but no timer drives an animation.

## Placement and screens

- Bottom, left or right placement.
- One dock on every connected screen, sharing one profile.
- **Screens and desktops** limits the dock to selected screens, virtual desktops or
  KDE activities.
- A selected screen is remembered across hot-plug, and the system primary screen
  is used while none is connected.
- An auto-hiding dock stays visible when its edge borders another monitor.
- Running markers can follow the current desktop and activity.

## Appearance settings

- Dock settings for icon size, magnification, bounce, reduced motion, position and
  visibility.
- Popup settings for size, height and icon size in their own **Popups** category,
  applied to the folder containers.

The categories, defaults and Apply/Accept/Close behavior are documented in
[Settings](../configuration/settings.md). Visibility modes and their effect on
screen reservation are in [Dock modes](../configuration/dock-modes.md).

## Keyboard and focus

- Keyboard navigation for the dock, its context menus, the settings window and the
  fullscreen menu.
- Hover never takes keyboard focus; the dock accepts on-demand focus and restores
  it when a popup closes.
- The fullscreen menu takes the keyboard only while it is open.

Automated checks do not establish screen-reader support, fractional scaling,
physical hot-plug or full visual quality. Those remain explicit validation gaps;
see [Troubleshooting](../troubleshooting.md).
