# Motion finding catalog

Categories recognized by `motion-review`, with the symptom, usual cause, and
recommendation line to justify each one.

### MOTION-01 - Instant property change
- Symptom: the value jumps between states without a perceptible transition.
- Cause: direct assignment where a visible state change existed.
- Recommendation: `Behavior` or `Transition` with a theme duration when the
  change carries information.

### MOTION-02 - Inadequate easing
- Symptom: motion feels rigid, mechanical, or too elastic.
- Cause: `Easing.Linear` in state transitions, or `OutBack`/`OutElastic` as a
  default.
- Recommendation: `Out*` on entry, `In*` on exit, `InOut*` between equivalent
  states; elastic only with justification.

### MOTION-03 - Animation restarts from zero
- Symptom: changing the target mid-animation returns to the start or jumps.
- Cause: `stop()` then `start()`, a recreated animation, or `from` pinned to the
  initial value.
- Recommendation: let the binding retarget the same animation, or evaluate
  `SmoothedAnimation`.

### MOTION-04 - Discrete hover where continuity belongs
- Symptom: the cursor crosses several elements and each one changes abruptly.
- Cause: per-element `hovered ? x : y` on continuous input.
- Recommendation: a continuous function of pointer distance with radius and
  normalization; see `../../fluid-motion/references/dock-magnification.md`.

### MOTION-05 - Excessive bounce
- Symptom: visible oscillation after arrival, or a jelly feel.
- Cause: underdamped spring or `OutElastic`/`OutBounce`.
- Recommendation: add damping or return to `NumberAnimation` with ease-out.

### MOTION-06 - Related animations out of sync
- Symptom: border, text, and background of one element finish at different times
  without intent.
- Cause: independent animations triggered by one event with different durations
  and delays.
- Recommendation: coordinate with `ParallelAnimation` or one state.

### MOTION-07 - Relayout during animation
- Symptom: the animation recalculates sibling positions and loses fluency.
- Cause: animating `width`, `height`, `Layout.*`, margins, or text sizes.
- Recommendation: transform or clip; keep layout stable.

### MOTION-08 - Unnecessary JavaScript animation
- Symptom: irregular motion that depends on system load.
- Cause: per-frame loops or calculations replicating the animation system.
- Recommendation: declarative Qt Quick animations.

### MOTION-09 - Expensive GPU effect
- Symptom: fluency drops with blur, shadows, masks, or offscreen layers.
- Cause: large surface, many instances, or animated effect properties.
- Recommendation: reduce surface, reuse the effect, or drop a level; see
  `../../surface-effects/SKILL.md`.

### MOTION-10 - Unnecessary shader
- Symptom: high cost for a finish another level achieves.
- Cause: `ShaderEffect` for something transforms, opacity, or `MultiEffect`
  already solve.
- Recommendation: simplify to level 1 or 2 while keeping the visual result.

### MOTION-11 - Animation that cannot invert correctly
- Symptom: fast enter/leave leaves the element mid-way, flickering, or in the
  wrong visual state.
- Cause: the animation must finish before inverting, or restarts.
- Recommendation: invert from the current state without stopping or restarting.

### MOTION-12 - Fixed duration that ignores the desktop setting
- Symptom: the animation keeps the same timing when the user changes global
  animation speed.
- Cause: a custom constant instead of a theme duration.
- Recommendation: use `Kirigami.Units.*` or a multiplicative factor.

### MOTION-13 - Invisible element still animating
- Symptom: persistent consumption with nothing visible to justify it.
- Cause: animation active while `visible: false`, `opacity: 0`, or off-screen.
- Recommendation: stop it when the element is not visible.

### MOTION-14 - Multiple redundant effects
- Symptom: high cost without perceptible improvement.
- Cause: stacked blurs, drawn shadow plus theme shadow, several effects on one
  surface.
- Recommendation: keep one effect per visual goal.

### MOTION-15 - Motion without purpose
- Symptom: the interface feels restless and communicates nothing new.
- Cause: decorative, permanent, or repeated animation without a state change.
- Recommendation: remove it or replace it with direct feedback.

### MOTION-16 - Inconsistent or ineffective reduced-motion criterion
- Symptom: with reduced motion, some animations stop and others do not; or none
  stop although the preference is active.
- Cause: mixed criteria (`> 0`, `=== 0`, `> 1`) and criteria that can never be
  false.
- Recommendation: one criterion per component, verifiable in the real
  environment.

### MOTION-17 - Fixed floor overriding the theme duration
- Symptom: the animation stays equally slow with global animation speed at its
  minimum.
- Cause: `Math.max(<fixed value>, Kirigami.Units.<duration>)`.
- Recommendation: scale the theme duration; justify any minimum and verify it
  does not override the preference.

### MOTION-18 - Duration 0 in an animator that may not fire
- Symptom: the property stays at its initial or intermediate value at minimum
  animation speed.
- Cause: a theme-derived duration that can reach 0; zero-duration animators are
  not reliable.
- Recommendation: set the final value explicitly and apply a 1 ms minimum.

### MOTION-19 - Control-to-content relation lost
- Symptom: a section or menu appears far from its control, neighbours move at a
  different rhythm, or closing leaves focus on hidden content.
- Cause: geometry independent from the origin, several animations without shared
  progress, or visual state separated from interaction state.
- Recommendation: preserve spatial origin, coordinate one expansion, and
  synchronize focus and reachability with visible content. Do not apply this to
  surfaces whose independent presentation is deliberate.

## Suggested priority

| Classification | Default priority |
|---|---|
| MOTION-08, MOTION-11, MOTION-16, MOTION-18 | High |
| MOTION-03, MOTION-04, MOTION-07, MOTION-09, MOTION-17, MOTION-19 | High or medium per component |
| MOTION-01, MOTION-02, MOTION-05, MOTION-06, MOTION-12, MOTION-13 | Medium |
| MOTION-10, MOTION-14, MOTION-15 | Medium or low per impact |

Final priority depends on how often the component is used: a daily element weighs
more than an exceptional one.

## Audit limits

- Without a real KDE session, fluency and perceived latency cannot be claimed.
- GPU measurement is not part of this skill; escalate to a dedicated performance
  diagnosis if needed.
- A finding without an exact location is not included.
