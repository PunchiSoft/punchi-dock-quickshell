#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Exercise the real entry point, scoped restore, and dock surface lifecycle."""

import json
from pathlib import Path
import re
import subprocess
import shutil
import tempfile
import sys
import time


def instances(output):
    if output.startswith("No running instances for "):
        return []
    return json.loads(output)


def check_log(output):
    if re.search(r'TypeError|ReferenceError|Binding loop|Failed to load|PUNCHI_SESSION_FAILED|\bERROR\b', output):
        raise RuntimeError(output)


def main():
    root = Path(__file__).resolve().parents[1]
    if '--isolated' not in sys.argv:
        return subprocess.run([
            sys.executable, str(root / 'scripts-dev/run-isolated.py'), '--session', '--',
            sys.executable, str(Path(__file__).resolve()), '--isolated',
        ]).returncode

    with tempfile.TemporaryDirectory(prefix='punchi-shell-other-') as temporary:
        unrelated = Path(temporary)
        (unrelated / 'shell.qml').write_text('import Quickshell\nShellRoot {}\n')
        foreign = subprocess.Popen(['qs', '--path', str(unrelated), '--no-color'],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            deadline = time.monotonic() + 8
            while time.monotonic() < deadline:
                listed = subprocess.run(['qs', 'list', '--path', str(unrelated), '--json'],
                                        capture_output=True, text=True, check=True)
                if instances(listed.stdout):
                    break
                if foreign.poll() is not None:
                    raise RuntimeError('Unrelated test configuration failed to start.')
                time.sleep(0.1)
            else:
                raise RuntimeError('Unrelated test configuration did not register.')
            run_checks(root)
            if foreign.poll() is not None:
                raise RuntimeError('Scoped restore stopped an unrelated configuration.')
            print('Unrelated Quickshell configuration preserved: passed')
        finally:
            foreign.terminate()
            try:
                foreign.wait(timeout=3)
            except subprocess.TimeoutExpired:
                foreign.kill()
                foreign.wait()
    return 0


def run_checks(root):
    process = subprocess.Popen(['bash', str(root / 'scripts-user/start.sh')],
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    try:
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            if process.poll() is not None:
                raise RuntimeError(process.stdout.read())
            result = subprocess.run(['qs', 'list', '--path', str(root), '--json'],
                                    capture_output=True, text=True, check=True)
            if instances(result.stdout):
                break
            time.sleep(0.1)
        else:
            raise RuntimeError('The shell instance did not register.')
        duplicate = subprocess.run(['bash', str(root / 'scripts-user/start.sh')],
                                   capture_output=True, text=True, timeout=8)
        if duplicate.returncode:
            raise RuntimeError(duplicate.stdout + duplicate.stderr)
        restored = subprocess.run(['bash', str(root / 'scripts-user/restore-kde.sh')],
                                  capture_output=True, text=True, timeout=8, check=True)
        output, _ = process.communicate(timeout=8)
        check_log(output)
        if process.returncode != 0:
            raise RuntimeError(f'Shell shutdown returned {process.returncode}: {output}')
        remaining = subprocess.run(['qs', 'list', '--path', str(root), '--json'],
                                   capture_output=True, text=True, check=True)
        if instances(remaining.stdout):
            raise RuntimeError('The restore script left a running shell instance.')
        subprocess.run(['bash', str(root / 'scripts-user/restore-kde.sh')],
                       capture_output=True, text=True, timeout=8, check=True)
        print('Entry point, duplicate prevention, scoped restore, and repeated restore: passed')
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()

    # Quickshell scans only inside its selected config root. Assemble the fixture
    # with the same modules under a parent-owned temporary root.
    with tempfile.TemporaryDirectory(prefix='punchi-shell-session-') as temporary:
        config = Path(temporary)
        for directory in ('components', 'config', 'services', 'modules', 'adapters'):
            shutil.copytree(root / directory, config / directory)
        fixture = (root / 'tests/runtime/shell.qml').read_text()
        (config / 'shell.qml').write_text(fixture.replace('../../modules/dock', 'modules/dock'))
        result = subprocess.run(['qs', '--path', str(config), '--no-color'],
                                capture_output=True, text=True, timeout=8)
    output = result.stdout + result.stderr
    check_log(output)
    if result.returncode or 'PUNCHI_SESSION_PASS' not in output:
        raise RuntimeError(output)
    print('Wayland surface, rendered frame, hide, reopen, and shutdown: passed')
    for line in output.splitlines():
        if 'PUNCHI_FRAME_RENDERED' in line:
            print(line)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
