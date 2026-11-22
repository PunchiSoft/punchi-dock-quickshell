# Curve catalogue

The shared UI curves for Punchi Dock Quickshell. They live in
[`config/PunchiMotion.js`](../../../../config/PunchiMotion.js) and every opt-in
surface binds them instead of writing a bezier array in place.

## Why a strong ease-out

Qt's `Easing.OutCubic` is a valid curve, but it covers about 78% of its travel at
40% of the duration and then spends a long tail arriving. The strong ease-out
covers about 92% at the same point and settles the remainder: the surface answers
input immediately and lands softly instead of marching. The difference is
perceptual, not a longer duration.

| Curve | 20% | 40% | 60% | 80% |
|---|---|---|---|---|
| `OutCubic` | 48.8% | 78.4% | 93.6% | 99.2% |
| `enter` (0.23, 1, 0.32, 1) | 68.2% | 92.5% | 98.6% | 99.9% |
| `drawer` (0.32, 0.72, 0, 1) | 65.6% | 91.8% | 97.6% | 99.5% |
| `exit` (0.215, 0.61, 0.355, 1) | 50.8% | 79.5% | 92.9% | 98.5% |
| `ease` (0.25, 0.1, 0.25, 1) | 29.5% | 68.3% | 88.5% | 97.6% |
| `InCubic` | 0.8% | 6.4% | 21.6% | 51.2% |

## Tokens

| Token | CSS cubic-bezier | Use |
|---|---|---|
| `enter` | `0.23, 1, 0.32, 1` | opening, arriving, responding to input |
| `exit` | `0.215, 0.61, 0.355, 1` | leaving and losing presence; a moderate ease-out |
| `move` | `0.77, 0, 0.175, 1` | on-screen movement between equivalent states |
| `drawer` | `0.32, 0.72, 0, 1` | a surface that slides in and out |
| `ease` | `0.25, 0.1, 0.25, 1` | hover fills and colour changes |

```qml
import "../../config/PunchiMotion.js" as PunchiMotion

NumberAnimation {
    duration: Kirigami.Units.shortDuration
    easing.type: Easing.BezierSpline
    easing.bezierCurve: root.open ? PunchiMotion.enter : PunchiMotion.exit
}
```

Qt encodes one CSS `cubic-bezier()` as six numbers:
`[control1.x, control1.y, control2.x, control2.y, 1, 1]`. The four-value CSS
form is rejected or ignored. `Easing.BezierSpline` is available in the project's
supported Qt 6.8 minimum; the installed environment is Qt 6.11.2.

## Choosing a curve

- Entering or exiting: `enter`, or the shorter `exit`. Both are ease-out. An
  ease-in on a short close starts nearly stationary and then snaps; the
  auto-hide used to do that and now uses `drawer`.
- On-screen movement or morphing: `move`.
- Hover and colour: `ease`; a strong ease-out on a large translucent band is too
  abrupt.
- Constant motion (marquee, progress): `Linear` only with a functional reason.
- Spring: only for drag, momentum or a gesture the user can reverse. Do not turn
  a click bounce into a spring just for the look.

## Paired elements

Elements that move as one unit share one curve and one duration. The fullscreen
menu content and its backdrop both open on `enter` with `longDuration` and leave
on `exit` with `shortDuration`; a backdrop left on a different duration trails
behind the surface it belongs to. The same rule applies to a popup and its tail,
and to a container and its Fan arc.

**Open decision:** the menu's row snap still uses a fixed `longDuration` instead
of a duration proportional to the travel. That is a separate change: the existing
`tst_menu_sections` assertion and a real-wheel check both need to move with it.

## Frequency and cost

- Seen 100+ times a day: do not animate it. Tens of times a day: at most a
  near-imperceptible response. Modals and first-run surfaces carry the visible
  motion.
- Prefer transform and opacity. Colour, radius and border are acceptable on a
  small surface; never animate width, height, margins or `Layout.*`.
- The dock already keeps the 95/125 ms hover pulse as its reference profile;
  that is a deliberate exception for a frequently seen control, not a default for
  new surfaces.

## Reduced motion

The project keeps its own criterion: remove displacement and decorative scale,
keep essential feedback and always reach the same final state. This is
intentionally gentler than the web rule that disables every animation; do not
replace the project's `motionEnabled`/`effectiveReducedMotion` path with a blanket
`animation: none` equivalent.

## Rules

- One token per role, never a per-animation literal. A new curve needs a record
  entry, a reason and the same six-number contract.
- Durations remain the Kirigami theme values. A curve token does not justify a
  custom duration.
- The hover pulse keeps its reference 95/125 ms timing; only its curves come from
  the tokens.
- Reduced motion still applies the final value without animation; the curve is
  never the only state indicator.
- `tests/qml/tst_motion_tokens.qml` guards the array shape, the `1, 1` end point
  and that a real `NumberAnimation` accepts the token.

## Migration state (2026-11-22)

The fullscreen menu, the popup family and the auto-hide slide bind these tokens.
The dock wave, the two-hop bounce, the minimize reaction, the update badge and
the Trash confirmation still use their reference profiles. Do not migrate those
without the owner's real-session visual approval and a new phase record; the
private change record `change-2026-11-22-motion-curves.md` holds the phase plan,
the open decisions and the resume steps for the local checkout.

## Source and attribution

The curve values and the strong ease-out timing guidance are adapted from Emil
Kowalski's skills: <https://github.com/emilkowalski/skills>, MIT License,
Copyright (c) 2026 Emil Kowalski. The sorted curve families, the paired-element
rule, the frequency gate and the spring guidance were checked against the Vercel
open-agents web-animation-design skill:
<https://github.com/vercel-labs/open-agents>, MIT License, Copyright (c) 2026
Vercel, Inc. The project implements the principles for Qt Quick; no web code or
animation library is copied. Qt documents the easing value type at
<https://doc.qt.io/qt-6/qml-easingcurve.html>.
