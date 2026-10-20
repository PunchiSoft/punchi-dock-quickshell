---
name: fluid-motion
description: Choose and implement the Qt Quick animation mechanism for Punchi Dock Quickshell, keeping velocity continuous, state reversibility and cursor-bound magnification intact; use when writing or correcting one concrete animation, not for deciding what to animate or auditing existing motion.
---

# Fluid motion in Qt Quick

Convert a state change or continuous input into continuous, interruptible,
reversible motion with Qt Quick's animation system instead of imperative logic.
Read [the shared doctrine](references/motion-doctrine.md) first; it is not
repeated here.

## Coordination

- `animations` decides what moves and why.
- `motion-review` audits existing motion before a refactor.
- `animation-performance` checks cost for delegates, large surfaces, and many
  instances.
- `surface-effects` covers blur, morphing, and shaders.
- `accessibility` covers focus, keyboard, and reduced motion.

## Mechanism selection

| Situation | Mechanism |
|---|---|
| Simple change of an existing property | `Behavior on <property>` |
| Component with named states | `State` + `Transition` |
| Bounded change with a known target | `NumberAnimation` / `PropertyAnimation` |
| Target that changes continuously | `SmoothedAnimation` or a continuous function |
| Damped physical response | `SpringAnimation` |
| Several properties of one element | `ParallelAnimation` |
| Related or chained properties | `ParallelAnimation` / `SequentialAnimation` |
| Animation that should run on the render thread | `OpacityAnimator`, `ScaleAnimator`, `XAnimator`, `YAnimator` |
| Continuous input already computed per frame | direct assignment, no intermediate animation |

## Implementation rules

### Velocity continuity

An element already in motion must not restart from zero when its goal changes.
Prefer `SmoothedAnimation`; review `reversingMode` for inversions. Do not chain
new `NumberAnimation` objects per goal change.

### Reversibility and interruption

Hover, press, expansion, and contraction must invert immediately from the current
value. Do not use `stop()` then `start()` to invert; do not use timers to "let an
animation finish". The final state is always reached, even after repeated
interruptions. With motion disabled, apply the final value without animation and
emit the completion signal if one exists.

### Discrete states

Named states (`rest`, `hovered`, `pressed`, `hidden`, `expanded`) may use
`NumberAnimation` with suitable easing, preferably declared in a `Transition` so
the state is the only source of truth. A decorative one-shot response (a pulse)
may restart on a new entry, but must settle to rest when the trigger ends.

### Preferred properties

Animate transform (`scale`, `x`, `y`, `rotation`, `translation`), `opacity`,
color, radius, and border. Do not animate `width`, `height`, `implicitWidth`,
`Layout.*`, text sizes, or margins: they cascade into relayout. Keep internal
layout stable and move the visual effect outside.

### Synchronization

Use `ParallelAnimation` for properties perceived as one deformation;
`SequentialAnimation` only when order is perceptible. Coordinate microinteractions
across one to three properties, not more. Drive shared triggers from one state or
signal, never independent timers.

### Cursor-bound motion

When input is pointer position, output must be a continuous function of it. See
[dock magnification](references/dock-magnification.md); the dock already
implements the wave in `modules/dock/DockMagnification.qml` and it must not be
replaced with `hovered ? 1.5 : 1.0`.

## Durations

Use theme durations before custom values and scale them multiplicatively. Do not
impose a fixed `Math.max(...)` floor on a theme duration: it overrides the user's
animation-speed preference. A custom duration needs a documented technical reason
next to the code. If a theme duration can be zero, set the final value explicitly
instead of relying on the animator firing.

## Examples

### Good: hover with a theme duration and natural reversal

```qml
Rectangle {
    scale: hoverHandler.hovered ? 1.03 : 1.0

    Behavior on scale {
        NumberAnimation {
            duration: Kirigami.Units.shortDuration
            easing.type: Easing.OutQuad
        }
    }
}
```

### Good: continuous target without restarts

```qml
Item {
    property real targetOffset: 0

    x: targetOffset
    Behavior on x {
        SmoothedAnimation { velocity: Kirigami.Units.gridUnit * 12 }
    }
}
```

### Bad: slow linear hover, or restarting per goal change

```qml
Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.Linear } }

onPointerMoved: {
    animation.stop()
    animation.from = currentValue
    animation.to = computedTarget
    animation.start()
}
```

### Bad: continuous input converted to a binary state

```qml
onPositionChanged: icon.scale = mouseX / width
```

No influence radius, normalization, or bounds: arbitrary and discontinuous.

## Verification

1. `qmllint` on the changed files.
2. Slow and fast pointer travel over the element and neighbours.
3. Interruption in both directions.
4. Final state after repeated interruptions.
5. Spatial relation with origin, neighbours, and content through open, close,
   mid-inversion, and resize.
6. Reduced motion: final state reached, no deformation.
7. Real panel orientation and size.
8. Runtime load review when the animation touches popups, delegates, or
   `shell.qml`.

Report the chosen mechanism, why it keeps continuity or reversibility, which
theme duration was used, and what still needs visual validation.
