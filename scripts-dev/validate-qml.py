#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Lint QML, reporting verified upstream metadata gaps without hiding them."""

import json
from pathlib import Path
import re
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_dir import resolve_build_dir  # noqa: E402


def main():
    root = Path(__file__).resolve().parents[1]
    files = [root / 'shell.qml']
    for directory in ('components', 'config', 'services', 'modules', 'adapters', 'tests/qml', 'tests/runtime', 'tests/folder-container'):
        files.extend(sorted((root / directory).rglob('*.qml')))
    result = subprocess.run([sys.argv[1], '-I', str(resolve_build_dir(root) / 'qml'), '--max-warnings', '0', *map(str, files)],
                            cwd=root, capture_output=True, text=True)
    output = result.stdout + result.stderr
    print(output, end='')
    diagnostics = re.findall(r'^(Warning|Error): (.*?):\d+:\d+: (.*) \[([^\]]+)\]$',
                             output, re.MULTILINE)
    expected = json.loads((root / 'tests/qmllint-upstream.json').read_text())
    actual = []
    for severity, path, message, category in diagnostics:
        actual.append(dict(severity=severity, file=str(Path(path).relative_to(root)),
                           message=message, category=category))
    # Every diagnostic stays visible. Only exact, documented upstream gaps are
    # accepted; new categories, files, messages, duplicates, or errors fail.
    unmatched = [item for item in actual if item not in expected]
    if len(re.findall(r'^(Warning|Error):', output, re.MULTILINE)) != len(actual):
        return 1
    if unmatched or len(actual) != len({json.dumps(item, sort_keys=True) for item in actual}):
        return 1
    if result.returncode and not actual:
        return result.returncode
    print(f'QML lint: {len(actual)} documented upstream metadata warnings; no new diagnostics.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
