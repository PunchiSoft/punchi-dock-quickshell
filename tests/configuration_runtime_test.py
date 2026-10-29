#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Exercise shared configuration controllers and settings on an offscreen host."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time


def main():
    root = Path(__file__).resolve().parents[1]
    assert os.environ.get('QT_QPA_PLATFORM') == 'offscreen', 'Use the isolated offscreen runner.'
    with tempfile.TemporaryDirectory(prefix='punchi-configure-runtime-') as temporary:
        config = Path(temporary)
        for name in ('modules', 'components', 'config', 'services', 'adapters'):
            shutil.copytree(root / name, config / name)
        pragmas = '\n'.join(line for line in (root / 'shell.qml').read_text().splitlines()
                            if line.startswith('//@ pragma '))
        source = pragmas + '\n' + '''import QtQuick
import Quickshell
import Quickshell.Io
import "modules/dock"
import "modules/settings"
import "config"
import "services"
ShellRoot {
    id: probe
    function find(item: var, name: string): var {
        if (item.objectName === name) return item
        const children = item.data || item.children
        if (!children) return null
        for (let index = 0; index < children.length; ++index) {
            const found = find(children[index], name)
            if (found) return found
        }
        return null
    }
    PunchiShellSettings { id: preferences }
    PunchiSettingsStore { settings: preferences }
    // No PanelWindow backend exists offscreen; exercise its shared controllers
    // with a real FloatingWindow, without claiming layer-shell/KWin evidence.
    FloatingWindow { id: host; visible: true; implicitWidth: 200; implicitHeight: 80 }
    PunchiDockConfigurationController { hostWindow: host; active: settingsWindow.visible }
    PunchiDockPanelPolicy {
        id: policy
        mode: preferences.panelMode
        baseHeight: preferences.itemSize
    }
    PunchiDockVisibilityController {
        id: visibility
        autoHide: policy.effectiveMode === "autohide"
        dodgeWindows: policy.effectiveMode === "dodge-windows"
        configuring: settingsWindow.visible
        reducedMotion: preferences.effectiveReducedMotion
    }
    PunchiSettingsWindow { id: settingsWindow; settings: preferences }
    IpcHandler {
        target: "dock"
        function openSettings(): bool { settingsWindow.open(); return true }
        function setMode(mode: string): bool {
            if (!policy.accepts(mode)) return false
            preferences.panelMode = mode
            return true
        }
        function snapshot(): string {
            return JSON.stringify({mode: policy.effectiveMode, visible: host.visible,
                exclusiveZone: policy.exclusiveZone, surfaceVisible: visibility.surfaceVisible,
                slideProgress: visibility.boundedSlideProgress})
        }
    }
    IpcHandler {
        target: "configurationProbe"
        function state(): string {
            return JSON.stringify({settingsVisible: settingsWindow.visible,
                configuring: settingsWindow.visible, pending: settingsWindow.hasPendingChanges,
                draftMode: probe.find(settingsWindow.contentItem, "dockSettingsView").settings.panelMode})
        }
        function prepare(): bool { preferences.reducedMotion = true; return true }
        function close(): bool {
            probe.find(settingsWindow.contentItem, "closeDockSettings").clicked()
            return true
        }
        function applyMode(mode: string): bool {
            probe.find(settingsWindow.contentItem, "dockSettingsView").settings.panelMode = mode
            probe.find(settingsWindow.contentItem, "applyDockSettings").clicked()
            return true
        }
        function hideDock(): bool { host.visible = false; return true }
    }
}
'''
        (config / 'shell.qml').write_text(source)
        env = os.environ.copy()
        env['PUNCHI_DOCK_MODE'] = 'desktop'
        env['QT_NO_XDG_DESKTOP_PORTAL'] = '1'
        env.pop('WAYLAND_DISPLAY', None)
        log_path = config / 'runtime.log'
        with log_path.open('w') as log:
            process = subprocess.Popen(['qs', '--path', str(config), '--no-color'],
                                       env=env, stdout=log, stderr=log)
            try:
                def call(target, method, *args):
                    result = subprocess.run(['qs', 'ipc', '--path', str(config), 'call', target, method, *args],
                                            capture_output=True, text=True, timeout=3)
                    assert result.returncode == 0, result.stderr + log_path.read_text()
                    return json.loads(result.stdout)

                def state_when(predicate):
                    deadline = time.monotonic() + 4
                    while time.monotonic() < deadline:
                        if process.poll() is not None:
                            raise RuntimeError(log_path.read_text())
                        try:
                            state = call('configurationProbe', 'state')
                            state.update(call('dock', 'snapshot'))
                            if predicate(state):
                                return state
                        except (AssertionError, json.JSONDecodeError):
                            pass
                        time.sleep(0.03)
                    raise RuntimeError(log_path.read_text() + '\nConfiguration probe timed out.')

                state_when(lambda s: s['mode'] == 'dodge-windows')
                call('configurationProbe', 'prepare')
                for _ in range(2):
                    call('dock', 'openSettings')
                    state_when(lambda s: s['settingsVisible'] and s['configuring'] and s['visible'] and s['surfaceVisible'])
                    assert call('dock', 'snapshot')['mode'] == 'dodge-windows'
                    call('configurationProbe', 'close')
                    state_when(lambda s: not s['configuring'] and s['mode'] == 'dodge-windows')
                call('dock', 'setMode', 'autohide')
                state_when(lambda s: not s['surfaceVisible'])
                call('dock', 'openSettings')
                state_when(lambda s: s['configuring'] and s['surfaceVisible'] and s['slideProgress'] == 1)
                time.sleep(0.7)
                shown = call('dock', 'snapshot')
                assert shown['surfaceVisible'] and shown['slideProgress'] == 1, shown
                call('configurationProbe', 'close')
                state_when(lambda s: not s['surfaceVisible'] and s['mode'] == 'autohide')
                call('dock', 'openSettings')
                state_when(lambda s: s['configuring'] and s['surfaceVisible'])
                call('configurationProbe', 'applyMode', 'desktop')
                state_when(lambda s: s['settingsVisible'] and s['mode'] == 'dodge-windows' and not s['pending'])
                assert call('configurationProbe', 'state')['draftMode'] == 'dodge-windows'
                call('configurationProbe', 'close')
                state_when(lambda s: s['mode'] == 'dodge-windows')
                call('dock', 'setMode', 'reserve')
                reserved = state_when(lambda s: s['exclusiveZone'] > 0)['exclusiveZone']
                call('dock', 'openSettings')
                state = state_when(lambda s: s['configuring'])
                assert state['exclusiveZone'] == reserved, state
                call('configurationProbe', 'close')
                state_when(lambda s: not s['settingsVisible'])
                for mode in ('reserve', 'autohide', 'dodge-windows', 'overlay'):
                    call('dock', 'openSettings')
                    state_when(lambda s: s['settingsVisible'] and s['surfaceVisible'])
                    call('configurationProbe', 'applyMode', mode)
                    state = state_when(lambda s: s['settingsVisible'] and s['surfaceVisible']
                                       and s['mode'] == mode and not s['pending'])
                    assert (state['exclusiveZone'] > 0) == (mode == 'reserve'), state
                    assert state['draftMode'] == mode, state
                    saved = json.loads((Path(env['XDG_CONFIG_HOME']) / 'punchi-dock-quickshell.json').read_text())
                    assert saved['panelMode'] == mode, saved
                    call('configurationProbe', 'close')
                    state_when(lambda s: not s['settingsVisible'] and s['mode'] == mode)
                call('configurationProbe', 'hideDock')
                state_when(lambda s: not s['visible'])
                call('dock', 'openSettings')
                state_when(lambda s: s['configuring'] and s['visible'])
                call('configurationProbe', 'close')
                state_when(lambda s: not s['configuring'] and not s['visible'])
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
                             r'Unable to assign|different thread|overrides a member|at engine destruction', output), output
        print('Shared configuration controllers: reveal, legacy mode migration, mode restore, Apply and reservation passed offscreen.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
