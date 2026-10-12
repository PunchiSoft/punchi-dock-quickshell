---
name: animations
description: Design and implement continuous dock magnification and interruptible QML transitions while checking reduced motion and per-frame cost.
---

# Dock motion

Identify the trigger, current and target states, spatial relationship, and motion
preference. Keep a single source of truth for each coordinated transition.

- Wave scale is a bounded continuous function of pointer-to-center distance.
  Use one coordinate space and invalidate geometry when layout changes.
- Keep layout centers stable and allocate visual room for enlarged icons.
- Prefer direct transforms for continuous tracking; evaluate `SmoothedAnimation`
  for retargeting and `NumberAnimation` for discrete state transitions.
- Do not restart an easing curve on every pointer update or use timers/FFI
  callbacks as animation engines. Avoid per-frame object allocation and I/O.
- Reduced motion reaches the same functional state without the decorative wave.
- Finish closing before hiding a surface; interruption must not leave it stuck.

Check slow and fast pointer travel, leave/re-enter, reversal, resize, clipping,
focus, and reduced motion. Measure before adding blur, layers, or heavy effects;
do not label unmeasured motion as performant.
