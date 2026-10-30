#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Name every failing CTest case from the JUnit report in the job summary.

Without this, a red run shows only `Failing after 5m`: the job status hides which
test failed and the log has to be opened by hand. The script prints one GitHub
error annotation per failure and always exits 0, because the job that calls it has
already failed.
"""

from pathlib import Path
import sys
import xml.etree.ElementTree as ElementTree


def failures(report):
    """Yield (name, message) for each failing test case in the report."""
    for case in ElementTree.parse(report).iter('testcase'):
        failure = case.find('failure')
        if failure is not None:
            message = (failure.get('message') or 'failed').splitlines()
            yield case.get('name', 'unknown'), message[0] if message else 'failed'


def main():
    report = Path(sys.argv[1] if len(sys.argv) > 1 else 'build/ctest-junit.xml')
    if not report.is_file():
        print(f'{report} is missing; the failing tests stay unnamed.', file=sys.stderr)
        return 0
    found = list(failures(report))
    for name, message in found:
        print(f'::error title={name}::{message}')
    print(f'{len(found)} failing test(s) named from {report}.')
    return 0


SELF_CHECK = """\
<testsuites><testsuite>
  <testcase name="application_media"><failure message="property playing">
    at /src/tests/runtime/media/tst_media.qml:47</failure></testcase>
  <testcase name="application_items"/>
</testsuite></testsuites>
"""


def self_check(root):
    """Prove a failing case is named and a passing one is not."""
    report = root / 'report.xml'
    report.write_text(SELF_CHECK)
    found = list(failures(report))
    if found != [('application_media', 'property playing')]:
        print(f'Self-check failed: {found}.', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    if '--self-check' in sys.argv:
        import tempfile
        with tempfile.TemporaryDirectory() as directory:
            raise SystemExit(self_check(Path(directory)))
    raise SystemExit(main())
