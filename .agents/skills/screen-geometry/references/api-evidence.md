# API evidence for screen geometry

Checked on 2026-11-12 against the official documentation and the installed
session. Re-check the symbol before relying on it in a new Qt/Kirigami release.

## Installed and tested versions

| Component | Version |
|---|---|
| Qt | 6.11.2 |
| KF6 Kirigami | 6.31.0 |
| Plasma | 6.8.2 |
| Quickshell | 0.2.1 (`git20260209.dacfa9d`) |
| Fedora | 44 |
| Session | KDE Plasma, Wayland, 1920×1080, scale 1 |

The online Qt documentation currently serves Qt 6.12; the symbols used here
also exist in the installed 6.11.2.

## Qt high DPI

Source: <https://doc.qt.io/qt-6/highdpi.html>

- Qt's main coordinate system is device-independent pixels. Window, Item, event
  and screen geometry are in that system.
- `QScreen::geometry()` may not be the physical pixel count. A device pixel ratio
  maps logical pixels to physical pixels.
- The screen list is authoritative for virtual-desktop reasoning; do not assume
  that a position immediately outside one screen belongs to its neighbour.
- `QT_SCALE_FACTOR` is a debugging tool, not a product setting. Do not multiply
  layout values by it.
- Fractional scaling can make the window DPR differ from the screen DPR; prefer
  the window's DPR for raster work.

Decision: keep QML layout values in logical pixels and never apply DPR twice.
Use DPR only for image/raster/OpenGL decisions.

## QScreen

Source: <https://doc.qt.io/qt-6/qscreen.html>

- `availableGeometry` excludes window-manager reserved areas such as task bars.
- On X11 it returns true available geometry only with one monitor and a window
  manager that sets `_NET_WORKAREA`; otherwise it may equal `geometry`.
- `devicePixelRatio` may differ from `QWindow::devicePixelRatio`, for example on
  Wayland with fractional scaling or surface-resolution properties. Prefer the
  window value when the target window is known.
- `logicalDotsPerInch` is for font/UI conversion; physical DPI is for physical
  measurements.

Decision: do not assume `availableGeometry` is a reliable layer-shell
reservation on Wayland. Measure the surface and subtract explicit margins.

## Qt Quick Screen attached type

Source: <https://doc.qt.io/qt-6/qml-qtquick-screen.html>

- Attached properties include `width`, `height`, `desktopAvailableWidth`,
  `desktopAvailableHeight`, `devicePixelRatio`, `orientation` and `pixelDensity`.
- The attached type is not valid at `Component.onCompleted`, because the Item or
  Window has not been displayed on a screen yet.
- `desktopAvailableWidth/Height` describe the virtual desktop excluding WM
  reservations, not one surface's content rect.

Decision: prefer the measured `Item` geometry for a layer-shell surface. Use
the screen object only to select the monitor or seed a fallback.

## Quickshell ShellScreen (0.2.1)

Source: <https://quickshell.org/docs/v0.2.1/types/Quickshell/ShellScreen/>

- `ShellScreen` exposes `width`, `height`, `x`, `y`, `name`, `model`,
  `serialNumber`, `orientation`, `primaryOrientation`, `physicalPixelDensity`,
  `logicalPixelDensity` and `devicePixelRatio`.
- It is a monitor object, not a window content rect. The documentation does not
  expose an `availableGeometry` property.
- The docs warn that stored copies become dangling after a monitor disconnect
  and return default values; reconnecting does not restore the same object.
- Quickshell uses its own type because the native Qt `Screen` could not be
  reused.

Decision: use `ShellScreen` to identify and select the monitor; use the measured
window content and explicit margins for the layout rectangle. Do not invent an
`availableGeometry` equivalent.

## Qt Quick Layouts

Source: <https://doc.qt.io/qt-6/qtquicklayouts-overview.html>

- Layouts own their children's geometry, including width, height, x, y and
  anchors. Do not set those properties on a child of a layout.
- Only a layout with no parent layout may use `anchors.fill: parent`.
- Use `Layout.minimumWidth`, `preferredWidth`, `maximumWidth`,
  `Layout.fillWidth` and the height equivalents for constraints and weights.
- Do not bind implicit or preferred sizes to the layout or to items the layout
  depends on; that creates cyclic dependencies.

Decision: use Layouts for resizable groups and computed rectangles for the
fixed grid. Do not mix both on the same child's geometry.

## Kirigami Units

Source: <https://api.kde.org/qml-org-kde-kirigami-platform-units.html>

- `gridUnit` is the fundamental unit of space for sizes, in pixels. Read it; do
  not hardcode 18.
- `smallSpacing` is for smaller UI elements such as a small icon and its label.
- `mediumSpacing` is for medium elements such as toolbar buttons and fields.
- `largeSpacing` is for bigger UI elements such as a large icon and a heading.
- `iconSizes` exposes `small`, `smallMedium`, `medium`, `large`, `huge`,
  `enormous` and `sizeForLabels`, normalised for DPI.
- `cornerRadius` is available since Kirigami 6.2.
- `shortDuration`, `mediumDuration`, `longDuration` and `veryLongDuration`
  follow the user's animation settings; `humanMoment` must not be used as an
  animation duration.

Decision: use Units for every spacing, icon, radius and duration token. A
reference layout may define a documented pixel value only when the design source
requires it, and that value belongs in `config/` with a test.

## KDE HIG layout and navigation

Source: <https://develop.kde.org/hig/layout_and_nav/>

- Use the Kirigami standard units consistently.
- The HIG table maps small related spacing to `smallSpacing`, groups and page
  edges to `largeSpacing`, toolbar spacing to `mediumSpacing`, and fixed sizes
  to `gridUnit` multiples (the page states 18 px).
- Icon sizes: `IconSizes.small` for menu items and raised buttons,
  `IconSizes.smallMedium` for flat/toolbar buttons and list items without
  subtitles, `IconSizes.medium` for list items with subtitles.
- Layouts must adapt to window shape and size; do not just scale a desktop UI
  down to a phone.
- Anchor and Qt Layout positioning reverse automatically for right-to-left
  languages; manually mirrored custom controls and direction icons still need
  checking.

Decision: use the HIG mapping rather than inventing a spacing scale. Reference
grids may use proportional scaling, but their unit-bearing details (spacing,
icon tokens, radii) still come from Kirigami.

## Owner-provided model

The owner supplied `modelo_matematico_geometria_pantallas_KDE.pdf` on
2026-11-12. Its useful rules are:

- model each element as a rectangle and calculate position, size, area and
  intersection;
- use computational geometry, proportions and constrained optimisation, not
  integral calculus;
- work in logical coordinates and keep DPR conversion coherent;
- subtract reserved areas to obtain the useful space;
- preserve a reference design with `S = min(W / W0, H / H0)`;
- validate collisions and separations after distribution.

This skill turns those rules into a repository procedure. The PDF's generic
advice is not runtime proof of a Qt or KDE behaviour; the API notes above are the
evidence used for the implementation.
