# Support

Punchi Dock Quickshell is alpha software maintained on a best-effort basis. There
is no stable release, long-term support branch, response time or fix guarantee.

## Where to ask

- Bug reports: open the repository bug form. It asks for the versions and steps a
  reproduction needs.
- Feature requests: open the feature request form and describe the observable
  behavior you want.
- Security problems: use the private advisory route in
  [SECURITY.md](SECURITY.md). Do not open a public issue.
- General contribution workflow: read [CONTRIBUTING.md](CONTRIBUTING.md).

Issues are the only support channel; Discussions and the wiki are disabled.

## Before you report

1. Read the [README](README.md), especially Known limitations and Compatibility
   at a glance.
2. Run `./scripts-user/setup.sh --check-deps` and keep its output.
3. Reproduce once with a fresh start: `./scripts-user/start.sh`, then
   `./scripts-user/restore-kde.sh` when you stop.
4. Search existing issues and pull requests.

## What a report needs

- Distribution and version.
- KDE Plasma and KWin versions, and the session type (Wayland is the only
  supported session).
- Qt and Quickshell versions, for example `qs --version` and
  `qtpaths6 --qt-version`.
- Steps to reproduce, the expected result and the observed result.
- Relevant log lines from
  `${XDG_STATE_HOME:-$HOME/.local/state}/punchi-dock-quickshell/start.log`.
- Whether the problem also happens after `./scripts-user/restore-kde.sh` and a
  new start.

Remove usernames, home paths, tokens, window titles and any private file content
before pasting logs or screenshots.

## Not supported

- X11. It is out of scope and no support work is planned.
- Non-KDE compositors and desktops.
- Distribution combinations that are not listed as validated. They need their own
  Quickshell/Qt build and their own testing.
- Composer, window-manager or Plasma bugs caused outside this project; report
  those upstream.
