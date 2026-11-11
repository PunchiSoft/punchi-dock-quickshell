---
name: performance-budget
description: Set and verify a load budget for QML models, views and delegates: bound delegate creation, virtualize large collections, and measure open, scroll and search cost. Use when adding or changing a view, delegate, model or data source, or when a surface lags with many items.
license: GPL-3.0-or-later
---
# Performance budget

Load is a requirement, not a later optimization. A surface is accepted only when
its object count and interaction cost are bounded by what the viewport shows, not
by how much data the user owns. `animation-performance` owns the per-frame cost
of one effect; this skill owns how many objects exist at all and how an
interaction scales with the data.

## Procedure

1. Declare the load before writing the view. Name the expected and worst-case row
   counts, how they grow (applications, folder entries, history), and which
   interactions must stay responsive: open, scroll, type, resize.
2. Measure a baseline with a repeatable fixture, not a hand-made catalogue. Run
   the same probe at the expected and worst-case counts and record delegate
   count, wall time and memory when available. A probe that cannot state a number
   is not evidence.
3. Set the budget for the change in the note or record: maximum delegates,
   whether object count is independent of catalogue size, and the measured open
   and typing costs. Without a budget, "it feels fine" is the only criterion.
4. Choose the structural fix, in this order:
   - Virtualize with `ListView` or `GridView` and a delegate per visible row or
     cell; never place a `Repeater` over a model that can be unbounded.
   - If a grid must keep sections, make the delegate a row of cells, or use the
     view's own section support, so the count stays proportional to the viewport.
   - Defer construction with `Loader.active` or an empty model while the surface
     is closed, and keep the closing fade from repopulating it.
   - Update a `QAbstractListModel` with the narrowest `dataChanged` or insert
     range; avoid resetting the model for a selection, a query that did not
     change, or a value one role owns.
   - Cache derived data per revision (search index, sections) instead of
     recomputing per keystroke or per delegate.
   - Remove per-item animations, shaders or effects unless only the active item
     needs them; a hidden `NumberAnimation` object per cell still exists.
5. Verify with the worst-case fixture and assert a bound, not only a screenshot:
   delegate count at or below the budget, creation time, and the reopen, search
   and order-change paths. A count that grows with the catalogue fails even when
   the small fixture looks perfect.
6. Run the real session for feel and visual clipping; an offscreen probe proves
   the bound, not the rendering. Record what was measured and what was not.

## Budget defaults

- Delegates: at most one viewport plus one cache screen, plus section headers.
  A section of 500 applications must not create 500 cells.
- Object count independent of catalogue size: 82, 500 and 1000 applications keep
  the same visible delegate count; only the model length changes.
- No eager work for a closed surface. Opening creates what fits; it does not
  build the catalogue.
- `Repeater` only over a bounded, static collection whose size is known at author
  time.
- Derived JS data rebuilt once per catalogue revision or per query change, never
  per delegate binding or per frame.
- Hidden animations and effects count as objects. Prefer one animated item over
  one animation set per cell.

## Gotchas

- A hidden `ListView` still owns its delegates when the view has a size; closing a
  window does not free them. Gate the model or the view, not only `visible`.
- A JS array assigned to `model` resets the view; rebuilding it on every keystroke
  recreates every visible delegate and costs more as the listing grows.
- A `Repeater` instantiates every item immediately, even when its parent clips
  them. `GridView`/`ListView` exist to avoid exactly that.
- `positionViewAtBeginning()` and a selection reveal can fight during an open
  transition: reset the state first, then place the view, and never reveal a
  stale index.
- Continuous scrolling shows partial rows at the viewport edge by design. If the
  resting state must not cut a cell, mask the edges or snap after the gesture;
  do not mistake the expected clip for a data bug.
- A theme icon is resolved per delegate; thousands of icons cost memory even
  when the pixmap cache shares the pixels.

## Coordination

- `animation-performance`: classify the motion each delegate still performs.
- `qml-ui-creation`: where the view lives and which surface owns it.
- `architecture`: a native model belongs in `adapters/`, derived state in
  `services/`, and the view stays a view.
- `testing`: the worst-case fixture, the probe isolation and the real-session
  evidence.
- `selection-emphasis`: one band still applies when delegates are recycled.

## Validation

```bash
python3 tests/foundation_test.py
```

Measure one real change with and without the budget: report the worst-case row
count, the delegate count, the open and typing timings, and the real-session
observation. Sources for the rules live in
[references/sources.md](references/sources.md).
