# Services

PunchiDockFixtureModel builds the configured desktop-entry catalogue from
`PunchiDefaultProfile.js`. PunchiApplicationLaunchService
validates activation against the model and delegates to the desktop adapter.
PunchiProfileExchangeService reads a user-selected JSON profile, validates it with
`PunchiProfileDocument.js`, previews it on a separate settings object and applies it to
the draft only after confirmation. The native `ProfileFile` bounds and validates
the read, rejects non-regular files, writes atomically and refuses symbolic-link
destinations. PunchiAutostartService owns the optional per-user XDG autostart entry and never
overwrites or deletes a file without its ownership marker. PunchiRecentApplications
references KDE activity history through native adapters and filters pinned or
open applications without maintaining a second history. PunchiLicenseDocument reads
the LICENSE document installed next to `shell.qml` so the About page can present
the verbatim license text inside the settings window. Services never import
visual components. PunchiUpdateNotice reads the native `UpdateState` aggregation of
PackageKit, fwupd and Flatpak and decides which launcher receives the count and
whether the settings switch allows it; the query itself never installs, refreshes
caches or requests authorization. The target is resolved from the catalog against
a short list of update front-ends (Discover first), so the service follows the
pinned launcher instead of assuming a distribution. Full discovery and user pinning remain
future work.
