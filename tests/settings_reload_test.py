#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Observe preference preservation across actual Quickshell engine reloads."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time


def ipc(config, method, *args):
    return subprocess.run(['qs', 'ipc', '--path', str(config), 'call', 'probe', method, *args],
                          capture_output=True, text=True, timeout=3)


def main():
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix='punchi-shell-reload-') as directory:
        config = Path(directory)
        for name in ('config', 'services', 'adapters'):
            shutil.copytree(root / name, config / name)
        (config / 'shell.qml').write_text('''import QtQml
import Quickshell
import Quickshell.Io
import "config"
import "services"
ShellRoot {
    ShellSettings { id: settings }
    SettingsStore { id: store; settings: settings }
    PersistentProperties {
        id: generation
        reloadableId: "probe-generation"
        property int count: 0
        onLoaded: count += 1
    }
    IpcHandler {
        target: "probe"
        function snapshot(): string {
            return JSON.stringify({ready: store.ready, generation: generation.count,
                preferences: settings.snapshot()})
        }
        function update(): bool {
            settings.panelMode = "autohide"
            settings.sizePercent = 125
            return true
        }
        function reload(): bool { Quickshell.reload(false); return true }
    }
}
''')
        env = os.environ.copy()
        env['PUNCHI_DOCK_MODE'] = 'desktop'
        log_path = config / 'runtime.log'
        with log_path.open('w') as log:
            process = subprocess.Popen(['qs', '--path', str(config), '--no-color'],
                                       env=env, stdout=log, stderr=log)
            try:
                def state_when(predicate):
                    deadline = time.monotonic() + 5
                    while time.monotonic() < deadline:
                        result = ipc(config, 'snapshot')
                        if result.returncode == 0:
                            try:
                                state = json.loads(result.stdout)
                            except json.JSONDecodeError:
                                state = None
                            if state is not None and predicate(state):
                                return state
                        if process.poll() is not None:
                            raise RuntimeError(log_path.read_text())
                        time.sleep(0.03)
                    raise RuntimeError(log_path.read_text() + '\nReload probe timed out.')
                initial = state_when(lambda state: state['ready'])
                assert initial['preferences']['panelMode'] == 'dodge-windows', initial
                assert json.loads(ipc(config, 'update').stdout) is True
                assert state_when(lambda state: state['ready'])['preferences']['sizePercent'] == 125
                for count in (2, 3):
                    assert ipc(config, 'reload').returncode == 0
                    state = state_when(lambda state: state['generation'] >= count and state['ready'])
                    assert state['preferences']['panelMode'] == 'autohide', state
                    assert state['preferences']['sizePercent'] == 125, state
                print('Startup override once and live preferences across repeated Quickshell reload: passed')
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
