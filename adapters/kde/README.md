# KDE adapters

QML types that reach KDE Frameworks, KWin and Plasma services for the dock. Each one
owns a capability contract and reports its unsupported case instead of faking it.

## QML adapters

| Type | Capability |
| --- | --- |
| `PunchiApplicationCatalogAdapter` | desktop-entry catalog and launch dispatch |
| `PunchiApplicationMediaAdapter` | Plasma MPRIS model behind `PunchiApplicationMediaService` |
| `PunchiApplicationSearchAdapter` | search across installed desktop entries |
| `PunchiDesktopApplicationAdapter` | launch an application through KService and activation |
| `PunchiFilePlacesAdapter` | KIO places for the container surfaces |
| `PunchiIconThemeAdapter` | KDE icon theme lookup and refresh |
| `PunchiMotionPreferences` | Kirigami animation durations |
| `PunchiRecentApplicationsAdapter`, `PunchiRecentApplicationsSelection` | KDE recent-application history and its selection model |
| `PunchiRecentDocumentsAdapter` | recent documents through KDE history |
| `PunchiUserProfile` | the account name and avatar |

## Native types

`native/` holds the C++ types registered into the `Punchi.Kde` QML module, grouped by
domain. Cross-group includes resolve through the group include path that `CMakeLists.txt`
sets, so no header reaches another group with a `../` chain.

| Group | Types |
| --- | --- |
| `applications/` | `PunchiApplicationCatalog`, `DockApplicationsModel`, `DockItemCatalog`, `PunchiRecentApplicationsAdapter`, `RecentApplicationsModel`, `DesktopEntry`, `DesktopLauncher`, `PunchiRunningApplications` |
| `windows/` | `WindowActivation`, `WindowVisibilityState`, `ScreenInfo`, `KWinMinimizeEffect`, `AutoHideEdge` |
| `files/` | `FilePlaces`, `FolderContents`, `RecentDocuments`, `TrashState` |
| `appearance/` | `IconThemeCatalog`, `IconThemeRefresh`, `PopupBlurController` |
| `profile/` | `ProfileFile` |
| `updates/` | `UpdateState` |

## Other

- `protocols/`: Wayland protocol XML scanned into headers at build time.
- `window-state/`: the standalone `punchi-window-state` process, its registration and
  the window models it publishes. `activationdecision.h` holds the free functions that
  decide an activation (`supportsWindowActivation`, `applicationWindow`,
  `activateWindowRequest`), which the backend and its tests share; the `WindowActivation`
  QML type lives in `native/windows/`, and no two headers share a name.
