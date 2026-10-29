# Components

PunchiDockTile owns dock-item semantics and a single icon/frame/hit transform.
PunchiDockTooltip provides a themed, unscaled speech balloon, and
PunchiAntialiasedSurface owns the shared MSAA layer. PunchiDockClickFeedback
adapts the original bounce feedback and PunchiTwoHopBounce preserves its two-hop
motion. PunchiDockBadge paints the update count as a tile child, so the
magnification scale and translate carry it with the icon; it is laid out at the
maximum magnification and counter-scaled so the digits are never upscaled.

PunchiEntryButton, PunchiEntryMarqueeLabel, PunchiEntryLayout, PunchiFanView,
PunchiFanRow, PunchiFanGeometry, PunchiPopupHeader and PunchiPopupShadowLabel are
the container presentation: two confirmed consumers (the folder container and the
recent-applications container) share one Grid/List/Detail/Fan language instead of
two drifting copies. They take their model rows, metrics and pointer/keyboard
ownership as inputs and never reach a service or an adapter themselves.

Names follow the convention in `AGENTS.md`: `Punchi` states the product, the
second word states the surface that owns the type (`PunchiDock*`, `PunchiMenu*`),
and a primitive shared by several surfaces names its form
(`PunchiBalloonSurface`, `PunchiFanView`). `menu` means the application menu;
context menus are `PunchiDockContext*` and `PunchiPopup*`. Every type here
already complies, `tests/naming-baseline.json` is empty, and `component_naming`
fails on a new type that skips the rule.
