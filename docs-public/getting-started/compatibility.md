# Compatibility

Punchi Dock Quickshell runs on Quickshell, so every KDE Plasma distribution for
which Quickshell itself is available is a candidate to run it. Quickshell's
[installation guide](https://quickshell.org/docs/v0.3.2/guide/install-setup/) lists
where it can be obtained: package repositories on Arch, Debian, Fedora Rawhide,
Nix, Gentoo (GURU) and Guix, a PPA on Ubuntu, a COPR on Fedora, and the
`home:AvengeMedia:danklinux` Open Build Service project on openSUSE, because the
Tumbleweed and Leap repositories carry no `quickshell` package at all. That list
decides whether the runtime exists on a system; this project neither packages nor
ships Quickshell.

Availability is not validation. A distribution where Quickshell installs is only a
candidate: the rows below record what this project has actually built and started,
and everything outside them is untested. Quickshell is also coupled to the Qt it
was compiled against, so a distribution that updates Qt without rebuilding
Quickshell can break the dock.

## Validated environments

| Status | KDE distributions / editions | Plasma | KWin | Qt | KF6 | Kirigami Addons | Quickshell | Checked |
|:---:|---|---|---|---|---|---|---|---|
| ✅ | Fedora 44 KDE | 6.7.5 | 6.7.5 | 6.11.2 | 6.31.0 | 1.13.1 | 0.2.1 | 2026-10-20 |
| 🟡 | Arch Linux (rolling, KDE Plasma) | 6.8.2 | 6.8.2 | 6.12.0 | 6.31.0 | 1.16.0 | 0.3.2 | 2026-10-31 · partial |
| 🟡 | CachyOS (rolling, KDE Plasma) | 6.8.2 | 6.8.2 | 6.12.0 | 6.31.0 | 1.16.0 | 0.3.2 | 2026-10-31 · partial |
| 🟡 | Debian 13.7 KDE (trixie) | 6.3.6 | 6.3.6 | 6.8.2 | 6.13.0 | 1.7.0 | 0.3.0 | 2026-10-30 · partial |
| ⚪ | Nobara KDE, Fedora Kinoite (immutable KDE Plasma), CentOS Stream 10 KDE (EPEL), Rocky Linux KDE, AlmaLinux Kitten KDE | — | — | — | — | — | — | — |
| ⚪ | KDE neon, Kubuntu KDE Plasma | — | — | — | — | — | — | — |
| ⚪ | Manjaro KDE, EndeavourOS KDE Plasma, Garuda KDE | — | — | — | — | — | — | — |
| ⚪ | openSUSE Tumbleweed KDE, openSUSE Leap KDE — distribution repositories carry no `quickshell` package | — | — | — | — | — | — | — |
| ⚪ | KaOS KDE Plasma, Solus KDE | — | — | — | — | — | — | — |
| ❌ | — | — | — | — | — | — | — | — |

✅ validated · 🟡 builds/starts, validation pending · ⚪ untested, same family ·
❌ unsupported · ⏳ pending · — not applicable. X11 is out of scope and non-KDE
compositors are unsupported.

## What each checked row exercised

- **Fedora 44 KDE** — the primary validated environment. It runs the complete
  automated validation graph on every change.
- **Arch Linux (rolling)** — install, trial, menu, folder containers and uninstall
  exercised on one machine on 2026-10-31. Prolonged use and full visual inspection
  remain pending, and Mesa/Zink warnings appear. Not a compatibility claim for every
  Arch installation.
- **CachyOS (rolling)** — on a fresh desktop install on 2026-10-31, the setup
  assistant installed the five missing packages in one step, the checkout built, and
  the trial printed `Configuration Loaded` before it was stopped. CachyOS serves
  optimized `cachyos-extra-v3` builds. The project test suite has not been run on
  CachyOS, and neither menu, container nor prolonged-use review has, so this is a
  compatibility claim for that install only.
- **Debian 13.7 KDE (trixie)** — the setup assistant installed every dependency and
  the dock then built and started on one machine on 2026-10-30. Prolonged use and
  full visual inspection remain pending. Quickshell comes from `trixie-backports`,
  not from the release suite, so the assistant offers to add that suite.

Only Fedora 44 has the complete automated validation graph. The list is based on the
[KDE Community wiki — Distributions](https://community.kde.org/Distributions).
Plasma 6.8.0 was released on 2026-10-14.

Kirigami Addons is listed on its own because its API moves within a KF6 major
series: 1.16.0 removed the avatar's `initialsColor` and the settings window stopped
loading on Arch, while Fedora 44 (1.13.1) and Debian 13 (1.7.0) kept working. A
rolling distribution can therefore reach an incompatible release before a fixed one
does, and the version belongs in this table next to Qt and KF6.

## Compatibility and validation

The initial target is Linux with KDE Plasma/KWin on Wayland. Quickshell and Qt must
be ABI-compatible; other combinations, distributions and compositors require their
own validation. X11 is out of scope and no support work is planned.

Updates to Plasma, KWin, KDE Frameworks, Qt or Quickshell can affect compatibility.
The risk differs between maintenance updates and changes to major versions or
internal interfaces; native KDE integration does not guarantee compatibility with
every future release. Quickshell documents breaking changes before 1.0 and
Qt-update issues with some package builds in its
[installation guide](https://quickshell.org/docs/v0.2.1/guide/install-setup/).

One current dependency needing particular attention is
`org.kde.plasma.private.mpris`, the internal Plasma module behind the context
menu's media transport. Window/task integrations and KDE screen-edge behavior also
need testing against the target Plasma/KWin version. Prefer public APIs, keep
internal integrations isolated, and provide graceful unavailability where a
capability can be optional.

Rebuilding can address a binary mismatch; changed API contracts require code
adaptation and regression checks.

Before claiming support for a release, declare required versions and test the actual
packages together, including launching, activation/minimization, menus, Trash and
hiding behavior. A normal KDE update does not intentionally manage Punchi Dock
Quickshell's personal settings file; our own format updates must migrate it. Broad
update compatibility remains a maintenance goal, not an established guarantee of
this prototype.

## Evidence limits

Automated checks can be timing-sensitive. During one complete-suite run the
`settings_reload` probe timed out and then passed when run alone. The changelog
records the current validation scope and known gaps.

An isolated Wayland session probe passed startup, duplicate prevention, rendering,
hide/reopen and scoped restoration. Automated checks do not establish final visual
quality, fractional scaling, screen-reader support, physical monitor hot-plug,
other screen layouts or native KDE startup cursor feedback. A two-screen
real-session check covered per-screen docks, screen selection, primary fallback,
virtual-desktop and activity filtering and shared-edge auto-hide; automated
fullscreen capture does not include layer-shell surfaces, so visual inspection
remains manual.
