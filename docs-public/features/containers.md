# Containers

Containers group applications, folders or recent history behind one dock item.
They share the Grid, List, Detail and Fan presentations, the themed balloon
surface and the keyboard behavior.

## Folder containers

<p align="center"><img src="../../assets/demo/container-views.webp" width="720" alt="The Home container changing presentation: Detail, then Grid, then Fan, chosen from the Folder view menu"></p>

<p align="center"><em>The same Home container in <strong>Detail</strong>,
<strong>Grid</strong> and <strong>Fan</strong>, switching through the
<strong>Folder view</strong> menu. The clip is one continuous take from the
maintainer's session; <strong>List</strong> is not shown for a folder container.</em></p>

- Any local folder can become a container. Built-in **Home** and **Downloads**
  items are defaults, not special cases in the model.
- **Presentation**: Grid, List, Detail and Fan. A side dock presents a stored Fan
  as Grid because the arc needs a top or bottom edge.
- Per-container sorting, subfolder browsing and a hidden-entry list.
- **Folder view** and **Sort by** open submenus with a **Back to menu** row. The
  view and sort choices carry the same icons as PunchiDock Remastered: grid, list,
  detailed list, fan, name, size, date and type.
- The built-in **Home** container opens as Fan and lists only the standard
  KDE/XDG user folders through their localized names. Its first-run profile leaves
  subfolder browsing off, so a selected folder opens in the file manager.
- Every presentation ends with an **Open** row and marks browsable folders with a
  chevron. A right-click on an entry offers **Open in File Manager** and
  **Copy Path**.
- Columns come from the space the popup really has, so scrolling appears only when
  the entries do not fit, with a slim indicator that fades while the listing rests.
- Opening inside the balloon uses native KDE file opening and the preferred MIME
  application for the selected entry.

The listing is a native `KDirModel` provider with a sort proxy. Navigation history
and file-opening intents belong to `PunchiFolderNavigationController`; the
presentation components receive rows and emit intents. See
[Data and settings](../architecture/data-and-settings.md#containers).

## Recent applications

- Optional recent applications from KDE activity history, with a configurable
  count.
- **Presentation** chooses either extra dock launchers or one container item with
  a fixed glyph. The container is the first-run presentation.
- **Container view** offers Grid, List, Detail and Fan for the container
  presentation, in its own submenu with a **Back to menu** row. The first-run view
  is List.
- Pinned applications and applications with open windows are excluded in both
  presentations.
- Dock settings include a switch that writes KDE's remember-applications
  preference and a shortcut to KDE's Recent Files options. When KDE saves no
  application history, a short note explains how to enable it.
- History is read from KDE; the project does not maintain a second recent list.
  The query follows KDE's current activity, and falls back to all activities when
  the service reports none.

## Item and presentation settings

- Item editors choose a theme icon for any pinned application or folder container
  and store it by name.
- Containers carry their selected Grid/List/Detail view in the saved profile.
- Trash is offered only when not already pinned, and a removed container pin keeps
  its built-in Home or Downloads descriptor available.
- Popup size, height and icon size have their own **Popups** category. The grid,
  the list/detail rows and the fan keep independent glyph sizes.

Removing a user folder pin removes the descriptor, never the directory or its
contents. Applying or accepting the settings window publishes pending changes;
closing it discards them. See [Settings](../configuration/settings.md).
