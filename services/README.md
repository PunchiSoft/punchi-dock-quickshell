# Services

DockFixtureModel supplies eight configured desktop-entry IDs. ApplicationLaunchService
validates activation against the model and delegates to the desktop adapter.
AutostartService owns the optional per-user XDG autostart entry and never
overwrites or deletes a file without its ownership marker. Services never import
visual components. Full discovery and user pinning remain
future work.
