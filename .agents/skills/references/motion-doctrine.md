# Shared motion doctrine

Common reference for `fluid-motion`, `surface-effects`, `animation-performance`,
and `motion-review`. It does not replace `AGENTS.md` or the `animations` policy,
which decide **what** moves; this document governs **how** decided motion behaves.

## Shared principles

### Immediate response

The interface reacts in the same frame that receives input. Smooth is not slow:
a 240 ms transition feels immediate if it starts without perceptible delay.
Do not delay the start to chain decorative animations, and do not use an entrance
animation as a substitute for an already computed state.

### Short durations

Start ranges, not mandatory constants:

| Role | Starting range |
|---|---|
| Press and release | 45-120 ms |
| Hover or focus | 70-160 ms |
| Icon or control change | 100-180 ms |
| Popup or menu | 140-240 ms |
| View or surface change | 180-320 ms |

Exits are faster than entries. For frequent actions, use the low end.

### Contained elasticity

Physical animations need enough damping. Avoid long bounce, jelly, and repeated
overshoot. If a spring needs more than one visible oscillation, the damping is
wrong.

### Motion hierarchy

Priority: manipulated element, affected neighbours, container, decorative
elements. Lower-priority motion must not start earlier or last longer than the
element that caused it.

### Purpose

Every animation serves at least one function: feedback, continuity, orientation,
state change, hierarchy, or spatial relation. Purely decorative motion that also
costs rendering is reconsidered.

### Continuity

> A continuous input change must produce a continuous output change.

Continuous inputs: pointer position, pointer speed, distance between elements,
scroll offset, gesture progress. Do not convert them into binary states when
that produces discontinuous motion.

```text
cursor enters: scale = 1.5      // discontinuous
cursor leaves: scale = 1.0

preferred:     scale = f(distance(cursor, iconCenter))
```

### Control-to-result continuity

A contextual opening keeps the spatial relation between its origin control and
the revealed content. If the surface is born beside that control, opening and
closing traverse the same geometry in opposite directions and affected neighbours
yield and recover space in coordination. The origin stays recognizable after a
resize or interruption. Rest is calm and the first visible change answers input
without delay.

### Anti-overanimation

Coordinate one to three properties per microinteraction, not more. Avoid
combining `scale`, `rotation`, `x`/`y`, `opacity`, `radius`, `blur`, `shadow`,
and `color` on the same element without a clear visual reason and accepted cost.

## Classic principles translated to UI

| Principle | Interface translation |
|---|---|
| Slow in / slow out | Non-linear easing; most motion does not start or end at full speed |
| Timing | Duration proportional to distance and frequency of use |
| Spacing | Separate peers in time so they read |
| Squash and stretch | Subtle pressure deformation, e.g. `scaleX: 1.03`, `scaleY: 0.97` |
| Follow-through | Secondary elements finish later with smaller amplitude |
| Overlapping action | Related elements overlap instead of chaining rigidly |
| Arcs | Travel follows a curve when space allows |
| Anticipation | Only when it prepares an action whose effect is delayed; rare in UI |

Deformations stay subtle. Do not create caricatures.
