# Cost classification and duration contract

Operational detail for `animation-performance`.

## Cost matrix

| Class | Implies | Examples |
|---|---|---|
| LOW | Only transform or composition on existing elements; no relayout, no new layers | `scale` of an icon, `opacity` of a card, `x`/`y` of a small surface |
| MEDIUM | Offscreen layer, small blur, few instances, or several coordinated properties | popup with scale and opacity; menu blur; highlight with border and scale |
| HIGH | Large surface with blur, shadow, or mask; per-delegate effect; animated relayout; per-element shader; per-frame JavaScript | blur over the whole dock; animated shadow per icon; animated `Layout.preferredWidth` |

Decision rule: every MEDIUM or HIGH animation explains why it cannot be LOW. If
there is no explanation, it is not approved.

## Simultaneous dock consumers

Cost is not judged in isolation. The dock may run several instances, many
delegates, a frequently updated window model, previews, blur and shadows, popups,
polling, and hover, magnification, opening, and closing animations at once.

## Operational prohibitions

| Practice | Why it is prohibited |
|---|---|
| `Timer` as animation engine | Not frame-synchronized; variable work and jumps |
| JavaScript loop per frame | Blocks the UI thread and bypasses the animation system |
| Recreating delegates during animation | Destroys objects and state; produces jumps |
| Rebuilding models per frame | Disproportionate notification and binding cost |
| Alternating `Loader` for an effect | Reloads components where a state sufficed |
| Animating `Layout.*` or `width`/`height` | Cascading relayout |
| Stacked blurs | Duplicate cost without a distinct finish |
| Effect or shader per delegate | Multiplies work by visible element count |

## Theme durations

`Kirigami.Units` exposes `veryShortDuration`, `shortDuration`, `longDuration`, and
`veryLongDuration`. Their values depend on the active Kirigami style and platform
plugin: the Plasma style derives them from the desktop animation-speed setting,
while a generic platform may not apply it.

Consequences:

1. multiply the theme duration to fit a role; never replace it with a constant;
2. do not apply `Math.max(...)` with a fixed value over a theme duration;
3. if a duration can be 0, move the property to its final value explicitly
   instead of relying on the animator;
4. do not assume the user preference is applied without verifying it in the
   target environment;
5. verify on the distributions you support before basing reduced motion on a
   duration value.

## Reduced-motion criterion

- Use one criterion per component and document it.
- Prefer an explicit component or settings property (`motionEnabled`,
  `effectiveReducedMotion`) over local duration checks.
- Verify that the criterion actually changes with the user preference; a
  criterion that is never false disables the protection silently.

## How to check

1. Dock full of icons and several dock instances.
2. Fast pointer movement during the animation.
3. Real concurrent animations, not one isolated.
4. Maximum model size.
5. Reduced motion enabled.
6. Record expected cost and what could not be measured.

Lint, tests, and successful loading do not prove fluency: observation in a real
KDE session is required.
