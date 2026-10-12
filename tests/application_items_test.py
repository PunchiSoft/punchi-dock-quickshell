#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Seed owned desktop entries, then exercise the actual item editor and launch."""
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import json
import time
from launch_runtime_test import owned_processes


def main():
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix='punchi-add-item-') as directory:
        owned = Path(directory)
        capture = owned / 'opened.jsonl'
        script = owned / 'capture.py'
        script.write_text('import json, sys\nwith open(sys.argv[1], "a") as output:\n output.write(json.dumps(sys.argv[2:]) + "\\n")\n')
        applications = Path(os.environ['XDG_DATA_HOME']) / 'applications'
        applications.mkdir()
        for suffix, hidden in [('sentinel', False), ('hidden', True)]:
            (applications / f'punchi-add-{suffix}.desktop').write_text('[Desktop Entry]\nType=Application\n'
                f'Name=Punchi owned {suffix}\nComment=Owned application fixture\nIcon=utilities-terminal\n'
                f'Exec=/usr/bin/python3 "{script}" "{capture}" %U\nTerminal=false\nStartupNotify=false\n'
                f'NoDisplay={str(hidden).lower()}\n')
        indexer = shutil.which('kbuildsycoca6')
        assert indexer, 'The KDE application cache builder is required for this owned fixture'
        subprocess.run([indexer, '--noincremental'], check=True, capture_output=True, text=True, timeout=10)
        runner = shutil.which('qmltestrunner') or '/usr/lib64/qt6/bin/qmltestrunner'
        try:
            result = subprocess.run([runner, '-input', str(root / 'tests/runtime/application-items')],
                                    capture_output=True, text=True, timeout=20)
            print(result.stdout + result.stderr, end='')
            assert result.returncode == 0, result.stdout + result.stderr
            deadline = time.monotonic() + 3
            while not capture.exists() and time.monotonic() < deadline:
                time.sleep(0.05)
            assert capture.exists() and [json.loads(line) for line in capture.read_text().splitlines()] == [[]]
            print('Owned item editor: search, draft/discard, duplicate rejection, live dock, persistence and KIO launch passed.')
        finally:
            for pid in owned_processes(script):
                try:
                    os.kill(pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
            deadline = time.monotonic() + 2
            while owned_processes(script) and time.monotonic() < deadline:
                time.sleep(0.05)
            if owned_processes(script):
                raise RuntimeError('Item sentinel cleanup failed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
