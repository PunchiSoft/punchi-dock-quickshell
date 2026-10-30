#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check the interaction patterns that made QML tests fail at random in CI.

Two rules, both derived from a real failure:

1. A wait for a delegate (`findChild(...) !== null`) must hand the reference to
   the caller. Resolving the same delegate again afterwards races the
   asynchronous model rebuild, which is how
   `test_containerSelectionKeepsEntriesOutOfThePopup` failed on a `verify()` with
   no message.
2. An explicit wait budget must stay below the deadline the isolated runner
   enforces (`scripts-dev/run-isolated.py` kills a test after 35 seconds), so a
   test cannot spend the whole budget waiting and report nothing.

Both rules start at zero violations and have no baseline: a hit is fixed in the
test, never recorded. `--self-check` proves the rules fire, so a rule that stops
matching cannot pass silently.
"""

from pathlib import Path
import re
import sys
import tempfile

# The isolated runner kills a test after this many seconds.
RUNNER_DEADLINE_MS = 35000
# A wait is matched with the delegate it resolves; the reference must live in the
# four lines after it, which is where the re-resolution used to sit.
RACE_WINDOW = 4
WAIT_LINE = re.compile(
    r'tryVerify|tryCompare|tryComp\w*|QTest\.qWaitFor', re.ASCII)
FIND_CHILD = re.compile(r'findChild\(\s*([^,()]+?)\s*,\s*"([^"]+)"\s*\)')
EXPLICIT_TIMEOUT = re.compile(
    r'try(?:Verify|Compare)\(.*?,\s*(\d{4,})\s*[,)]', re.ASCII)
RACE_HINT = ('capture the reference inside the wait: `let row = null; '
             'tryVerify(function() { row = findChild(...); return row !== null })`')
TIMEOUT_HINT = ('keep an explicit wait budget below the runner deadline of '
                f'{RUNNER_DEADLINE_MS} ms')


def qml_tests(root):
    """Yield every QML test file, sorted by path."""
    for directory in ('tests/qml', 'tests/runtime'):
        base = root / directory
        if base.is_dir():
            for path in sorted(base.rglob('*.qml')):
                yield path


CAPTURE = re.compile(r'^\s*(?!const\b|let\b|var\b|return\b)[\w.]+\s*=\s*findChild\(')


CLOSURE_OPEN = re.compile(r'tryVerify\(function\(\)\s*\{\s*$')


def delegate_waits(lines):
    """Yield (line index, ancestor, name) for each wait on a delegate.

    Only a `findChild` inside the wait's own call counts: on the same line, or
    inside the closure a `tryVerify(function() {` opens.
    """
    for index, line in enumerate(lines):
        found = FIND_CHILD.findall(line)
        if found and WAIT_LINE.search(line):
            yield index, found[0][0], found[0][1]
            continue
        if not CLOSURE_OPEN.search(line):
            continue
        for candidate in range(index + 1, min(index + RACE_WINDOW, len(lines))):
            if re.match(r'\s*\}', lines[candidate]):
                break
            found = FIND_CHILD.findall(lines[candidate])
            if found:
                yield candidate, found[0][0], found[0][1]
                break


def race_violations(path, lines):
    """Return the reference re-resolutions that follow a delegate wait."""
    found = []
    for resolve_index, ancestor, name in delegate_waits(lines):
        for offset in range(1, RACE_WINDOW + 1):
            candidate = resolve_index + offset
            if candidate >= len(lines):
                break
            if (ancestor, name) not in FIND_CHILD.findall(lines[candidate]):
                continue
            # Assigning the reference inside the wait is the fix, not the race.
            if CAPTURE.match(lines[candidate]):
                continue
            found.append((candidate + 1, name))
            break
    return found


def timeout_violations(lines):
    """Return the explicit waits that exceed the runner deadline."""
    found = []
    for index, line in enumerate(lines):
        match = EXPLICIT_TIMEOUT.search(line)
        if match and int(match[1]) >= RUNNER_DEADLINE_MS:
            found.append((index + 1, match[1]))
    return found


def check(root, files=None):
    """Return every violation as (path, line, detail, hint)."""
    violations = []
    for path in files if files is not None else qml_tests(root):
        lines = Path(path).read_text().splitlines()
        for line, name in race_violations(path, lines):
            violations.append((str(path), line, f'delegate "{name}" resolved again '
                                                'after the wait', RACE_HINT))
        for line, budget in timeout_violations(lines):
            violations.append((str(path), line, f'wait budget of {budget} ms',
                              TIMEOUT_HINT))
    return violations


SELF_CHECK_RACY = """\
function test_racy() {
    tryVerify(function() { return findChild(list, "row-1") !== null })
    const row = findChild(list, "row-1")
    mouseClick(row)
}
"""

SELF_CHECK_CAPTURED = """\
function test_captured() {
    let row = null
    tryVerify(function() {
        row = findChild(list, "row-1")
        return row !== null
    }, 5000, "the row is listed")
    mouseClick(row)
}
"""

SELF_CHECK_SLOW = """\
function test_slow() {
    tryCompare(session, "playing", false, 60000)
}
"""


def self_check():
    """Prove both rules fire on a racy fixture and pass a corrected one."""
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        racy = root / 'racy.qml'
        racy.write_text(SELF_CHECK_RACY)
        captured = root / 'captured.qml'
        captured.write_text(SELF_CHECK_CAPTURED)
        slow = root / 'slow.qml'
        slow.write_text(SELF_CHECK_SLOW)
        violations = check(root, files=[racy, captured, slow])
        reported = {(Path(path).name, line) for path, line, _, _ in violations}
        expected = {('racy.qml', 3), ('slow.qml', 2)}
        if reported != expected:
            print('Self-check failed: the rules reported '
                  f'{sorted(reported)} instead of {sorted(expected)}.', file=sys.stderr)
            return 1
    return 0


def main():
    root = Path(__file__).resolve().parents[1]
    # The self-check runs on every invocation, so a rule that stops matching cannot
    # pass the repository silently.
    if self_check():
        return 1
    violations = check(root)
    if not violations:
        print(f'Test timing: {sum(1 for _ in qml_tests(root))} QML test files follow '
              'the delegate-wait and wait-budget rules.')
        return 0
    for path, line, detail, hint in violations:
        print(f'{path}:{line}: {detail}. {hint}', file=sys.stderr)
    print(f'{len(violations)} test-timing violation(s).', file=sys.stderr)
    return 1


if __name__ == '__main__':
    raise SystemExit(main())
