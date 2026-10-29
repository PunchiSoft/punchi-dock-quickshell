#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check the component naming convention described in AGENTS.md.

A QML type's name is its file name and each layer directory is flat, so the
prefix is the namespace. Every type in a naming layer starts with `Punchi`, and
no local type may shadow a Qt or KDE type it would collide with.

Types that predate the rule are recorded in `tests/naming-baseline.json`. The
list only shrinks: a new type must already comply, a renamed type must drop its
entry in the same change, and an entry whose file is gone or already compliant
fails the test.
"""

from pathlib import Path
import json
import sys

PREFIX = 'Punchi'
NAMING_LAYERS = ('components', 'config', 'services', 'modules', 'adapters')
# Types exported by QtQuick.Controls. A local file with one of these names
# shadows the toolkit type in every file that imports the module.
RESERVED = (
    'Menu.qml',
    'MenuItem.qml',
    'MenuBar.qml',
    'MenuSeparator.qml',
    'MenuBarItem.qml',
)
BASELINE = Path('tests/naming-baseline.json')


def naming_files(root):
    """Yield every QML type file in a naming layer, sorted by path."""
    for layer in NAMING_LAYERS:
        directory = root / layer
        if not directory.is_dir():
            continue
        for path in sorted(directory.rglob('*.qml')):
            yield path


def load_baseline(path):
    if not path.is_file():
        return {}
    document = json.loads(path.read_text(encoding='utf-8'))
    pending = document.get('pending')
    if not isinstance(pending, list) or not all(isinstance(item, str) for item in pending):
        raise ValueError('pending must be a list of repository-relative paths')
    return {item: document.get('reason', '') for item in pending}


def main():
    root = Path(__file__).resolve().parents[1]
    try:
        baseline = load_baseline(root / BASELINE)
    except (ValueError, json.JSONDecodeError) as error:
        print(f'Naming: unreadable {BASELINE}: {error}', file=sys.stderr)
        return 1
    files = {path.relative_to(root).as_posix(): path for path in naming_files(root)}
    violations = []
    compliant = 0
    for relative, path in sorted(files.items()):
        if path.name in RESERVED:
            violations.append((relative, f'shadows the QtQuick.Controls type {path.stem}',
                'name the surface instead, for example PunchiMenuWindow.qml'))
            continue
        if path.name.startswith(PREFIX):
            compliant += 1
            if relative in baseline:
                violations.append((relative, 'stale baseline entry',
                    'remove it: the file already complies'))
            continue
        if relative not in baseline:
            violations.append((relative, 'missing the Punchi prefix',
                'prefix the type with Punchi and name the surface when more than one '
                'owns the concept: PunchiDock*, PunchiMenu*, Punchi<Form>'))
    for relative in sorted(baseline.keys() - files.keys()):
        violations.append((relative, 'stale baseline entry',
            'remove it: the file is gone or was renamed'))
    for relative, problem, hint in violations:
        print(f'{relative}: {problem}\n  {hint}', file=sys.stderr)
    if violations:
        print(f'Naming: {len(violations)} violation(s).', file=sys.stderr)
        return 1
    pending = len(baseline)
    print(f'Naming: {compliant} compliant, {pending} pending rename, 0 violations.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
