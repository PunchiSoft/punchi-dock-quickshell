#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Prove the settings writer bounds the profile in UTF-8 bytes."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time


MAXIMUM_BYTES = 256 * 1024
VALID_ENTRIES = 300
OVER_LIMIT_ENTRIES = 1200
ENTRY_WIDTH = 80


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    assert os.environ.get('QT_QPA_PLATFORM') == 'offscreen', \
        'Use the isolated offscreen runner.'
    with tempfile.TemporaryDirectory(prefix='punchi-settings-utf8-') as directory:
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
    PunchiShellSettings { id: settings }
    PunchiSettingsStore { id: store; settings: settings }
    IpcHandler {
        target: "store"
        function summary(): string {
            const containers = settings.containers
            const hidden = containers && containers.length
                ? containers[0].hiddenEntries || [] : []
            return JSON.stringify({ready: store.ready, sizePercent: settings.sizePercent,
                hiddenCount: hidden.length,
                hiddenFirst: hidden.length ? hidden[0] : ""})
        }
        function setHidden(count: string, width: string): bool {
            const nameCount = parseInt(count, 10)
            const nameWidth = parseInt(width, 10)
            if (!Number.isInteger(nameCount) || !Number.isInteger(nameWidth)
                    || nameCount <= 0 || nameWidth <= 0) return false
            const text = "漢".repeat(nameWidth)
            const names = []
            for (let index = 0; index < nameCount; ++index)
                names.push(text + String(index))
            const next = JSON.parse(JSON.stringify(settings.containers))
            if (!next || next.length === 0) return false
            next[0].hiddenEntries = names
            settings.containers = next
            return true
        }
    }
}
''')
        profile = work / 'profile'
        profile.mkdir()
        path = profile / 'punchi-dock-quickshell.json'
        path.write_text(json.dumps({
            'version': 17,
            'sizePercent': 100,
            'containers': [{
                'id': 'downloads', 'path': '', 'title': 'Downloads',
                'icon': 'folder-downloads',
            }],
        }))
        environment = os.environ.copy()
        environment['PUNCHI_PROFILE_DIR'] = str(profile)
        environment.pop('WAYLAND_DISPLAY', None)
        log_path = work / 'runtime.log'
        process = None

        def start() -> dict:
            nonlocal process
            log = log_path.open('w')
            process = subprocess.Popen(
                ['qs', '--path', str(config), '--no-color'],
                env=environment, stdout=log, stderr=log)
            log.close()
            deadline = time.monotonic() + 8
            while time.monotonic() < deadline:
                if process.poll() is not None:
                    raise RuntimeError(log_path.read_text())
                result = subprocess.run(
                    ['qs', 'ipc', '--path', str(config), 'call', 'store', 'summary'],
                    capture_output=True, text=True, timeout=3)
                if result.returncode == 0:
                    try:
                        state = json.loads(result.stdout)
                    except json.JSONDecodeError:
                        state = None
                    if state and state['ready']:
                        return state
                time.sleep(0.05)
            raise RuntimeError(log_path.read_text() + '\nSettings store did not start.')

        def stop() -> None:
            nonlocal process
            if process is None:
                return
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            process = None

        def call(method: str, *arguments: str) -> dict:
            result = subprocess.run(
                ['qs', 'ipc', '--path', str(config), 'call', 'store', method,
                 *arguments],
                capture_output=True, text=True, timeout=10)
            assert result.returncode == 0, result.stderr + log_path.read_text()
            return json.loads(result.stdout)

        def profile_document() -> dict:
            try:
                return json.loads(path.read_text())
            except (OSError, json.JSONDecodeError):
                return {}

        def wait_for_hidden(count: int) -> dict:
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                document = profile_document()
                containers = document.get('containers') or []
                hidden = containers[0].get('hiddenEntries', []) if containers else []
                if len(hidden) == count:
                    return document
                time.sleep(0.05)
            raise AssertionError(f'Profile did not reach {count} hidden entries: '
                                 f'{path.stat().st_size if path.exists() else 0} bytes')

        try:
            state = start()
            assert state['hiddenCount'] == 0 and state['sizePercent'] == 100, state

            assert call('setHidden', str(VALID_ENTRIES), str(ENTRY_WIDTH)) is True
            valid = wait_for_hidden(VALID_ENTRIES)
            valid_size = path.stat().st_size
            assert valid_size <= MAXIMUM_BYTES, valid_size
            assert valid_size > 60000, valid_size
            assert valid['sizePercent'] == 100, valid
            valid_first = valid['containers'][0]['hiddenEntries'][0]
            stop()

            state = start()
            assert state['hiddenCount'] == VALID_ENTRIES, state
            assert state['hiddenFirst'] == valid_first, state
            assert state['sizePercent'] == 100, state

            assert call('setHidden', str(OVER_LIMIT_ENTRIES), str(ENTRY_WIDTH)) is True
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                if path.stat().st_size > MAXIMUM_BYTES:
                    break
                if 'settings profile exceeds the storage limit' in log_path.read_text():
                    break
                time.sleep(0.05)
            assert path.stat().st_size <= MAXIMUM_BYTES, path.stat().st_size
            assert 'settings profile exceeds the storage limit' in log_path.read_text(), \
                'The over-limit save did not report the storage limit'
            kept = profile_document()
            kept_hidden = kept.get('containers', [{}])[0].get('hiddenEntries', [])
            assert len(kept_hidden) == VALID_ENTRIES, len(kept_hidden)
            assert kept.get('sizePercent') == 100, kept.get('sizePercent')

            stop()
            state = start()
            assert state['hiddenCount'] == VALID_ENTRIES, state
            assert state['sizePercent'] == 100, state
            print('Settings profile: UTF-8 byte limit accepted a multibyte profile '
                  'and preserved the previous file when the next save exceeded it.')
        finally:
            stop()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
