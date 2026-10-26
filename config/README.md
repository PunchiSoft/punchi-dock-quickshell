# Config

DockMetrics derives shared geometry from Kirigami.Units. ShellSettings exposes
reactive preferences; TooltipStyle owns balloon metrics. MotionPreferences supplies
KDE animation durations. DockMetrics also sizes the update badge (`badgeBaseSize`,
`badgeFontPixelSize`, `badgeInset`), taken from `Kirigami.Units.iconSizes.small`,
`Kirigami.Theme.smallFont` and `Kirigami.Units.smallSpacing`. LauncherBadge lays
them out at the configured maximum magnification on the icon corner.
