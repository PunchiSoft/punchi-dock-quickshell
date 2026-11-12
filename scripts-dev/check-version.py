#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify every release-version declaration against the newest dated CHANGELOG entry."""

from pathlib import Path
import re
import sys

NUMERIC = r'\d+\.\d+\.\d+'
PRERELEASE = r'(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?'
VERSION = NUMERIC + PRERELEASE
CHANGELOG_HEADING = re.compile(rf'^## ({VERSION}) — \d{{4}}-\d{{2}}-\d{{2}}$', re.M)


def capture(pattern):
    def finder(text, _expected):
        match = pattern.search(text)
        return match[1] if match else None
    return finder


def table_row(text, expected):
    # The local record keeps one row per historical release.
    return expected if re.search(rf'^\| {re.escape(expected)} \|', text, re.M) else None


# CMake accepts only a numeric project version, so the tree keeps the base and the
# display string separately. Every other declaration mirrors the display version.
DECLARATIONS = (
    ('CMakeLists.txt',
     capture(re.compile(rf'set\(PUNCHI_VERSION_BASE ({NUMERIC})\)')), 'base', True),
    ('CMakeLists.txt',
     capture(re.compile(rf'set\(PUNCHI_DISPLAY_VERSION "({VERSION})"\)')), 'display', True),
    ('README.md',
     capture(re.compile(rf'\*\*First beta, not published\.\*\* The tree declares '
                        rf'version\s+\*\*({VERSION})\*\*')), 'display', True),
    ('README.es.md',
     capture(re.compile(rf'\*\*Primera beta, sin publicar\.\*\* El árbol declara la '
                        rf'versión\s+\*\*({VERSION})\*\*')), 'display', True),
    ('AGENTS.md',
     capture(re.compile(rf'The declared version is `({VERSION})`')), 'display', True),
    ('modules/settings/PunchiSettingsAbout.qml',
     capture(re.compile(rf'applicationVersion: "({VERSION})"')), 'display', True),
    ('tests/runtime/application-items/tst_settings_window.qml',
     capture(re.compile(rf'Punchi Dock Quickshell ({VERSION})')), 'display', True),
    ('docs-public/versioning.md', table_row, 'display', True),
)


def main():
    root = Path(__file__).resolve().parents[1]
    changelog = root / 'CHANGELOG.md'
    if not changelog.is_file():
        print('CHANGELOG.md is missing; the release version cannot be verified.',
              file=sys.stderr)
        return 1
    release = CHANGELOG_HEADING.search(changelog.read_text())
    if release is None:
        print('CHANGELOG.md has no "## <version> — <date>" release heading.',
              file=sys.stderr)
        return 1
    display = release[1]
    base = display.split('-', 1)[0]
    expected = {'base': base, 'display': display}

    failures = []
    checked = 0
    for relative, finder, kind, required in DECLARATIONS:
        path = root / relative
        if not path.is_file():
            if required:
                failures.append(f'{relative}: file is missing')
            continue
        checked += 1
        found = finder(path.read_text(), expected[kind])
        if found is None:
            failures.append(f'{relative}: no {expected[kind]} declaration found')
        elif found != expected[kind]:
            failures.append(f'{relative}: declared {found}, expected {expected[kind]}')

    if failures:
        print(f'Release version {display} is inconsistent:', file=sys.stderr)
        for failure in failures:
            print(f'  {failure}', file=sys.stderr)
        return 1

    print(f'Release version: {display} declared consistently in {checked} files '
          f'(CMake base {base}).')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
