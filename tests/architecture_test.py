#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check the QML layer direction described in AGENTS.md.

Reads the quoted relative imports of every QML file in a layer directory and
fails when one reaches a layer it must not know about. Test fixtures are not
scanned: they legitimately import several layers at once.
"""

from pathlib import Path
import json
import re
import sys

LAYERS = ('components', 'config', 'services', 'modules', 'adapters')
# Layer -> layers it must never import through a quoted relative import. The
# flow is view intent -> service -> adapter, so a lower layer may not reach up:
# `modules` stays absent from this map because a feature module may use every
# layer below it.
FORBIDDEN = {
    'services': ('modules', 'components'),
    'adapters': ('services', 'modules', 'components', 'config'),
    'components': ('modules', 'services', 'adapters'),
    'config': ('modules', 'services', 'adapters'),
}
IMPORT = re.compile(r'^\s*import\s+"(?P<path>[^"]+)"')
# A root-level declaration in shell.qml would move composition into logic. The
# pattern anchors on the four-space indentation of a direct child of the root
# object, so nested handlers inside an instance stay valid.
# Up to six spaces keeps a shallow declaration honest without matching the
# eight-space handler of a nested object such as Connections.
SHELL_ROOT_DECLARATION = re.compile(r'^ {0,6}(?:readonly\s+)?(?:property|function)\b')
SHELL_LINE_LIMIT = 140
ALLOWLIST = Path('tests/architecture-allowlist.json')


def relative(path, root):
    try:
        return path.resolve().relative_to(root).as_posix()
    except ValueError:
        return None


def layer_imports(path, root):
    """Yield (line_number, import_text, target_layer_or_None, escapes_root)."""
    for number, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
        match = IMPORT.match(line)
        if not match:
            continue
        target = relative(path.parent / match.group('path'), root)
        if target is None:
            yield number, match.group('path'), None, True
            continue
        parts = Path(target).parts
        # An import of the repository root itself has no layer to classify.
        top = parts[0] if parts else ''
        yield number, match.group('path'), top, False


def main():
    root = Path(__file__).resolve().parents[1]
    allowlist = json.loads((root / ALLOWLIST).read_text())
    allowed = {(entry['file'], entry['import']): entry['reason'] for entry in allowlist}
    for entry in allowlist:
        if not entry.get('reason', '').strip():
            print(f'Architecture: allowlist entry without a reason: {entry}', file=sys.stderr)
            return 1
    violations, used, files, edges = [], set(), 0, 0
    for layer in LAYERS:
        for path in sorted((root / layer).rglob('*.qml')):
            files += 1
            for number, target, top, escapes in layer_imports(path, root):
                source = relative(path, root)
                if escapes:
                    violations.append((source, number, target, 'import outside the repository',
                        'a quoted import must stay inside the repository root'))
                    continue
                if top == layer or top not in LAYERS:
                    continue
                edges += 1
                forbidden = FORBIDDEN.get(layer, ())
                if top not in forbidden:
                    continue
                if (source, target) in allowed:
                    used.add((source, target))
                    continue
                violations.append((source, number, target, f'{layer} may not import {top}',
                    'route the call through a service, an adapter or a shared primitive'))
    for source, target in allowed.keys() - used:
        violations.append((source, 0, target, 'stale allowlist entry',
            'remove it: the import is gone or already allowed'))
    shell = (root / 'shell.qml').read_text(encoding='utf-8').splitlines()
    if len(shell) > SHELL_LINE_LIMIT:
        violations.append(('shell.qml', len(shell), '', f'{len(shell)} lines over the {SHELL_LINE_LIMIT} limit',
            'move feature logic into modules/'))
    for number, line in enumerate(shell, 1):
        if SHELL_ROOT_DECLARATION.match(line):
            violations.append(('shell.qml', number, '',
                f'root-level declaration: {line.strip()}',
                'shell.qml only composes; put state in a service and logic in a module'))
    for source, number, target, problem, hint in violations:
        where = f'{source}:{number}' if number else source
        detail = f'import "{target}": {problem}' if target else problem
        print(f'{where}: {detail}\n  {hint}', file=sys.stderr)
    if violations:
        print(f'Architecture: {len(violations)} violation(s).', file=sys.stderr)
        return 1
    print(f'Architecture: {files} QML files, {edges} layer imports, '
          f'{len(allowed)} allowlisted, 0 violations.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
