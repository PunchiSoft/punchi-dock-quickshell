#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Run model tests on a bus with no host service auto-activation directories."""
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
from xml.sax.saxutils import escape


def interrupted(signum, _frame):
    raise KeyboardInterrupt(f'Private bus interrupted by signal {signum}.')


def main():
    if len(sys.argv) < 2:
        raise SystemExit('A test command is required.')
    for signum in (signal.SIGTERM, signal.SIGHUP):
        signal.signal(signum, interrupted)
    with tempfile.TemporaryDirectory(prefix='punchi-model-bus-') as directory:
        root = Path(directory)
        config = root / 'bus.conf'
        config.write_text('<busconfig><type>session</type><listen>unix:tmpdir='
            + escape(directory) + '</listen><auth>EXTERNAL</auth>'
            '<policy context="default"><allow own="*"/>'
            '<allow send_destination="*" eavesdrop="true"/>'
            '<allow eavesdrop="true"/></policy></busconfig>')
        process = subprocess.Popen(['dbus-run-session', '--config-file=' + str(config),
            '--', *sys.argv[1:]], start_new_session=True)
        try:
            return process.wait(timeout=30)
        finally:
            try: os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError: pass
            try: process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
            try: os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError: pass


if __name__ == '__main__':
    raise SystemExit(main())
