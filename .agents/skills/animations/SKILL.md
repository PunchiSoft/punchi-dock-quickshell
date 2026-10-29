---
name: animations
description: Decide what moves in Punchi Dock Quickshell, classify each transition, and keep dock magnification, popup hover, press feedback and closing surfaces coherent. Use when adding or judging a transition, a hover effect, or an opening and closing surface.
license: GPL-3.0-or-later
metadata:
  source: Punchi Dock Remastered motion pack, adapted for Quickshell and KDE Plasma/KWin
---

# Motion policy

Turn state changes and interactions into brief, legible, cheap motion. Do not add
motion for its own sake: every movement must improve feedback, comprehension,
spatial orientation, continuity, or perceived responsiveness.

## Coordination

- `fluid-motion` chooses the Qt Quick mechanism and keeps reversal continuous.
- `motion-review` audits existing motion without changing code.
- `animation-performance` checks per-frame cost and theme durations.
- `motion-design` coordinates a change that mixes input policy and motion.
- `surface-effects` decides material, blur, and shader levels.
- `accessibility` covers focus, keyboard, and reduced motion.
- `qml-ui-creation` and `quickshell-development` cover the component itself.

## Diagnose before proposing

Identify the element, trigger (hover, focus, press, selection, model update,
popup open/close, drag, loading, error), initial and final state, UX goal,
frequency of use, panel orientation and available size, expected cost, and the
reduced-motion alternative.

Classify the animation:

- `necessary`: communicates a transition that would otherwise be confusing.
- `useful`: improves feedback or continuity without being essential.
- `decorative`: adds no clarity; do not add it unless explicitly requested.
- `harmful`: delays, distracts, breaks accessibility, or costs without benefit.

## Rules

- The dock is a frequently used tool, not a permanent scene: prefer short
  microinteractions. Exits are slightly faster than entries.
- No default bounce, elasticity, or continuous loops.
- Do not scale text when it can lose sharpness or legibility.
- Do not animate properties that force relayout when a transform reads the same.
- Interruption is mandatory: fast hover, press, or model changes must never leave
  an inconsistent visual state. Final states always belong to the current target.
- Do not block an action until an animation finishes.
- Keep one source of truth per coordinated transition.

### Contextual expansion

When a launcher, button, or action opens a nearby menu or selector, treat control
and result as one interaction: the surface is revealed from the activation point
and affected neighbours yield space legibly; closing returns space and focus to
the origin. See [the shared doctrine](../references/motion-doctrine.md).

- Rest is visually calm; the first visible change answers input without delay.
- Shape, position, clipping, and appearance of one expansion move together and
  can be reversed from any point.
- A brief pressure deformation belongs to chosen controls, not every surface.
- Do not lose focus, available action, or spatial relation when the panel
  resizes or reduced motion is active.

### Popup hover

Popup rows share [PunchiPopupRowHighlight](../../../components/PunchiPopupRowHighlight.qml).
It owns hover, selection, focus, press, the fill fade, and the single hover pulse.
Rows scale their content with `visualScale`; they never re-implement the profile.

- The pulse is a one-shot response to pointer entry: 3% rise in 95 ms and a
  125 ms return, matching Punchi Menu's reference hover. Leaving mid-pulse
  settles to 1.
- Press lives in the same surface (0.97, `veryShortDuration`), so an interrupted
  gesture still ends at rest.
- Hover and keyboard focus stay distinct: focus paints a ring, not another fill.
- Reduced motion reaches the same fill and press states without scaling.

## Durations

Prefer theme durations: `Kirigami.Units.veryShortDuration`, `shortDuration`,
`longDuration`, `veryLongDuration`. Scale them multiplicatively for a role; do
not clamp them with a fixed floor such as `Math.max(80, ...)`, which overrides
the user's animation-speed preference. Custom values need a documented reason
next to the code; the popup pulse keeps 95/125 ms for parity with Punchi Menu.

## Easing

- `OutQuad`/`OutCubic`: appearing, arriving, responding to an action.
- `InQuad`/`InCubic`: leaving or losing presence.
- `InOutQuad`/`InOutCubic`: transitions between equivalent states.
- `OutBack`/`OutElastic`/`OutBounce`: only with functional justification and
  small amplitude.
- `Linear`: only for continuous values such as progress, drag, or pointer
  tracking, never for state transitions.

## Reduced motion

- Use one criterion per component and document it. Prefer the component's
  `motionEnabled`/`settings.effectiveReducedMotion` over local duration checks.
- Remove wide travel and decorative pulses; keep essential feedback.
- Always reach the same final state, including focus and press.
- Do not rely on motion as the only state indicator.

## Performance

Check concurrent animations, animated delegates, relayout, binding loops,
permanent timers, blur, shadows, shaders, and offscreen layers. Measure before
adding effects; a low-cost transform repeated per delegate stops being low cost.
Never claim fluency from an offscreen test.

## Validation

1. `qmllint` for the changed files.
2. Slow and fast pointer travel over the element and its neighbours.
3. Interruption in both directions at mid-animation.
4. Final state after repeated interruptions.
5. Reduced motion: same functional state, no decorative scaling.
6. Horizontal and vertical panel, real size and scale.
7. For popups, delegates, or `shell.qml`, run the applicable runtime check.

Report what changed, why the motion adds clarity or feedback, what was executed,
and what still needs a real KDE session.
