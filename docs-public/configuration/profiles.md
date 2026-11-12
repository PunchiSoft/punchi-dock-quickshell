# Profiles

A portable profile moves the dock items, folder containers and preferences
between machines without copying a program installation.

## Export

The **Profile** category exports the pending values as a portable JSON document
with schema `punchi-dock-quickshell/profile` and format version 1. The export is
written atomically with owner-only permissions, and a symbolic-link destination is
never overwritten.

## Import

Import also accepts a raw saved profile, validates every field, and previews the
result before the values become pending edits. The preview runs on a separate
settings object, so the current dock and the saved file stay untouched until the
user confirms. After confirmation, the imported values are pending edits like any
other change: Apply or Accept publishes them and Close discards them.

## File contract

- The selected file must be a regular UTF-8 file of at most 256 KiB.
- FIFOs and device files are rejected.
- Validation covers the profile document, item identities, container entries,
  preference ranges and unknown or unsupported versions.
- A profile newer than the supported format version is rejected instead of
  partially applied.

## What a profile cannot contain

A profile is data only: it cannot add commands, executable JavaScript, autostart
entries, KDE configuration or file contents. Autostart remains an
installation-level integration and is not part of a profile.

## Trial profiles

A trial run keeps its own profile in the instance runtime directory and exports it
as `PUNCHI_PROFILE_DIR`. It starts from the default items, never changes the
profile an installed copy owns, and is removed with the trial cleanup unless the
confirmation is declined.

The stored-file schema, migration rules and defaults are documented in
[Data and settings](../architecture/data-and-settings.md#persistence).
