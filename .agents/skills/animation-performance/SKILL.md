---
name: animation-performance
description: Keep Punchi Dock Quickshell motion fluid by applying per-frame rules, LOW/MEDIUM/HIGH cost classes, delegate and effect limits, theme durations, and one reduced-motion criterion. Use when a visual change may affect frame cost, or when several animations or effects run at once.
license: GPL-3.0-or-later
metadata:
  source: Punchi Dock Remastered motion pack, adapted for Quickshell and KDE Plasma/KWin
---

# Animation performance

A visual improvement must not degrade perceived fluency. An animation that cannot
keep its rhythm with a full dock, several instances, and a moving pointer is
poorly sized.

Shared doctrine: [motion doctrine](../references/motion-doctrine.md).

## Coordination

- `fluid-motion` chooses the mechanism.
- `surface-effects` chooses the effect level.
- `testing` decides what evidence supports a fluency claim.
- `motion-review` inventories existing motion before a refactor.

## Per-frame rules

Prefer, in order:

1. transform (`scale`, `x`, `y`, `rotation`, `translation`);
2. `opacity`;
3. color, radius, border;
4. size of an element without layout children.

Animating `width`, `height`, `implicitWidth`, `Layout.*`, text sizes, or margins
triggers relayout and cascading repaint. If an inline expansion needs height to
yield space, measure the relayout area and keep the rest of the surface stable;
deriving visual properties from one progress does not remove layout cost.

## Prohibitions

Do not use as an animation engine:

- repeating `Timer` shifting properties;
- JavaScript loops per frame;
- high-frequency polling to simulate interpolation;
- JavaScript interpolation where Qt Quick already animates.

Do not create or destroy during an animation: delegates recreated by model or key
changes, models rebuilt per frame, hierarchies swapped by a `Loader` for an
effect, or dynamically created components when an existing state suffices.

## Cost classes

| Change | Cost |
|---|---|
| `scale` of an existing icon | LOW |
| `opacity` of a small surface | LOW |
| `x`/`y` of a small surface | LOW |
| Popup animation with scale and opacity | MEDIUM |
| Animated blur over a large surface | MEDIUM/HIGH |
| Animated shadow on many delegates | HIGH |
| Independent shader per icon | HIGH |
| Mask or clip recalculated per frame | HIGH |
| Animation that resizes a layout | HIGH |

MEDIUM or HIGH motion must explain why it cannot be LOW. A LOW transform repeated
per delegate stops being LOW. Full criteria:
[cost classification](references/cost-classification.md).

## Durations and the user preference

- Theme durations first: `Kirigami.Units.veryShortDuration`, `shortDuration`,
  `longDuration`, `veryLongDuration`.
- No fixed minimum on a theme duration; it overrides the animation-speed
  preference.
- Scale multiplicatively when a role needs to be slightly longer or shorter.
- A custom value is allowed with an explicit technical reason next to the code.
- If a duration can be 0, set the final value explicitly instead of trusting the
  animator to fire.

## Reduced motion

- Reduce duration before removing the state change.
- Remove deformations, elastic effects, and wide travel.
- Keep basic feedback and always reachable final states.
- Do not depend on motion to understand state.
- A component that declares `motionEnabled` must honour it in **all** its
  animations, not only some.
- Use one criterion per component and document it; a criterion that can never be
  false silently disables the protection.

## Examples

### Good: transform on an existing icon

```qml
scale: hovered ? 1.05 : 1.0
Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration } }
```

### Good: reduced motion keeps the final state

```qml
scale: root.motionEnabled ? highlight.visualScale : 1
```

### Bad: floor on a theme duration

```qml
duration: Math.max(140, Kirigami.Units.shortDuration)
```

### Bad: animated relayout

```qml
Behavior on Layout.preferredWidth { NumberAnimation { duration: 200 } }
```

### Bad: effect per delegate

```qml
Repeater {
    model: 40
    delegate: MultiEffect { source: icon; blurEnabled: true }
}
```

## Verification

1. Measure with the dock full of icons and with several dock instances.
2. Move the pointer fast during the animation, not only at rest.
3. Check concurrent animations, not one isolated.
4. Check with the maximum model size.
5. Check reduced motion.
6. Declare expected cost and what could not be measured.
7. For contextual openings, compare expansion, mid-inversion, resize, and
   coincidence with other animations.

Do not declare fluency without observing it in a real KDE session.
