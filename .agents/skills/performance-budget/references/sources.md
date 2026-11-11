# Sources for the performance budget

Verified on 2026-11-11. Prefer the installed Qt/KDE version when a page moves.

## Qt 6

- **Frame budget**: <https://doc.qt.io/qt-6/qtquick-performance.html#timing-considerations>
  "60 FPS means that there is approximately 16 milliseconds between each frame"
  and blocking work must stay within a couple of milliseconds. The same page
  requires profiling before optimizing and keeping bindings simple
  (`#property-bindings`).
- **ListView loads delegates on demand**:
  <https://doc.qt.io/qt-6/qml-qtquick-listview.html#details>
  "ListView will only load as many delegate items as needed to fill up the view.
  Items outside of the view will not be loaded unless a sufficient cacheBuffer
  has been set."
- **cacheBuffer is extra delegates, created asynchronously**:
  <https://doc.qt.io/qt-6/qml-qtquick-listview.html#cacheBuffer-prop>
  It "only maintains additional instantiated delegates" and is not a replacement
  for efficient delegates.
- **Delegate cost and reuse**:
  <https://doc.qt.io/qt-6/qml-qtquick-listview.html#delegate-prop>
  "The number of objects and bindings in the delegate has a direct effect on the
  flicking performance"; move optional work into a `Loader`; use whole-number
  sizes. Reuse requires a stable model:
  <https://doc.qt.io/qt-6/qml-qtquick-listview.html#reusing-items>.
- **Repeater creates every item immediately**:
  <https://doc.qt.io/qt-6/qml-qtquick-repeater.html#considerations-when-using-repeater>
  "The Repeater type creates all of its delegate items when the repeater is first
  created. This can be inefficient if there are a large number of delegate items
  and not all of the items are required to be visible at the same time."
- **Loader gating**:
  <https://doc.qt.io/qt-6/qml-qtquick-loader.html#active-prop>
  Inactive releases the loaded item; asynchronous loading spreads creation over
  frames.
- **Granular model changes**:
  <https://doc.qt.io/qt-6/qabstractitemmodel.html#dataChanged>
  The roles argument names what changed; `beginResetModel()` resets every
  attached view (`#beginResetModel`).
- **Large or dynamic data belongs in C++**:
  <https://doc.qt.io/qt-6/qtquick-bestpractices.html#separate-ui-from-business-logic>
  "For larger and more dynamic data sets, use a strongly typed language, such as
  C++, to handle the business logic."
- **Clipping cost**:
  <https://doc.qt.io/qt-6/qquickitem.html#clip-prop> and
  <https://doc.qt.io/qt-6/qtquick-visualcanvas-scenegraph-renderer.html#clipping>
  Clip the viewport, not each delegate; per-item clip prevents batching.

## KDE Plasma 6 reference implementations

Pinned to `plasma-desktop@748e64bb09e082d49a2dc5ad32521f0c9968f268` and
`plasma-workspace@99533d6c4cc9f29336a2809d9a02ed134b2461f5`.

- **Kickoff list**:
  <https://github.com/KDE/plasma-desktop/blob/748e64bb09e082d49a2dc5ad32521f0c9968f268/applets/kickoff/KickoffListView.qml>
  A `ListView` of applications with `section.property: "group"` and
  `PlasmaExtras.ListSectionHeader`, `reuseItems: false` because pooled delegates
  kept the wrong model bindings, and `clip` only while the content overflows.
- **Kickoff grid**:
  <https://github.com/KDE/plasma-desktop/blob/748e64bb09e082d49a2dc5ad32521f0c9968f268/applets/kickoff/KickoffGridView.qml>
  A `GridView` with fixed `cellWidth`/`cellHeight`; `reuseItems: false` for the
  same reason.
- **Section blocks**:
  <https://github.com/KDE/plasma-desktop/blob/748e64bb09e082d49a2dc5ad32521f0c9968f268/applets/kickoff/ListOfGridsView.qml>
  and `ListOfGridsViewDelegate.qml`: an outer `ListView` whose delegate is a
  `KickoffGridView` sized from its row count. It virtualizes sections, not the
  cells of one very large section.
- **Favorites** are a separate model, not mixed into the 500-app list:
  <https://github.com/KDE/plasma-desktop/blob/748e64bb09e082d49a2dc5ad32521f0c9968f268/applets/kickoff/ApplicationsPage.qml>
- **Kicker model**:
  <https://github.com/KDE/plasma-workspace/blob/99533d6c4cc9f29336a2809d9a02ed134b2461f5/applets/kicker/appsmodel.cpp>
  a full `beginResetModel()` for a catalogue refresh and granular `dataChanged`
  for one entry.
- **Application Dashboard**:
  <https://github.com/KDE/plasma-desktop/blob/748e64bb09e082d49a2dc5ad32521f0c9968f268/applets/kicker/ItemMultiGridView.qml>
  a `Repeater` of category blocks, which is not virtualized across categories;
  a native reference but not a pattern to copy for a large catalogue.
- **Reuse regressions**: KDE commits `b5560b0d1b` and `aa8a1fbf` disabled
  `reuseItems` in both views; bug <https://bugs.kde.org/show_bug.cgi?id=515229>
  records a wheel-scroll category transfer issue.

## Not verified

- No official KDE document on Kickoff app-list scaling was found; only source,
  commits and bug reports.
- No verified Qt/KDE example of a strict one-row-delegate-per-N-cells list was
  found. The design in the improvement plan composes the documented ListView
  laziness with a small row delegate and must be proved with our own census.
- Qt does not quantify the object churn of a model reset; the "views rebuild
  delegates" consequence is an inference from the documented reset.
