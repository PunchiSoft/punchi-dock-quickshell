# Effect levels and admission criteria

Detail for `surface-effects`.

## Level 1 - simulated material

Expected cost: **LOW**. Preferred for most components.

| Property | Perceived effect |
|---|---|
| `scale`, `scaleX`, `scaleY` | swelling, pressure, contained bounce |
| `opacity` | appearance, fade, emphasis |
| `radius` | square-to-capsule transition |
| `x`, `y`, `transform` | displacement, follow-through |
| theme shadow and border | depth and separation |
| theme highlight | sheen and material feel |

Many material sensations need no shader:

- pressure: `scaleX` slightly up and `scaleY` slightly down, short return to 1;
- breathing capsule: `radius` and `scale` coordinated in fewer than three
  properties;
- visual fusion of adjacent shapes: bring radii closer and overlap the border
  before reaching for a shader.

## Level 2 - Qt Quick Effects and MultiEffect

`MultiEffect` is exported as `QtQuick.Effects/MultiEffect 6.5`; the project's Qt 6
minimum makes it available, but verify on each distribution.

Reasonable uses: blur, shadow, mask, colorization, composition. Avoid large
blurred surfaces, stacked blurs, and animated properties that force per-frame
effect recalculation. Reuse one effect when several elements need the same
finish.

## Level 3 - shaders

Admission requires the eight answers in the skill: necessity, cost, instance
count, Qt version, KDE/Wayland behaviour, integrated GPU behaviour, multi-dock
impact, and a legible fallback. Without them, the shader is not introduced.

## Degradation

Every effect must define its disabled state: the surface remains legible and
coherent, contrast holds in light and dark themes, and motion still reaches the
same functional state when the effect is unavailable.
