# Components

LauncherTile owns launcher semantics and a single icon/frame/hit transform.
LauncherTooltip provides a themed, unscaled speech balloon. AntialiasedSurface
owns the shared MSAA layer. LauncherClickFeedback adapts the original bounce
feedback and TwoHopBounce preserves its two-hop motion. LauncherBadge paints the
update count as a tile child, so the magnification scale and translate carry it
with the icon; it is laid out at the maximum magnification and counter-scaled so
the digits are never upscaled.
