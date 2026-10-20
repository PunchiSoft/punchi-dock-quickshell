# Continuous dock magnification

Proximity magnification for Punchi Dock Quickshell. The behaviour already exists
in `modules/dock/DockMagnification.qml`; this reference describes how to extend it
without breaking continuity. It does not authorize a rewrite.

## Current model

| Element | Role |
|---|---|
| `scaleAt(centerX, index)` | Scale of one icon from cosine influence and progress |
| `shiftAt(centerX)` | Horizontal separation so scaled cells keep exact spacing |
| `radius` | Three and a half item pitches across, including a soft shoulder |
| `progress` | Continuous entry and exit ramp for the whole wave |
| `amplitude` / `maximumScale` | Bounded growth above rest |
| `leftInfluenceSum` | Constant-time sum of compact cosine samples |

The influence is continuous, equals 1 at the icon centre, and decays to 0 at the
radius without a step. `shiftAt` preserves original gaps at every cursor position
and zoom level, so the wave is not just an isolated icon growing.

## Rules

- Never turn magnification into a boolean per icon (`hovered ? 1.5 : 1.0`).
- Scale is a function of real distance between pointer and icon centre in one
  coordinate space. Recompute geometry when the layout, size, or orientation
  changes; do not cache absolute positions without invalidation.
- Normalize inside the radius and clamp the result. The value must never depend
  on an unbounded quotient.
- Raising maximum scale requires reviewing the radius: a high peak with a short
  radius reads as unstable; the peak must transfer continuously.
- Keep horizontal and vertical panels symmetric; the main axis decides distance.
- With reduced motion, limit the effect to a subtle change on the active icon and
  do not apply the wave to neighbours.
- Keep layout centres stable and reserve visual room for enlargement.

## Cost

`scale` and visual displacement are transforms: **LOW**. The expensive part can be
per-element geometry when the icon count grows and the pointer moves fast.

Watch for per-frame object allocation, unnecessary `mapToItem` recomputation, and
CPU spikes during fast travel. Confirm that fast pointer movement produces no
jumps or flicker.

## Multiple docks

Each dock computes its wave from its own pointer and layout. A dock that does not
contain the pointer must not magnify. Do not share one global cursor position as
the scale source without checking which dock owns it.

## Verification

1. Traverse the pointer slowly from one end to the other: the profile moves
   without steps.
2. Cross several icons quickly: no jumps and no icon left magnified.
3. Enter and leave mid-wave: scale returns to 1 without finishing the previous
   travel.
4. Check the configured maximum scale.
5. Check reduced motion.
6. Check horizontal and vertical panels and more than one visible dock.
