#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check the quarantine list that keeps a known flake out of the blocking CI run.

`tests/flaky-tests.json` must stay empty: a flaky test is stabilized, and
`tests/test_timing_test.py` removes the pattern that made it flaky. Quarantine is
for the residue that needs a real investigation, so an entry has to carry an open
issue number, a written reason and an expiry date. `scripts-dev/ci-headless.sh`
excludes these tests from the blocking run and re-runs them on their own, where a
failure warns instead of failing the pipeline.

An entry without a reason, without an issue, with a malformed date, with a past
date, or naming the same test twice fails this check.
"""

from pathlib import Path
import datetime
import json
import re
import sys
import tempfile

QUARANTINE = Path('tests/flaky-tests.json')
TEST_NAME = re.compile(r'[A-Za-z0-9_.-]+')


def load(root, quarantine):
    return json.loads((root / quarantine).read_text())


def check(root, today=None, quarantine=QUARANTINE):
    """Return the problems with the quarantine list, empty when it is valid."""
    today = today or datetime.date.today()
    document = load(root, quarantine)
    problems = []
    seen = set()
    for index, entry in enumerate(document.get('quarantined', [])):
        where = f'{quarantine}#quarantined[{index}]'
        test = entry.get('test', '')
        if not TEST_NAME.fullmatch(str(test)):
            problems.append(f'{where}: "{test}" is not a CTest name')
        elif test in seen:
            problems.append(f'{where}: "{test}" is listed twice')
        else:
            seen.add(test)
        issue = entry.get('issue')
        if not isinstance(issue, int) or issue <= 0:
            problems.append(f'{where}: "issue" must be an open issue number')
        if not str(entry.get('reason', '')).strip():
            problems.append(f'{where}: "reason" must say why the test is quarantined')
        expires = str(entry.get('expires', ''))
        try:
            date = datetime.date.fromisoformat(expires)
        except ValueError:
            problems.append(f'{where}: "expires" must be a YYYY-MM-DD date')
            continue
        if date <= today:
            problems.append(f'{where}: the quarantine expired on {expires}; '
                            'stabilize the test or extend it with a reason')
    return problems


SELF_CHECK_EMPTY = '{"quarantined": []}'
SELF_CHECK_EXPIRED = json.dumps({'quarantined': [
    {'test': 'application_media', 'issue': 0, 'reason': '', 'expires': '2000-01-01'},
    {'test': 'application_media', 'issue': 12, 'reason': 'slow runner', 'expires': '2999-01-01'},
]})


def self_check(root):
    """Prove an empty list passes and a stale, duplicated entry fails."""
    documents = {'empty.json': SELF_CHECK_EMPTY, 'expired.json': SELF_CHECK_EXPIRED}
    for name, content in documents.items():
        (root / name).write_text(content)
    if check(root, quarantine=Path('empty.json')):
        print('Self-check failed: an empty quarantine list must pass.', file=sys.stderr)
        return 1
    problems = check(root, quarantine=Path('expired.json'))
    expected = ('issue', 'reason', 'expired', 'twice')
    if not all(any(key in problem for problem in problems) for key in expected):
        print(f'Self-check failed: expected every rule to fire, got {problems}.',
              file=sys.stderr)
        return 1
    return 0


def main():
    root = Path(__file__).resolve().parents[1]
    # The self-check runs on every invocation, so a rule that stops matching cannot
    # pass the repository silently.
    with tempfile.TemporaryDirectory() as directory:
        if self_check(Path(directory)):
            return 1
    problems = check(root)
    if not problems:
        print('Quarantine: tests/flaky-tests.json carries no stale or malformed entry.')
        return 0
    for problem in problems:
        print(problem, file=sys.stderr)
    return 1


if __name__ == '__main__':
    raise SystemExit(main())
