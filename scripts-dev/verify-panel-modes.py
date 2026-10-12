#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify live panel modes and actual layer-shell requests in an owned session."""

import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time


def call(config, function, *arguments):
    return subprocess.run(['qs', 'ipc', '--path', str(config), 'call', 'dock', function,
                           *arguments], capture_output=True, text=True, timeout=3)


def main():
    root = Path(__file__).resolve().parents[1]
    if '--isolated' not in sys.argv:
        return subprocess.run([
            sys.executable, str(root / 'scripts-dev/run-isolated.py'), '--session', '--',
            sys.executable, str(Path(__file__).resolve()), '--isolated',
        ]).returncode
    with tempfile.TemporaryDirectory(prefix='punchi-shell-panel-modes-') as temporary:
        config = Path(temporary)
        for directory in ('components', 'config', 'services', 'modules', 'adapters', 'scripts-user'):
            shutil.copytree(root / directory, config / directory)
        (config / 'build').mkdir()
        (config / 'build/qml').symlink_to(root / 'build/qml', target_is_directory=True)
        (config / 'build/punchi-window-state').symlink_to(root / 'build/punchi-window-state')
        (config / 'shell.qml').write_text('import Quickshell\nimport Quickshell.Io\n'
            'import "modules/dock"\nShellRoot { Dock { id: dock }\n'
            'IpcHandler { target: "probe"; function dismiss(): bool { dock.visible = false; return true } } }\n')
        log_path = config / 'wayland.log'
        env = os.environ.copy()
        env['WAYLAND_DEBUG'] = 'client'
        env['PUNCHI_DOCK_MODE'] = 'overlay'
        with log_path.open('w') as log:
            process = subprocess.Popen(['bash', str(config / 'scripts-user/start.sh'), 'overlay'],
                                       env=env, stdout=log, stderr=log)
            try:
                deadline = time.monotonic() + 5
                while time.monotonic() < deadline:
                    result = call(config, 'snapshot')
                    if result.returncode == 0:
                        break
                    if process.poll() is not None:
                        raise RuntimeError(log_path.read_text())
                    time.sleep(0.05)
                else:
                    raise RuntimeError('The dock IPC did not register.')
                initial = json.loads(result.stdout)
                assert initial['mode'] == 'overlay' and initial['exclusiveZone'] == 0, initial
                for mode, layer in [('reserve', 2), ('autohide', 2), ('dodge-windows', 2), ('overlay', 2)]:
                    result = subprocess.run(['bash', str(config / 'scripts-user/start.sh'), mode],
                                            capture_output=True, text=True, timeout=3)
                    assert result.returncode == 0 and json.loads(result.stdout) is True, result.stdout
                    state = json.loads(call(config, 'snapshot').stdout)
                    assert state['mode'] == mode and state['layer'] == layer, state
                    if mode == 'reserve':
                        assert state['baseHeight'] <= state['exclusiveZone'] < state['windowHeight'], state
                    else:
                        assert state['exclusiveZone'] == 0, state
                    if mode == 'autohide':
                        samples = []
                        deadline = time.monotonic() + 3
                        while time.monotonic() < deadline:
                            state = json.loads(call(config, 'snapshot').stdout)
                            samples.append(state)
                            if not state['surfaceVisible']:
                                break
                            time.sleep(0.03)
                        else:
                            raise RuntimeError('Automatic hiding did not finish.')
                        assert 0 < state['windowHeight'] < state['baseHeight'], state
                        assert state['opacity'] == 0 and state['slideProgress'] == 0, state
                        assert state['slideOffset'] == state['slideDistance'], state
                        if not state['reducedMotion']:
                            moving = [sample for sample in samples if 0 < sample['slideProgress'] < 1]
                            assert moving, 'No intermediate slide was observed.'
                            for sample in moving:
                                assert sample['surfaceVisible'] and sample['opacity'] == 1, sample
                                assert 0 < sample['sceneY'] - sample['restingSceneY'] < sample['slideDistance'], sample
                                assert math.isclose(sample['sceneY'], sample['restingSceneY'] + sample['slideOffset'], rel_tol=1e-6, abs_tol=1e-5), sample
                                assert sample['windowHeight'] > sample['baseHeight'], sample
                        assert json.loads(call(config, 'revealDock').stdout) is True
                        shown = json.loads(call(config, 'snapshot').stdout)
                        assert shown['surfaceVisible'] and shown['windowHeight'] > shown['baseHeight'], shown
                    print('Panel mode:',  json.dumps(state, sort_keys=True))
                    # Allow compositor commits; this is not a production animation loop.
                    time.sleep(0.15)
                legacy = subprocess.run(['bash', str(config / 'scripts-user/start.sh'), 'desktop'],
                                        capture_output=True, text=True, timeout=3)
                assert legacy.returncode == 0 and json.loads(legacy.stdout) is True, legacy.stdout
                migrated = json.loads(call(config, 'snapshot').stdout)
                assert migrated['mode'] == 'dodge-windows' and migrated['layer'] == 2, migrated
                assert migrated['exclusiveZone'] == 0, migrated
                rejected = subprocess.run(['bash', str(config / 'scripts-user/start.sh'), 'dodge'],
                                          capture_output=True, text=True, timeout=3)
                assert rejected.returncode == 2
                before = json.loads(call(config, 'snapshot').stdout)
                invalid = call(config, 'setMode', 'dodge')
                assert json.loads(invalid.stdout) is False
                assert json.loads(call(config, 'snapshot').stdout) == before
                dismissed = subprocess.run(['qs', 'ipc', '--path', str(config), 'call', 'probe', 'dismiss'],
                                           capture_output=True, text=True, timeout=3)
                assert json.loads(dismissed.stdout) is True
                assert json.loads(call(config, 'snapshot').stdout)['visible'] is False
                recovered = subprocess.run(['bash', str(config / 'scripts-user/start.sh')],
                                           capture_output=True, text=True, timeout=3)
                assert recovered.returncode == 0 and json.loads(recovered.stdout) is True, recovered.stdout
                assert json.loads(call(config, 'snapshot').stdout)['visible'] is True
                listed = subprocess.run(['qs', 'list', '--path', str(config), '--json'],
                                        capture_output=True, text=True, timeout=3)
                assert len(json.loads(listed.stdout)) == 1
                print('Repeated start recovers a dismissed dock without duplication: passed')
            finally:
                process.terminate()
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        output = log_path.read_text()
        if re.search(r'\bERROR\b|TypeError|ReferenceError|Binding loop|Failed to load', output):
            raise RuntimeError(output)
        assert re.search(r'\.set_exclusive_zone\([1-9]\d*\)', output), 'No reservation request reached Wayland.'
        assert '.set_exclusive_zone(-1)' in output, 'Auto-hide did not reach the physical edge.'
        assert '.set_exclusive_zone(0)' in output, 'No zero reservation reached Wayland.'
        assert ('.set_layer(2)' in output
                or re.search(r'\.get_layer_surface\([^\n]+, 2, "dock"\)', output)), output
        assert '.set_layer(1)' not in output, 'Retired Bottom stacking was requested.'
        assert not re.search(r'\.get_layer_surface\([^\n]+, 1, "dock"\)', output), output
        print('Live mode bindings, invalid-mode rejection, and layer-shell protocol commits: passed')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
