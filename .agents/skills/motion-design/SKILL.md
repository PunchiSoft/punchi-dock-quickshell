---
name: motion-design
description: Resolve interaction policy and animation as one system, covering repeated navigation, input bursts, retargeting, hover competing with selection, and interruptible transitions. Use when input behavior and motion must be fixed together, not for an isolated visual animation.
license: GPL-3.0-or-later
metadata:
  source: Punchi Dock Remastered motion pack, adapted for Quickshell and KDE Plasma/KWin
---

# Coordinated UX and motion design

Resolve interactive behaviour and its animated representation as one system. Do
not let an animation hide a defective input policy, and do not let an input fix
produce a slow, blocked, or inaccessible interface.

## Coordination

Activate only the specialized skills that apply: `review-cycle` to reconstruct a
reported flow, `animations` for policy and duration, `fluid-motion` for the
mechanism, `accessibility` for keyboard, focus, screen readers, or reduced
motion, `qml-ui-creation` for QML changes, `animation-performance` for many
delegates or concurrent motion, and `surface-effects` for material decisions.

Do not duplicate their detailed rules here.

## Procedure

1. Recover repository context and preserve existing modifications.
2. Identify component, trigger event, initial state, final state, and expected
   result.
3. Inventory every source that can change the same state: mouse, wheel,
   touchpad, keyboard, auto-repeat, hover, timers, gestures, bindings, model, and
   external signals. For inline content, also identify origin control, yielding
   neighbours, and focus on open and close; check that displaced controls outside
   the visible area are still keyboard and accessible.
4. Separate interaction policy from visual transition: policy decides which
   intent is accepted, grouped, or discarded; the transition decides how the
   accepted change is represented.
5. Determine whether the symptom is input accumulation, double dispatch,
   retargeting, unwanted wrap, hover competing with selection, excessive
   duration, or render work.
6. Propose the minimal change with explicit behaviour for mouse, keyboard,
   wheel/touchpad, and reduced motion.
7. If only a diagnosis was requested, stop after presenting evidence, probable
   cause, alternatives, and a test that distinguishes them.
8. If implementation is authorized, follow `AGENTS.md` and the validation of the
   activated skills.

## Repeated navigation and carousels

- Check whether every event changes the index immediately while the previous
  transition is still active.
- Check whether a new selection retargets toward an ever more distant target and
  increases apparent speed.
- Treat repeated click, held key, wheel, and touchpad coherently.
- Distinguish a real click from auto-repeat or two handlers processing one
  gesture.
- Prevent hover from selecting elements that scroll under a stationary pointer
  during navigation started elsewhere.
- Decide explicitly whether the carousel wraps.
- Prefer coalescing, brief throttling, or controlled advance over blocking input
  for the whole animation.
- Avoid long queues of steps that keep moving after the person stopped.
- Keep response immediate and the final position predictable.

## Decision criteria

- `brief throttle`: buttons and wheel when speed matters but accidental bursts
  must not be accepted.
- `coalescing`: several quick inputs express one latest target.
- `bounded queue`: every step matters, but pending motion is limited.
- `interruption and retargeting`: deliberate continuous tracking with predictable
  speed and destination.

Never choose a duration or timer without explaining which input behaviour it
protects. Do not use the end of an animation as the only unlock if that makes the
control artificially slow.

## Validation

1. One click or press produces exactly one step.
2. A short burst ends at a predictable position.
3. Holding a key does not accelerate uncontrolled.
4. Wheel and touchpad do not jump from accumulated deltas.
5. Moving or resting the pointer does not change selection accidentally.
6. Extremes respect the defined wrap policy.
7. Closing, changing view, or reducing motion cancels pending state.
8. Focus, accessible semantics, and keyboard activation still work.
9. A contextual opening keeps content near its control through inversion and
   resize.
10. `qmllint` and the applicable runtime load review report no regressions.

Always separate static review, automated test, and manual validation in a real
KDE session. Do not claim the motion feel was fixed without visual evidence or
user confirmation.
