// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Shared UI curves for the surfaces that opt into the strong ease-out profile.
// A CSS cubic-bezier() becomes six numbers for Qt Quick:
// [control1.x, control1.y, control2.x, control2.y, end.x, end.y], with the end
// point fixed at 1,1. Bind them with `easing.type: Easing.BezierSpline`.
//
// The values follow Emil Kowalski's animation guidance
// (https://github.com/emilkowalski/skills, MIT License, Copyright (c) 2026 Emil
// Kowalski) and the sorted curve families in the Vercel open-agents
// web-animation-design skill (MIT License, Copyright (c) 2026 Vercel, Inc.).
// The project adopts the curve character, not the web implementation: these
// animate Qt Quick properties, and no JavaScript animation loop is added.
//
// Keep the curves here. A literal bezier array inside an animation forks the
// profile and drifts from the rest of the shell.

// cubic-bezier(0.23, 1, 0.32, 1): appearing, arriving, responding to input.
const enter = [0.23, 1, 0.32, 1, 1, 1]
// cubic-bezier(0.215, 0.61, 0.355, 1): leaving on the shorter close duration.
// It is a moderate ease-out, not an ease-in: a slow start makes a short close
// linger and then snap.
const exit = [0.215, 0.61, 0.355, 1, 1, 1]
// cubic-bezier(0.77, 0, 0.175, 1): on-screen movement between equivalent states.
const move = [0.77, 0, 0.175, 1, 1, 1]
// cubic-bezier(0.32, 0.72, 0, 1): drawer-like travel; leaves at once, lands softly.
const drawer = [0.32, 0.72, 0, 1, 1, 1]
// cubic-bezier(0.25, 0.1, 0.25, 1): hover fills and colour changes. The gentle
// asymmetry reads better than a strong ease-out on a large translucent band.
const ease = [0.25, 0.1, 0.25, 1, 1, 1]
