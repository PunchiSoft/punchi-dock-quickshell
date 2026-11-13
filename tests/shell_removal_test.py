#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Reject removal commands that can escape their intended path.

The static rules cover the two idioms that turn an empty variable into a
disaster: a removal target ending in `/*` after a quoted variable, and a
recursive removal without `--`. When ShellCheck is installed, the same files are
checked for the quoting and expansion codes that own those rules
(SC2115, SC2086, SC2046, SC2068).
"""

from pathlib import Path
from typing import List, Tuple
import os
import re
import shutil
import subprocess
import sys


PROJECT = Path(__file__).resolve().parents[1]
DIRECTORIES = ('scripts-user', 'scripts-dev')
REMOVAL = re.compile(r'\brm\s+-[A-Za-z]', re.ASCII)
END_OF_OPTIONS = re.compile(r'(^|\s)--(\s|$)', re.ASCII)
EMPTY_ROOT_GLOB = re.compile(
    r'"\$(?:\{)?[A-Za-z_][A-Za-z0-9_]*(?:\})?"\s*/\*', re.ASCII)
SHELLCHECK_CODES = 'SC2115,SC2086,SC2046,SC2068'


def shell_files() -> List[Path]:
    found: List[Path] = []
    for name in DIRECTORIES:
        base = PROJECT / name
        if base.is_dir():
            found.extend(sorted(base.rglob('*.sh')))
    return found


def static_violations(files: List[Path]) -> List[Tuple[Path, int, str]]:
    violations: List[Tuple[Path, int, str]] = []
    for path in files:
        for number, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
            if line.lstrip().startswith('#'):
                continue
            if '--no-preserve-root' in line:
                violations.append((path, number, 'recursive removal may not disable root protection'))
            match = REMOVAL.search(line)
            if not match:
                continue
            command = line[match.start():]
            if not END_OF_OPTIONS.search(command):
                violations.append((path, number, 'removal is missing the -- option terminator'))
            if EMPTY_ROOT_GLOB.search(command):
                violations.append((path, number, 'removal target expands to /* when the variable is empty'))
    return violations


def shellcheck_output(files: List[Path]) -> Tuple[bool, str]:
    tool = os.environ.get('PUNCHI_SHELLCHECK') or shutil.which('shellcheck')
    if not tool:
        return False, ''
    result = subprocess.run(
        [tool, '-x', '-i', SHELLCHECK_CODES, '-f', 'gcc', *map(str, files)],
        check=False, capture_output=True, text=True, timeout=30,
    )
    return True, result.stdout + result.stderr


def main() -> int:
    files = shell_files()
    if not files:
        print('Shell removal: no shell scripts found', file=sys.stderr)
        return 1
    violations = static_violations(files)
    for path, line, detail in violations:
        print(f'{path}:{line}: {detail}', file=sys.stderr)

    ran_shellcheck, output = shellcheck_output(files)
    if output.strip():
        print(output, end='' if output.endswith('\n') else '\n', file=sys.stderr)

    if violations or output.strip():
        return 1
    tool = 'ShellCheck' if ran_shellcheck else 'static rules (ShellCheck not installed)'
    print(f'Shell removal: {len(files)} scripts passed with {tool}.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
