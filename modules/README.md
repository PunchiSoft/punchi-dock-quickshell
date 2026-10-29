# Modules

Feature modules own their surfaces and their feature-specific interaction. They may use
`services/`, `components/`, `config/` and `adapters/`; nothing outside `shell.qml` and the
dock contexts imports a module's internals.

| Module | Owns | Entry |
| --- | --- | --- |
| `dock/` | the dock window, magnification, contexts and their policies | `Dock.qml` |
| `folders/` | folder containers over the native KDirModel provider | `PunchiFolderContainerPopup.qml` |
| `recent/` | the recent-applications and recent-documents containers | `PunchiRecentApplicationsPopup.qml` |
| `settings/` | the settings window and its pages | `PunchiSettingsWindow.qml` |

`shell.qml` imports `modules/dock` and `modules/settings`; the dock contexts open
`modules/folders` and `modules/recent`. A new module needs a folder, a row in this table
and, when it is a top-level surface, one import in `shell.qml`.
