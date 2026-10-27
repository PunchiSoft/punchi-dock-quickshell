#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify every delivery-version declaration against the newest CHANGELOG entry."""

from pathlib import Path
import re
import sys

VERSION = r'\d+\.\d+\.\d+'
CHANGELOG_HEADING = re.compile(rf'^## ({VERSION}) — \d{{4}}-\d{{2}}-\d{{2}}$', re.M)


def capture(pattern):
    def finder(text, _expected):
        match = pattern.search(text)
        return match[1] if match else None
    return finder


def table_row(text, expected):
    # The local versioning record keeps one row per historical delivery.
    return expected if re.search(rf'^\| {re.escape(expected)} \|', text, re.M) else None


# Every declaration is the authoritative counter mirrored somewhere else. The
# local record is optional so the check also runs on a checkout without docs/.
DECLARATIONS = (
    ('CMakeLists.txt',
     capture(re.compile(rf'project\(punchi-dock-quickshell VERSION ({VERSION})')), True),
    ('README.md',
     capture(re.compile(rf'\*\*Current delivery:\*\* \*\*({VERSION})\*\*')), True),
    ('README.es.md',
     capture(re.compile(rf'\*\*Entrega actual:\*\* \*\*({VERSION})\*\*')), True),
    ('AGENTS.md',
     capture(re.compile(rf'The current delivery is `({VERSION})`')), True),
    ('modules/settings/SettingsAbout.qml',
     capture(re.compile(rf'applicationVersion: "({VERSION})"')), True),
    ('tests/runtime/application-items/tst_settings_window.qml',
     capture(re.compile(rf'Punchi Dock Quickshell ({VERSION})')), True),
    ('docs/versioning.md', table_row, False),
)


def main():
    root = Path(__file__).resolve().parents[1]
    changelog = root / 'CHANGELOG.md'
    if not changelog.is_file():
        print('CHANGELOG.md is missing; the delivery version cannot be verified.',
              file=sys.stderr)
        return 1
    delivery = CHANGELOG_HEADING.search(changelog.read_text())
    if delivery is None:
        print('CHANGELOG.md has no "## <version> — <date>" delivery heading.',
              file=sys.stderr)
        return 1
    expected = delivery[1]

    failures = []
    checked = 0
    for relative, finder, required in DECLARATIONS:
        path = root / relative
        if not path.is_file():
            if required:
                failures.append(f'{relative}: file is missing')
            continue
        checked += 1
        found = finder(path.read_text(), expected)
        if found is None:
            failures.append(f'{relative}: no {expected} declaration found')
        elif found != expected:
            failures.append(f'{relative}: declared {found}, expected {expected}')

    if failures:
        print(f'Delivery version {expected} is inconsistent:', file=sys.stderr)
        for failure in failures:
            print(f'  {failure}', file=sys.stderr)
        return 1

    print(f'Delivery version: {expected} declared consistently in {checked} files.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
