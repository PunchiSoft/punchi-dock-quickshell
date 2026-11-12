# Troubleshooting

Known limits, expected warnings and the recovery paths that leave Plasma running.

## Known limitations

- Alpha software: behavior, configuration and native APIs may change without
  migration.
- Quickshell 0.3.0 logs one harmless `WARN: QSettings::value: Empty key passed`
  at startup in some distributions, including Debian 13. It appears before the shell
  loads and with an empty configuration, so this project does not produce it; it
  does not change behavior, and the full startup log keeps it for diagnosis.
- Requires KDE Plasma/KWin on Wayland. Other desktops and compositors are not
  supported. X11 is out of scope and no support work is planned. Within KDE Plasma
  the runtime limit is Quickshell: where it is available the dock is a candidate,
  and openSUSE is the case that needs an extra repository because its own
  repositories do not carry the package.
- Fedora 44 with KDE Plasma 6.7.5 and KWin 6.7.5 on Wayland, checked 2026-10-20, is
  the primary validated environment. Arch Linux and Debian 13.7 KDE have passed a
  build and initial-start test; prolonged-use and full visual validation remain
  pending.
- English UI only for now; [README.es.md](../README.es.md) is a documentation
  translation.
- Source and CMake prefix installs only; no RPM/DEB packages, tags or release
  binaries.
- Window activation, media transport and KWin cursor feedback still need broader
  real-session validation. A two-screen layout (eDP-1 + HDMI-A-1, Plasma 6.7.5)
  exercised per-screen docks, screen selection, primary fallback,
  virtual-desktop and activity filtering and shared-edge auto-hide on 2026-10-27;
  other layouts, physical hot-plug and fractional scaling remain unvalidated.

## The dock does not start

1. Read the startup log written by the menu entry:
   `${XDG_STATE_HOME:-$HOME/.local/state}/punchi-dock-quickshell/start.log`.
2. Run `./scripts-user/setup.sh --check-deps` and install what it reports.
3. Start in the foreground with `./scripts-user/start.sh` so the failure is visible
   in the terminal.
4. If a setup step failed, the assistant wrote
   `punchi-dock-quickshell-setup-*.log` under your Documents directory with the
   version, distribution, paths and captured compiler output.

## Another instance is running

Only one instance runs at a time. Starting a second one reports the active path and
the restore script that stops it. Stop the reported instance with
`./scripts-user/restore-kde.sh` before starting the other copy.

## Return to the KDE interface

`./scripts-user/restore-kde.sh` stops this project's Quickshell configuration and
restores the KWin settings the dock owns, even when the dock is already stopped.
Plasma keeps running and other Plasma configuration is untouched. See
[Desktop integration](features/desktop-integration.md).

## A KDE setting changed outside the dock

A key changed outside Punchi Dock Quickshell is preserved as an external user change
and is no longer restored by the dock. See
[Native backend](architecture/native-backend.md#owned-kwin-settings).

## Expected warnings

- The `QSettings::value: Empty key passed` warning from Quickshell 0.3.0 in some
  distributions, including Debian 13, appears before `Configuration Loaded` and
  with an empty configuration. This project does not produce it.
- Mesa/Zink warnings were observed on Arch Linux with Quickshell 0.3.2.
- A timed-out session probe can pass when run alone; see
  [Compatibility](getting-started/compatibility.md#evidence-limits).

## Reporting a problem

Report security problems through [SECURITY.md](../SECURITY.md), never in a public
issue. For everything else, [SUPPORT.md](../SUPPORT.md) lists the information a
report needs: version, distribution and Plasma/KWin/Qt/Quickshell versions, the
startup log and the steps that reproduce the behavior.
