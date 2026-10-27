#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check the owned settings file read path, including legacy migration bounds."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time


def main():
    root = Path(__file__).resolve().parents[1]
    assert os.environ.get('QT_QPA_PLATFORM') == 'offscreen', 'Use the isolated offscreen runner.'
    with tempfile.TemporaryDirectory(prefix='punchi-settings-store-') as directory:
        work = Path(directory)
        config = work / 'config-tree'
        config.mkdir()
        for name in ('config', 'services', 'adapters'):
            shutil.copytree(root / name, config / name)
        pragmas = '\n'.join(line for line in (root / 'shell.qml').read_text().splitlines()
                            if line.startswith('//@ pragma '))
        (config / 'shell.qml').write_text(pragmas + '\n' + '''import QtQuick
import Quickshell
import Quickshell.Io
import "config"
import "services"
ShellRoot {
    ShellSettings { id: settings }
    SettingsStore { id: store; settings: settings }
    IpcHandler {
        target: "store"
        function snapshot(): string {
            return JSON.stringify({ready: store.ready, settings: settings.snapshot()})
        }
    }
}
''')
        profile = work / 'profile'
        profile.mkdir()
        env = os.environ.copy()
        env['PUNCHI_PROFILE_DIR'] = str(profile)
        env.pop('WAYLAND_DISPLAY', None)
        log_path = work / 'runtime.log'

        def run_shell(predicate):
            with log_path.open('w') as log:
                process = subprocess.Popen(['qs', '--path', str(config), '--no-color'],
                                           env=env, stdout=log, stderr=log)
                try:
                    deadline = time.monotonic() + 8
                    while time.monotonic() < deadline:
                        if process.poll() is not None:
                            raise RuntimeError(log_path.read_text())
                        result = subprocess.run(
                            ['qs', 'ipc', '--path', str(config), 'call', 'store', 'snapshot'],
                            capture_output=True, text=True, timeout=3)
                        if result.returncode == 0:
                            try:
                                state = json.loads(result.stdout)
                            except json.JSONDecodeError:
                                state = None
                            if state and state['ready'] and predicate(state):
                                return state
                        time.sleep(0.05)
                    raise RuntimeError(log_path.read_text() + '\nSettings store did not start.')
                finally:
                    process.terminate()
                    try:
                        process.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()

        legacy = profile / 'punchi-shell.json'
        current = profile / 'punchi-dock-quickshell.json'
        legacy.write_text(json.dumps({'version': 11, 'sizePercent': 125, 'dockEdge': 'left'}))
        state = run_shell(lambda value: value['settings']['sizePercent'] == 125)
        assert state['settings']['dockEdge'] == 'left', state
        deadline = time.monotonic() + 3
        while not current.exists() and time.monotonic() < deadline:
            time.sleep(0.02)
        assert current.exists(), 'Legacy migration did not write the current profile'
        assert legacy.exists(), 'Legacy migration removed the backup'
        assert json.loads(current.read_text())['sizePercent'] == 125

        legacy.write_text(json.dumps({'version': 11, 'sizePercent': 80, 'dockEdge': 'right'}))
        current.write_text(' ' * (256 * 1024 + 1))
        state = run_shell(lambda value: value['settings']['sizePercent'] == 100)
        assert state['settings']['dockEdge'] == 'bottom', state
        assert 'settings read failed: too-large' in log_path.read_text()
        assert current.stat().st_size == 256 * 1024 + 1, 'An unreadable current profile was overwritten'
        assert json.loads(legacy.read_text())['sizePercent'] == 80, 'Legacy fallback ran after a read error'
        print('Owned settings file: bounded read and legacy migration passed')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
