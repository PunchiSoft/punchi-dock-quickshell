#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check the component naming convention described in AGENTS.md.

A QML type's name is its file name and each layer directory is flat, so the
prefix is the namespace. Every type in a naming layer starts with `Punchi`, and
no local type may shadow a Qt or KDE type it would collide with.

`tests/naming-baseline.json` exists as a visible record with an empty `pending`
list, and it must stay empty: a type that predates the convention is renamed, not
recorded. Silencing a naming failure by adding an entry fails this test, so the
fix is always the rename. A deliberate exemption would have to change this file
and its rule, which is a reviewable decision instead of a quiet edit.
"""

from pathlib import Path
import json
import sys
import tempfile

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

PREFIX_HINT = ('prefix the type with Punchi and name the surface when more than one '
               'owns the concept: PunchiDock*, PunchiMenu*, Punchi<Form>')
BASELINE_HINT = ('rename the type instead of recording it; the baseline stays empty, so '
                 'a naming failure is fixed by the rename')


def naming_files(root):
    """Yield every QML type file in a naming layer, sorted by path."""
    for layer in NAMING_LAYERS:
        directory = root / layer
        if not directory.is_dir():
            continue
        for path in sorted(directory.rglob('*.qml')):
            yield path


def load_baseline(path):
    """Return the recorded pending names, rejecting a malformed document."""
    if not path.is_file():
        raise ValueError('missing tests/naming-baseline.json')
    document = json.loads(path.read_text(encoding='utf-8'))
    pending = document.get('pending')
    if not isinstance(pending, list) or not all(isinstance(item, str) for item in pending):
        raise ValueError('pending must be a list of repository-relative paths')
    return pending


def violations(root, baseline):
    """Return (count_compliant, [(path, problem, hint)]) for one tree."""
    files = {path.relative_to(root).as_posix(): path for path in naming_files(root)}
    found = []
    compliant = 0
    for relative, path in sorted(files.items()):
        if path.name in RESERVED:
            found.append((relative, f'shadows the QtQuick.Controls type {path.stem}',
                'name the surface instead, for example PunchiMenuWindow.qml'))
        elif path.name.startswith(PREFIX):
            compliant += 1
        else:
            found.append((relative, 'missing the Punchi prefix', PREFIX_HINT))
    for relative in baseline:
        if relative in files:
            found.append((relative, 'recorded in the naming baseline',
                BASELINE_HINT))
        else:
            found.append((relative, 'stale baseline entry',
                'remove it: the file is gone or was renamed'))
    return compliant, found


def self_check():
    """Prove the checks can fail, so a green run means something."""
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        (root / 'components').mkdir()
        (root / 'tests').mkdir()
        (root / 'components' / 'Compliant.qml').write_text('import QtQuick\nItem {}\n')
        (root / 'components' / 'PunchiGood.qml').write_text('import QtQuick\nItem {}\n')
        (root / 'components' / 'Menu.qml').write_text('import QtQuick\nItem {}\n')

        compliant, found = violations(root, [])
        problems = {relative: problem for relative, problem, _ in found}
        assert compliant == 1, 'the self-check miscounted compliant types'
        assert problems.get('components/Compliant.qml') == 'missing the Punchi prefix'
        assert problems.get('components/Menu.qml', '').startswith('shadows')
        assert 'components/PunchiGood.qml' not in problems

        _, found = violations(root, ['components/PunchiGood.qml'])
        assert any('recorded in the naming baseline' in problem
                   for _, problem, _ in found), 'a recorded name must fail'
        _, found = violations(root, ['components/Gone.qml'])
        assert any('stale baseline entry' in problem
                   for _, problem, _ in found), 'a stale entry must fail'


def main():
    root = Path(__file__).resolve().parents[1]
    try:
        self_check()
    except AssertionError as error:
        print(f'Naming: the self-check failed: {error}.', file=sys.stderr)
        return 1
    try:
        baseline = load_baseline(root / BASELINE)
    except (ValueError, json.JSONDecodeError) as error:
        print(f'Naming: unreadable {BASELINE}: {error}', file=sys.stderr)
        return 1
    compliant, found = violations(root, baseline)
    for relative, problem, hint in found:
        print(f'{relative}: {problem}\n  {hint}', file=sys.stderr)
    if found:
        print(f'Naming: {len(found)} violation(s).', file=sys.stderr)
        return 1
    print(f'Naming: {compliant} compliant, baseline empty, 0 violations.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
