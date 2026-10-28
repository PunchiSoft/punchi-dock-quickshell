# Config

DockMetrics derives shared geometry from Kirigami.Units. ShellSettings exposes
reactive preferences; TooltipStyle owns balloon metrics. MotionPreferences supplies
KDE animation durations. DockMetrics also sizes the update badge (`badgeBaseSize`,
`badgeFontPixelSize`, `badgeInset`), taken from `Kirigami.Units.iconSizes.small`,
`Kirigami.Theme.smallFont` and `Kirigami.Units.smallSpacing`. LauncherBadge lays
them out at the configured maximum magnification on the icon corner.

`ScreenSelection.js` holds the pure screen-selection, primary-fallback and
shared-edge rules used by `ScreenPolicy` and its tests. `RecentPresentation.js`
holds the two recent-applications presentations, the four container views and
the fixed container glyph, so the default profile, the profile document, the
settings guards and the dock read one source. `DefaultProfile.js` is
the canonical first-run profile: launcher catalogue, pinned order, folders,
preference values and validation ranges. A catalogue row with an empty
`desktopId` and a `defaultMimeTypes` string names a role the native catalogue
resolves through `KApplicationTrader`, which is how **Browser** opens this
session's preferred browser instead of a fixed one; the first-run Home container
stores `browseSubfolders: false`; profile version 12 also stores screen,
virtual-desktop and activity selections plus the placement switches; profile
version 13 adds the recent-applications presentation and its container view. `ShellSettings`
starts from it and `reset()` restores a fresh copy. `ProfileDocument.js` validates
the portable JSON document used by import and export, including the raw saved
profile form; it never evaluates JavaScript.
