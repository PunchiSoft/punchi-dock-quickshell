---
name: motion-review
description: Audit existing Punchi Dock Quickshell motion without changing code, locate animations and effects, classify each finding with the MOTION catalog, and report file, line, component, symptom, cause, class, recommendation, risk, cost, and priority.
---

# Motion audit

Produce a verifiable, prioritized report about existing motion without touching
code. This skill does not edit QML, adjust durations, or add animations.

## Coordination

- `fluid-motion` recommends the concrete mechanism.
- `surface-effects` covers the technical level of a visual effect.
- `animation-performance` covers cost and theme durations.
- `animations` covers the project policy on what should move.
- `accessibility` when a finding affects focus, keyboard, or reduced motion.
- `visual-review` when the problem is perceptible but not measurable in code.

## Procedure

1. Define scope: component, surface, or flow to audit.
2. Inventory animations and effects with exact locations:

   ```bash
   grep -rn "Behavior on\|Animation {\|Animator {\|Transition {\|ShaderEffect" modules/ components/
   ```

3. Inventory durations and their origin: custom value, theme duration, fixed
   floor, or configuration factor.
4. For contextual openings, identify origin control, revealed surface, and
   displaced neighbours. Check whether they share progress, whether spatial
   relation survives inversion, and whether focus follows visible content.
5. Check the reduced-motion criterion used by each component.
6. Classify each finding with [the finding catalog](references/finding-catalog.md).
7. Assign risk, cost, and priority with explicit criteria.
8. Deliver the report in the mandatory format, ordered by priority.
9. State what could not be verified without a real KDE/KWin session.

## Mandatory finding format

```text
FILE

LINE / APPROXIMATION

COMPONENT

CURRENT ANIMATION

SYMPTOM

CAUSE

CLASSIFICATION

RECOMMENDATION

RISK

COST

PRIORITY
```

## Classification criteria

**Risk** — what can break: low (isolated visual change), medium (interaction,
focus, shared state), high (behaviour, load, accessibility).

**Cost** — added or removed rendering work: low (transforms and opacity on
existing elements), medium (offscreen layer, small blur, several coordinated
properties), high (large surfaces, per-delegate effects, relayout, per-frame
work).

**Priority** — high when continuity, reversibility, accessibility, or per-frame
work is broken; medium when perception degrades; low for consistency or
maintenance.

## Do not

- Propose a rewrite without an inventory.
- Recommend architecture changes for a single finding.
- Call an aesthetic preference a finding without observable impact.
- Claim an animation is fluid or slow without having observed it.
- Include a finding without an exact location.

## Expected output

- Scope and reviewed files.
- Findings table with identifier, location, classification, and priority.
- Each finding body in the mandatory format.
- Checks that require a real KDE session.
- Uncovered risks and audit limits.
