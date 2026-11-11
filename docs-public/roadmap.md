# Roadmap

Punchi Dock Quickshell currently focuses on a configurable dock for KDE Plasma.
Version 0.1.0 is the first development snapshot, not a completed desktop shell.

| Stage | Scope | Status |
|---|---|---|
| 1 | Modular foundations, fixed-icon dock, safe start/restore, developer checks | Implemented; basic hover/focus reviewed by user |
| 2 | Continuous magnification, themed balloons, horizontal expansion, reduced motion | Implemented; final visual review pending |
| 3 | Configured desktop-entry launching and two-hop bounce | Implemented; manual app/visual review pending |
| 3a | Native KDE launching, startup notification, and Wayland activation | Implemented; real KWin activation and KDE cursor-feedback validation pending |
| 4a | Standalone KDE window-access validation | Diagnostic complete; compositor access unavailable |
| 4b | Four Plasma visibility modes | Implemented; manual stacking/work-area review pending |
| 4b.1 | Automatic hiding and bottom-edge reveal | Implemented; independent of window overlap |
| 4b.2 | Persistent settings, KDE application discovery, pinning and ordering | Implemented; component/runtime checks, with a known engine-reload issue in 0.1.0 |
| 4b.3 | KDE desktop actions, recent documents and Places menus | Implemented; desktop/theme visual validation remains separate |
| 4b.4 | Running-application indicators through a dedicated KDE backend | In development; validation pending |
| 4c | Native filtered geometry and window dodge | Implemented; isolated validation, real KWin geometry/shortcut checks pending |
| 4d | Activate existing windows; minimize an active window on click | Implemented; isolated validation, physical KWin checks pending |
| 4e | Startup coordination, window cycling, running unpinned apps, middle-click New Window | Implemented; isolated validation, physical KWin checks pending |
| 4f | One dock per screen, shared services, screen/virtual-desktop/activity visibility and internal-edge handling | Implemented; two-screen IPC validation, physical hot-plug and visual review pending |
| 5 | Panel, launcher, and control surfaces | Planned |

Keep each stage independently useful and reversible. Shared settings, theme,
services, and interaction primitives must be reused across modules.

Do not replace Plasma panels or session services as an incidental feature change.
Decide coexistence/replacement and validate the affected service ownership first.

The eight preset launchers are defaults. Users can discover and search installed
applications through KDE, add them to the pinned list and reorder them in settings.
Apply and Accept publish pending changes; Close discards them.

The earlier window-access diagnostic records the generic Quickshell client's
observed restriction. A dedicated backend supplies running-state indicators and a separate filtered
geometry/Showing Desktop projection for window dodge. Existing-window activation
now has a separate command domain. Physical foreground/restoration and live
geometry/shortcut behavior remain unvalidated. Task Manager configuration follows
when a real configurable option is added.
