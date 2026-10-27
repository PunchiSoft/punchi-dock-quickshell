---
name: surface-effects
description: Evaluate and implement material and finish levels, covering depth, glass, morphing, blur, shadow, highlights, and transparency, and choose the lowest-cost QML, MultiEffect, or ShaderEffect level. Use when a surface needs a visual finish, not for pure motion or global performance diagnosis.
license: GPL-3.0-or-later
metadata:
  source: Punchi Dock Remastered motion pack, adapted for Quickshell and KDE Plasma/KWin
---

# Surface effects and material

Choose the lowest technical level that achieves the requested finish, with known
cost, safe degradation, and without making the effect the default of every
element. Motion coordination follows the
[shared doctrine](../references/motion-doctrine.md).

## Coordination

- `fluid-motion` for the movement of the effect.
- `animation-performance` before approving an animated effect over large or
  repeated surfaces.
- `accessibility` when the effect affects contrast, legibility, or state.
- `quickshell-development` and `qt-kde-reference` for surface capabilities.

## Levels

Operational detail: [effect levels](references/effect-levels.md).

### Level 1 - simulated material (preferred)

Cheap properties: `scale`, `scaleX`, `scaleY`, `opacity`, `radius`, `x`, `y`,
`transform`, theme shadow/border, and theme highlight. This is the default; moving
to level 2 requires justification.

### Level 2 - Qt Quick Effects

`QtQuick.Effects` and `MultiEffect` for blur, shadow, mask, colorization, and
composition. Requirements before use:

- the effect adds something level 1 cannot;
- no stacked effects on the same surface;
- not applied to every dock delegate;
- no animated properties that force effect recompilation per frame;
- an acceptable behaviour when the effect is unavailable.

### Level 3 - shaders

`ShaderEffect` only for a finish normal QML cannot reasonably achieve: metaballs,
signed distance fields, shape fusion, distortion, refraction, displacement, or
morphing. Before introducing one, report: why QML is insufficient, expected
render cost, simultaneous instances, target Qt version, KDE/Wayland behaviour,
integrated-GPU behaviour, and impact with several dock instances. Without those
answers, do not introduce it.

## Rules

- Separate a surface's continuous motion from its material finish. A reveal from
  a control can be solved with QML geometry and the current theme surface without
  simulating refraction.
- Reserve expressive material for navigation surfaces or highlighted controls
  where it reinforces hierarchy. Evaluate contrast, light/dark theme, reduced
  motion, and cost before applying a light, shadow, or fusion response; rest must
  remain legible.
- Keep control-to-surface continuity even when the optical effect is disabled.
- One effect per surface: do not stack blur, drawn shadow, and border for one
  finish.
- Prefer the theme's surface and shadow over reproducing them.
- Do not animate blur intensity over a large surface without measuring.
- Theme shadows and borders already scale with the theme; do not hard-code pixel
  values.
- Do not use fixed colors when the effect must adapt to light or dark themes.
- Every effect degrades to a legible state: without blur, the surface remains
  coherent.
- No X11-specific dependencies.

## Verification

1. Check light and dark themes.
2. Check fractional scaling when the effect depends on pixels.
3. Check that degradation without the effect is legible.
4. Check cost with several dock instances and a full panel.
5. If animated, check fluency with a moving pointer.
6. State explicitly what could not be tested.
