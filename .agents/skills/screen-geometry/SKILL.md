---
name: screen-geometry
description: Calculate available logical space, reference scale, grid rows and KDE units before a QML layout is written. Use when a surface clips at some resolution, a grid must adapt, or spacing, DPR or availableGeometry is in doubt.
license: GPL-3.0-or-later
metadata:
  source: Owner-provided KDE screen geometry model, verified against Qt, KDE and Quickshell documentation
---

# Screen geometry

Turn measured logical space into rectangles that fit. This skill owns the math;
`qml-ui-creation` owns the surface, `accessibility` owns focus, and
`performance-budget` owns delegate cost. Use rectangles, proportions and
constraints, not integral calculus.

## Procedure

1. Classify the surface: fullscreen grid, panel, popup, dock, or a control inside
   one. Name the rectangle the layout may occupy, not the whole screen.
2. Measure the content rect in logical pixels after layout: the owning `Item`'s
   `width` and `height`. Start from `Quickshell.screens`/`ShellScreen` only to
   choose the monitor. Subtract each explicit reservation once: side margins,
   header, dock, scrollbar gutter, layer-shell exclusive zone.
3. Record the reference design next to the code: `W0 × H0`, columns, rows, cell
   width and height, icon size, label size and gaps. Cite the screenshot or
   design that produced it. The macOS Launchpad capture at 1440×900 is the
   current menu reference.
4. Compute a proportional scale and whole counts. Prefer
   `S = min(W / W0, H / H0)` so the design never overflows either axis. Derive
   columns and rows with `floor`; keep a minimum and maximum from the product
   constraints. Compute the used rectangle and centre the remainder.
5. Apply constraints before painting: minimum icon, label and touch target;
   maximum columns and rows; Kirigami spacing; whole rows; no partial tile at
   rest. If a square card is required, make the card square inside a
   rectangular cell; do not force the cell to be square.
6. Express the result in QML. Use `Kirigami.Units` for spacing, icons, radii and
   durations; theme fonts and `FontMetrics` for text. Keep reference constants
   in `config/`, composition and measured rectangles in `modules/`, and monitor
   queries in the window or screen-policy owner.
7. Validate at the reference size and at the extremes: no clipped row or
   column, whole rows, icon at or above the approved size, label visible or
   intentionally withheld, and no overlap. Capture the real session and record
   DPR and scale.
8. Record the reference, formulas, tested resolutions and unvalidated cases in
   the change record. A passing headless layout test is not a visual or
   compositor guarantee.

## Formulas

- Rectangle: `R = (x, y, w, h)`; area `A = w × h`.
- Useful area: `A_util = A_screen − A_reserved`. For layout, use `W` and `H`
  separately; area alone cannot prove that a shape fits.
- Reference scale: `S = min(W / W0, H / H0)`. `max` overflows the smaller axis;
  do not stretch a reference to fill both axes when that changes its shape.
- Counts: `columns = clamp(minCols, maxCols, floor((W + gap) / (cellW + gap)))`;
  the same for rows with `H`, `cellH` and `gap`.
- Cell size: `cellW = (W − gap × (columns − 1)) / columns`; used width is
  `columns × cellW + gap × (columns − 1)`; the offset is
  `(W − usedW) / 2`. Repeat vertically.
- Square card in a rectangular cell:
  `side = min(cellW, cellH)`, card offset `(cellW − side) / 2`; the card content
  width is `side − inset`.
- No clipping at rest: `usedH <= H`, and either the viewport height equals
  `usedH`, or the next row starts at or after the viewport edge. A centred grid
  with leftover space is not clipping; a viewport that cuts a tile is.
- DPR: `physical = logical × DPR`. Apply DPR only to raster, image and OpenGL
  work, never again to QML layout values.
- Overlap: `R1 ∩ R2 ≠ ∅` means collision. Expand each rect by its required
  separation before testing when the design needs a gutter.

## Kirigami Units: where to apply

| Need | Use | Note |
|---|---|---|
| Spacing between small related items | `smallSpacing` | HIG default for tightly related controls |
| Spacing between groups and page edges | `largeSpacing` | HIG grouping rule |
| Toolbar spacing | `mediumSpacing` | between buttons and fields |
| Fixed sizes | multiples of `gridUnit` | read the value; it is 18 px in the current session, not a constant |
| Icons | `iconSizes.small`, `smallMedium`, `medium`, `large`, `huge`, `enormous`, `sizeForLabels` | normalised for DPI |
| Rounded corners | `cornerRadius` | available since Kirigami 6.2 |
| Durations | `shortDuration`, `mediumDuration`, `longDuration`, `veryLongDuration` | follow the user's animation setting |
| Text | `Kirigami.Theme.defaultFont`, `smallFont`, `FontMetrics` | do not hardcode a point size without an approved reference |
| Screen/window geometry | measured `Item` size; `ShellScreen.width`/`height` | logical units; verify against the measured surface |
| Raster or GL work | `devicePixelRatio` | not a layout multiplier |

Ownership:

- `config/`: reference constants and shared metrics, with their source.
- `modules/`: measured rectangles, counts, offsets and composition.
- `components/`: Kirigami Units and theme values; no monitor queries.
- `services/` and `adapters/kde/`: data and desktop behaviour; no visual layout.
- `shell.qml`: composition only.

## QML rules

- Use logical pixels from measured Items. `Screen`/`ShellScreen` size is a
  starting point, not the content rect.
- Use `Math.floor` for whole cells and rows, `Math.round` for pixel sizes, and
  guard `0`/`NaN` before any icon raster request.
- Size the viewport to the used grid or clip it at a row boundary. Never leave a
  partial tile visible when the surface is at rest.
- A square hover/selection card does not require square grid cells. The current
  menu reference uses 7×5 rectangular cells and a square highlight.
- Keep the approved icon size. If the cell cannot contain the icon plus label,
  reduce columns or rows, or withhold the label; shrinking the glyph is the last
  resort and needs the owner's approval.
- Use Qt Quick Layouts for resizable groups. The layout owns child geometry;
  don't bind a child's `width` or `height` while it is in a layout. Only a
  top-level layout may use `anchors.fill: parent`.
- Avoid binding loops: compute metrics from measured width/height and constants,
  not from the item the metric sizes.

## Gotchas

- Do not multiply QML geometry by `devicePixelRatio`; Qt already supplies
  device-independent pixels. Wayland scale is an integer; fractional scaling can
  differ between the window and the screen.
- `QScreen::availableGeometry` excludes window-manager reservations, but on X11
  it may equal the full geometry and on Wayland/layer-shell reservations are not
  guaranteed. Quickshell `ShellScreen` exposes `width`, `height`,
  `devicePixelRatio` and `logicalPixelDensity`, not `availableGeometry`.
  Prefer the measured surface plus explicit margins.
- Qt's `Screen` attached properties are not valid at `Component.onCompleted`;
  the item has not been displayed on a screen yet. Use the Quickshell screen
  object passed to the window or read after completion.
- `S = min(...)` preserves aspect; `max(...)` overflows. A reference grid that
  fills one axis may leave a centred margin on the other; that is correct.
- A square cell at 7 columns on 1440×900 fits only three rows. The macOS
  reference uses rectangular cells and a square highlight; don't force square
  cells to satisfy a "square card" request.
- Hardcoded reference values belong in `config/` with a source and a test, not
  in a view.
- A centred grid with spare space is not a bug; a clipped row is.

## Validation

- `python3 tests/foundation_test.py` for the skill structure and catalog.
- Geometry tests at the reference size and extremes: assert `used <= available`,
  whole rows, no partial tile, icon at or above reference, and label visibility
  matches the constraint.
- Real session: capture at the actual resolution and inspect the first and last
  row and column. Record DPR, scale, Qt/Kirigami/Quickshell versions.
- Trigger evals: use the queries in `tests/skills-trigger-evals.md`; record the
  rate and the description that changed.
- API evidence: [references/api-evidence.md](references/api-evidence.md).

## Coordination

- `qml-ui-creation`: surface composition and native controls.
- `accessibility`: focus order, names, scaling and reduced motion.
- `performance-budget`: delegate count, cache and worst-case load.
- `qt-kde-reference`: version and API evidence; this skill records the geometry
  decision and its tested resolutions.
