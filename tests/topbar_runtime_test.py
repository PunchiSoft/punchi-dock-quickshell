#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Observe the top panel on a real KWin: mount, reservation and teardown.

The probe owns a temporary profile and XDG tree, connects to the existing
compositor through the socket the isolated runner exposes, and never changes
the user's Plasma configuration or panels. It asserts only layer-shell and IPC
state; visual appearance is a separate, manual observation.
"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time


def ipc(config, method):
    return subprocess.run(['qs', 'ipc', '--path', str(config), 'call', 'topbar', method],
                          capture_output=True, text=True, timeout=3)


def main():
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix='punchi-topbar-runtime-') as directory:
        config = Path(directory)
        for name in ('modules', 'components', 'config', 'services', 'adapters'):
            shutil.copytree(root / name, config / name)
        pragmas = '\n'.join(line for line in (root / 'shell.qml').read_text().splitlines()
                            if line.startswith('//@ pragma '))
        (config / 'shell.qml').write_text(pragmas + '''
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "config"
import "services"
import "modules/topbar"
ShellRoot {
    PunchiShellSettings { id: settings }
    PunchiTopBarServices { id: topBarServices; settings: settings }
    PunchiScreenPolicy {
        id: screenPolicy
        settings: settings
        connectedScreens: Quickshell.screens
        primaryScreenName: ""
    }
    Variants {
        id: bars
        model: settings.topBarEnabled ? screenPolicy.activeScreens : []
        delegate: PunchiTopBar {
            property var modelData
            screen: modelData
            settings: settings
            services: topBarServices
        }
    }
    Component.onCompleted: settings.topBarEnabled = true
    IpcHandler {
        target: "topbar"
        function enable(): bool { settings.topBarEnabled = true; return true }
        function disable(): bool { settings.topBarEnabled = false; return true }
        function state(): string {
            const result = []
            for (let index = 0; index < bars.instances.length; ++index) {
                const bar = bars.instances[index]
                result.push({
                    screen: bar.screenKey,
                    visible: bar.visible,
                    width: bar.width,
                    height: bar.height,
                    reserved: bar.reservedHeight,
                    exclusiveZone: bar.exclusiveZone,
                    screenWidth: bar.screen ? bar.screen.width : 0,
                    screenHeight: bar.screen ? bar.screen.height : 0
                })
            }
            return JSON.stringify({enabled: settings.topBarEnabled,
                screenCount: Quickshell.screens.length, count: result.length, bars: result})
        }
    }
}
''')
        env = os.environ.copy()
        env.pop('QT_QUICK_CONTROLS_STYLE', None)
        env['QT_NO_XDG_DESKTOP_PORTAL'] = '1'
        log_path = config / 'runtime.log'
        with log_path.open('w') as log:
            process = subprocess.Popen(['qs', '--path', str(config), '--no-color'],
                                       env=env, stdout=log, stderr=log)
            try:
                def state_when(predicate):
                    deadline = time.monotonic() + 8
                    while time.monotonic() < deadline:
                        result = ipc(config, 'state')
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
                    raise RuntimeError(log_path.read_text() + '\nTop panel probe timed out.')

                mounted = state_when(lambda state: state['enabled'] and state['count'] >= 1)
                assert mounted['screenCount'] >= 1, mounted
                # One bar per allowed screen, anchored to the top edge.
                assert mounted['count'] == mounted['screenCount'], mounted
                for bar in mounted['bars']:
                    assert bar['visible'] is True, bar
                    assert bar['reserved'] > 0, bar
                    assert bar['exclusiveZone'] == bar['reserved'], bar
                    assert bar['width'] == bar['screenWidth'], bar
                    assert bar['height'] == bar['screenHeight'], bar
                    assert bar['screen'], bar

                # Disabling the switch releases the surface and its reservation.
                assert ipc(config, 'disable').returncode == 0
                released = state_when(lambda state: not state['enabled'] and state['count'] == 0)
                assert released['count'] == 0, released
                assert process.poll() is None, log_path.read_text()

                # Re-enabling mounts exactly one surface again.
                assert ipc(config, 'enable').returncode == 0
                remounted = state_when(lambda state: state['enabled'] and state['count'] >= 1)
                assert remounted['count'] == remounted['screenCount'], remounted
                print('Top panel mount, exclusive reservation and teardown on the real compositor: passed')
            finally:
                process.terminate()
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
            leftover = subprocess.run(['pgrep', '-af', str(config)], capture_output=True, text=True)
            assert leftover.returncode != 0, leftover.stdout
        output = log_path.read_text()
        print(output, end='')
        assert not re.search(r'ReferenceError|TypeError|Binding loop|Failed to load|'
                             r'Unable to assign|at engine destruction', output), output
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
