#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Exercise screen, desktop and IPC placement policy in an offscreen shell."""
import json
import os
import re
import shutil
import subprocess
import tempfile
import time
from pathlib import Path


def main():
    root = Path(__file__).resolve().parents[1]
    assert os.environ.get('QT_QPA_PLATFORM') == 'offscreen', 'Use the isolated offscreen runner.'
    with tempfile.TemporaryDirectory(prefix='punchi-placement-runtime-') as temporary:
        config = Path(temporary)
        for name in ('modules', 'components', 'config', 'services', 'adapters'):
            shutil.copytree(root / name, config / name)
        pragmas = '\n'.join(line for line in (root / 'shell.qml').read_text().splitlines()
                            if line.startswith('//@ pragma '))
        (config / 'shell.qml').write_text(pragmas + '''
import QtQuick
import Quickshell
import Quickshell.Io
import "config"
import "services"
import "modules/dock"
ShellRoot {
    id: probe
    property int settingsOpened: 0
    PunchiShellSettings { id: settings }
    PunchiScreenPolicy {
        id: policy
        settings: settings
        connectedScreens: [
            {name: "LEFT", x: 0, y: 0, width: 1920, height: 1080},
            {name: "RIGHT", x: 1920, y: 0, width: 2560, height: 1440}]
        primaryScreenName: "RIGHT"
    }
    PunchiVirtualDesktopPolicy {
        id: desktopPolicy
        settings: settings
        runningApplications: QtObject {
            property bool available: true
            property var virtualDesktops: [{id: 1, name: "One", current: true},
                {id: 2, name: "Two", current: false}]
            property var activities: [{id: "work", name: "Work", current: true}]
        }
    }
    QtObject {
        id: dockLeft
        property var screen: ({name: "LEFT"})
        function reveal(): bool { return true }
        function focus(): bool { return true }
        function snapshot(): string { return JSON.stringify({screen: "LEFT"}) }
    }
    QtObject {
        id: dockRight
        property var screen: ({name: "RIGHT"})
        function reveal(): bool { return true }
        function focus(): bool { return true }
        function snapshot(): string { return JSON.stringify({screen: "RIGHT"}) }
    }
    PunchiDockIpc {
        docks: [dockLeft, dockRight]
        settings: settings
        primaryScreenName: policy.primaryScreenName
        onSettingsRequested: probe.settingsOpened += 1
    }
    IpcHandler {
        target: "placementProbe"
        function state(): string {
            return JSON.stringify({
                allowed: desktopPolicy.allowed,
                desktop: desktopPolicy.currentDesktopId,
                activity: desktopPolicy.currentActivityId,
                left: policy.allows({name: "LEFT"}),
                right: policy.allows({name: "RIGHT"}),
                active: policy.activeScreens.map(screen => screen.name),
                sharedRightEdge: policy.isSharedEdge(policy.connectedScreens[0], "right"),
                screenMode: settings.screenMode,
                desktopMode: settings.desktopMode,
                settingsOpened: probe.settingsOpened
            })
        }
        function list(csv: string): var {
            return csv === "-" || csv.length === 0 ? [] : csv.split(",")
        }
        function configure(mode: string, screens: string, desks: string, desktops: string): bool {
            settings.screenMode = mode
            settings.selectedScreens = list(screens)
            settings.desktopMode = desks
            settings.selectedDesktops = list(desktops)
            return true
        }
        function hotplug(names: string): bool {
            const catalog = {
                LEFT: {name: "LEFT", x: 0, y: 0, width: 1920, height: 1080},
                RIGHT: {name: "RIGHT", x: 1920, y: 0, width: 2560, height: 1440}
            }
            policy.connectedScreens = list(names).map(name => catalog[name])
            return true
        }
    }
}
''')
        env = os.environ.copy()
        env.pop('WAYLAND_DISPLAY', None)
        env['QT_NO_XDG_DESKTOP_PORTAL'] = '1'
        log_path = config / 'runtime.log'
        with log_path.open('w') as log:
            process = subprocess.Popen(['qs', '--path', str(config), '--no-color'],
                                       env=env, stdout=log, stderr=log)
            try:
                def call(target, method, *args):
                    result = subprocess.run(['qs', 'ipc', '--path', str(config), 'call',
                                             target, method, *args],
                                            capture_output=True, text=True, timeout=3)
                    assert result.returncode == 0, result.stderr + log_path.read_text()
                    try:
                        return json.loads(result.stdout)
                    except json.JSONDecodeError:
                        raise AssertionError(repr(result.stdout) + result.stderr + log_path.read_text())

                def state_when(predicate):
                    deadline = time.monotonic() + 4
                    while time.monotonic() < deadline:
                        if process.poll() is not None:
                            raise RuntimeError(log_path.read_text())
                        try:
                            state = call('placementProbe', 'state')
                            if predicate(state):
                                return state
                        except (AssertionError, json.JSONDecodeError):
                            pass
                        time.sleep(0.03)
                    raise RuntimeError(log_path.read_text() + '\nPlacement probe timed out.')

                state = state_when(lambda value: value['allowed'])
                assert state['active'] == ['LEFT', 'RIGHT'], state
                assert state['sharedRightEdge'], state
                assert call('dock', 'screenKeys') == ['LEFT', 'RIGHT'], 'screen keys'
                assert call('dock', 'snapshot')['screen'] == 'RIGHT', 'primary dock'
                assert call('dock', 'snapshotFor', 'LEFT')['screen'] == 'LEFT'
                assert call('dock', 'snapshotFor', 'MISSING') == {}, 'unknown screen'
                assert call('dock', 'revealFor', 'LEFT')
                assert call('dock', 'focusFor', 'MISSING') is False
                assert call('dock', 'setMode', 'autohide')
                assert call('dock', 'setMode', 'primary') is False, 'invalid mode'
                call('dock', 'openSettings')
                state = state_when(lambda value: value['settingsOpened'] == 1)
                # A selected screen keeps the dock off the other screen only.
                call('placementProbe', 'configure', 'selected', 'LEFT', 'all', '-')
                state = state_when(lambda value: value['screenMode'] == 'selected')
                assert state['left'] and not state['right'], state
                assert state['active'] == ['LEFT'], state
                # Selecting another desktop hides the dock while it is active.
                call('placementProbe', 'configure', 'selected', 'LEFT', 'selected', '2')
                state = state_when(lambda value: value['desktopMode'] == 'selected')
                assert state['desktop'] == '1' and not state['allowed'], state
                # Disconnecting the only selected screen falls back to primary.
                call('placementProbe', 'hotplug', 'RIGHT')
                state = state_when(lambda value: value['active'] == ['RIGHT'])
                assert not state['left'] and state['right'], state
                # Reconnecting restores the configured screen.
                call('placementProbe', 'hotplug', 'LEFT,RIGHT')
                state = state_when(lambda value: value['active'] == ['LEFT'])
                assert state['left'] and not state['right'], state
            finally:
                process.terminate()
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        output = log_path.read_text()
        print(output, end='')
        assert not re.search(r'\bERROR\b|ReferenceError|TypeError|Binding loop|Failed to load|'
                             r'Unable to assign|different thread|overrides a member|at engine destruction',
                             output), output
        print('Placement policy: screen selection, hot-plug fallback, desktop filtering and IPC routing passed offscreen.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
