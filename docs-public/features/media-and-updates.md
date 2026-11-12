# Media and updates

Desktop status the dock shows without owning the underlying service.

## Media transport

- Transport for the matching KDE MPRIS player: **Previous Track**, **Play/Pause**,
  **Next Track** and **Stop**.
- The rows appear only while a player exists and follow its live capabilities.
- The menu closes after dispatch.
- The private Plasma MPRIS provider is isolated in one adapter; the service owns
  the transport contract and reusable metadata, so media state is independent of
  dock surfaces.

Media transport still needs broader real-session validation across players.

## Trash

- A Trash item backed by native KDE state.
- Left-click opens the Trash.
- The context menu offers **Open** and **Empty Trash** behind one themed
  confirmation.
- The destructive action stays disabled while the Trash is empty, unavailable or
  busy.
- KDE supplies a fresh listing after the job instead of an assumed empty result.

The dock never deletes files directly: KIO performs the operation through the
native Trash state.

## Update badge

An update badge appears on the Discover launcher while the machine has pending
updates.

- The count is read only from PackageKit, fwupd and Flatpak through their native
  interfaces.
- The dock never asks Discover, never installs anything, never refreshes package
  caches and never requests authorization.
- The number travels and scales with the icon and rests on its lower-right corner,
  where KDE paints its own update dots.
- The badge takes the color KDE paints its update notifications with: neutral
  orange while updates are pending and negative red once a security update is
  present.
- While PackageKit applies updates, the disc shows the tray's `update-busy` glyph
  instead of the count, and rechecks as soon as the install ends, so a just-applied
  count is not painted again.
- The **Updates** switch turns the badge off without a restart.
- The badge follows whichever supported update front-end is actually pinned
  (Discover first) rather than assuming a distribution; a missing service simply
  contributes nothing.

PackageKit reports its own backend (`dnf5`, `apt`, `alpm`, `zypper` ...), so
distribution packages work wherever PackageKit is installed. AUR helpers and Snap
are not queried yet.

The backend aggregation is described in
[Native backend](../architecture/native-backend.md#updates).
