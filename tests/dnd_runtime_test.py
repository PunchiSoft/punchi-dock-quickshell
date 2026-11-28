#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Read Plasma's effective Do Not Disturb state without changing it."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time


def ipc(config, method):
    return subprocess.run(['qs', 'ipc', '--path', str(config), 'call', 'dnd', method],
                          capture_output=True, text=True, timeout=3)


def main():
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix='punchi-dnd-runtime-') as directory:
        config = Path(directory) / 'shell.qml'
        config.write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import Punchi.Kde as Native
ShellRoot {
    Native.NotificationStateControl { id: dnd; monitoring: true }
    IpcHandler {
        target: "dnd"
        function state(): string {
            return JSON.stringify({available: dnd.available, inhibited: dnd.inhibited})
        }
    }
}
''')
        env = os.environ.copy()
        env.pop('QT_QUICK_CONTROLS_STYLE', None)
        env['QT_NO_XDG_DESKTOP_PORTAL'] = '1'
        log_path = Path(directory) / 'runtime.log'
        with log_path.open('w') as log:
            process = subprocess.Popen(['qs', '-p', str(config), '--no-color'],
                                       env=env, stdout=log, stderr=log)
            try:
                deadline = time.monotonic() + 8
                state = None
                while time.monotonic() < deadline:
                    result = ipc(config, 'state')
                    if result.returncode == 0:
                        try:
                            state = json.loads(result.stdout)
                        except json.JSONDecodeError:
                            state = None
                        if state is not None and state['available']:
                            break
                    if process.poll() is not None:
                        raise RuntimeError(log_path.read_text())
                    time.sleep(0.03)
                assert state is not None, log_path.read_text()
                assert state['available'] is True, state
                assert isinstance(state['inhibited'], bool), state
                print('Plasma Do Not Disturb effective state read-only: passed')
            finally:
                process.terminate()
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
