# KDE adapters

QML types that reach KDE Frameworks, KWin and Plasma services for the dock. Each one
owns a capability contract and reports its unsupported case instead of faking it.

## QML adapters

| Type | Capability |
| --- | --- |
| `ApplicationCatalogAdapter` | desktop-entry catalog and launch dispatch |
| `ApplicationMediaAdapter` | Plasma MPRIS model behind `ApplicationMediaService` |
| `ApplicationSearchAdapter` | search across installed desktop entries |
| `DesktopApplicationAdapter` | launch an application through KService and activation |
| `FilePlacesAdapter` | KIO places for the container surfaces |
| `IconThemeAdapter` | KDE icon theme lookup and refresh |
| `MotionPreferences` | Kirigami animation durations |
| `RecentApplicationsAdapter`, `RecentApplicationsSelection` | KDE recent-application history and its selection model |
| `RecentDocumentsAdapter` | recent documents through KDE history |
| `UserProfile` | the account name and avatar |

## Native types

`native/` holds the C++ types registered into the `Punchi.Kde` QML module, grouped by
domain. Cross-group includes resolve through the group include path that `CMakeLists.txt`
sets, so no header reaches another group with a `../` chain.

| Group | Types |
| --- | --- |
| `applications/` | `ApplicationCatalog`, `DockApplicationsModel`, `DockItemCatalog`, `RecentApplicationsAdapter`, `RecentApplicationsModel`, `DesktopEntry`, `DesktopLauncher`, `RunningApplications` |
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
