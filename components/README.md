# Components

LauncherTile owns launcher semantics and a single icon/frame/hit transform.
LauncherTooltip provides a themed, unscaled speech balloon. AntialiasedSurface
owns the shared MSAA layer. LauncherClickFeedback adapts the original bounce
feedback and TwoHopBounce preserves its two-hop motion. LauncherBadge paints the
update count as a tile child, so the magnification scale and translate carry it
with the icon; it is laid out at the maximum magnification and counter-scaled so
the digits are never upscaled.

EntryButton, EntryMarqueeLabel, EntryLayout, FanView, FanRow, FanGeometry,
PopupHeader and PopupShadowLabel are the container presentation: two confirmed
consumers (the folder container and the recent-applications container) share one
Grid/List/Detail/Fan language instead of two drifting copies. They take their
model rows, metrics and pointer/keyboard ownership as inputs and never reach a
service or an adapter themselves.
