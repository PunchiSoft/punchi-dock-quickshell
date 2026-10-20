# Services

DockFixtureModel supplies eight configured desktop-entry IDs. ApplicationLaunchService
validates activation against the model and delegates to the desktop adapter.
AutostartService owns the optional per-user XDG autostart entry and never
overwrites or deletes a file without its ownership marker. RecentApplications
references KDE activity history through native adapters and filters pinned or
open applications without maintaining a second history. LicenseDocument reads
the LICENSE document installed next to `shell.qml` so the About page can present
the verbatim license text inside the settings window. Services never import
visual components. Full discovery and user pinning remain
future work.
