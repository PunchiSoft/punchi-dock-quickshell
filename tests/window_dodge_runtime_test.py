#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Drive the production visibility channel and policy in isolated Quickshell."""
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
    with tempfile.TemporaryDirectory(prefix='punchi-dodge-runtime-') as directory:
        config = Path(directory)
        for name in ('modules', 'components', 'config', 'services', 'adapters'):
            shutil.copytree(root / name, config / name)
        observer = config / 'observer.py'
        observer.write_text('''#!/usr/bin/python3
import pathlib,sys,select
root=pathlib.Path(__file__).parent
last=None
while True:
 if select.select([sys.stdin],[],[],0.02)[0] and sys.stdin.read(1)=='':
  (root/'closed').write_text('EOF'); break
 data=(root/'state.json').read_bytes()
 if data!=last:
  sys.stdout.buffer.write(data+b'\\n');sys.stdout.flush();last=data
''')
        observer.chmod(0o700)
        def write_state(available, desktop=False, rectangles=()):
            next_file = config / 'next.json'
            next_file.write_text(json.dumps({'version': 1, 'available': True,
                'desktopIds': ['org.kde.konsole'], 'visibility': {'available': available,
                    'showingDesktop': desktop, 'rectangles': rectangles}}))
            next_file.replace(config / 'state.json')
        write_state(False)
        (config / 'shell.qml').write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import "modules/dock"
import "services"
import "config"
import "adapters/kde/window-state"
ShellRoot {
    ShellSettings { id: settings; panelMode: "dodge-windows" }
    DockFixtureModel { id: catalog }
    RunningApplications { id: running; catalog: catalog }
    WindowModels { id: nativeModels }
    DockRestingGeometry { id: region; screenWidth: 800; screenHeight: 600;
        bodyWidth: 200; bodyHeight: 50; bottomClearance: 2; edgeMargin: 4 }
    WindowOverlap { id: overlap; source: running.visibilityState; region: region.region }
    DockVisibilityController {
        id: visibility
        dodgeWindows: settings.panelMode === "dodge-windows"
        autoHide: settings.panelMode === "autohide"
        overlapAvailable: overlap.available
        overlapping: overlap.overlapping
        showingDesktop: overlap.showingDesktop
        reducedMotion: true
        hideDelay: 10
    }
    IpcHandler {
        target: "dodgeProbe"
        function state(): string {
            return JSON.stringify({mode: settings.panelMode, available: overlap.available,
                desktop: overlap.showingDesktop, overlapping: overlap.overlapping,
                visible: visibility.surfaceVisible, shouldHide: visibility.shouldHide,
                allFilter: nativeModels.allTasks.filterMinimized,
                visibleFilter: nativeModels.visibleTasks.filterMinimized,
                hiddenFilter: nativeModels.visibleTasks.filterHidden,
                desktopFilter: nativeModels.visibleTasks.filterByCurrentVirtualDesktop,
                activityFilter: nativeModels.visibleTasks.filterByActivity})
        }
        function setMode(mode: string): bool { settings.panelMode = mode; return true }
        function menu(open: bool): bool { visibility.menuOpen = open; return true }
        function configure(open: bool): bool { visibility.configuring = open; return true }
        function stopBackend(): bool { running.backend.enabled = false; return true }
    }
}
''')
        env = os.environ.copy()
        env['PUNCHI_WINDOW_BACKEND'] = str(observer)
        env['QT_NO_XDG_DESKTOP_PORTAL'] = '1'
        env.pop('WAYLAND_DISPLAY', None)
        log_path = config / 'runtime.log'
        with log_path.open('w') as log:
            process = subprocess.Popen(['qs', '--path', str(config), '--no-color'], env=env, stdout=log, stderr=log)
            try:
                def call(method, *args):
                    result = subprocess.run(['qs', 'ipc', '--path', str(config), 'call', 'dodgeProbe', method, *args],
                                            capture_output=True, text=True, timeout=3)
                    if result.returncode: return None
                    return json.loads(result.stdout)
                def state_when(predicate):
                    state = None
                    deadline = time.monotonic() + 4
                    while time.monotonic() < deadline:
                        state = call('state')
                        if state and predicate(state): return state
                        if process.poll() is not None: break
                        time.sleep(0.03)
                    raise RuntimeError(log_path.read_text() + '\nDodge observation timed out: ' + json.dumps(state))
                state = state_when(lambda s: s['visible'] and not s['available'])
                assert not state['allFilter'] and all(state[k] for k in
                    ('visibleFilter', 'hiddenFilter', 'desktopFilter', 'activityFilter')), state
                write_state(True, rectangles=[[0, 0, 100, 100]])
                state_when(lambda s: s['available'] and not s['overlapping'] and s['visible'])
                crossing = [[300, 500, 100, 80]]
                write_state(True, rectangles=crossing)
                state_when(lambda s: s['overlapping'] and not s['visible'])
                write_state(True, desktop=True, rectangles=crossing)
                state_when(lambda s: s['desktop'] and not s['overlapping'] and s['visible'])
                time.sleep(0.08)
                assert call('state')['visible']
                write_state(True, rectangles=crossing)
                state_when(lambda s: not s['desktop'] and not s['visible'])
                assert call('menu', 'true')
                state_when(lambda s: s['visible'])
                assert call('menu', 'false')
                state_when(lambda s: not s['visible'])
                assert call('configure', 'true')
                state_when(lambda s: s['visible'])
                assert call('configure', 'false')
                state_when(lambda s: not s['visible'])
                write_state(False)
                state_when(lambda s: not s['available'] and s['visible'])
                assert call('setMode', 'autohide')
                write_state(True, desktop=True, rectangles=crossing)
                state_when(lambda s: s['desktop'] and not s['visible'])
                assert call('setMode', 'dodge-windows')
                state_when(lambda s: s['desktop'] and s['visible'])
                assert call('stopBackend')
                state_when(lambda s: not s['available'] and s['visible'])
                assert (config / 'closed').read_text() == 'EOF'
                print('Native visibility channel, official model filters, desktop state, holds and fallback: passed')
            finally:
                process.terminate()
                try: process.wait(timeout=3)
                except subprocess.TimeoutExpired: process.kill(); process.wait(timeout=3)
        output = log_path.read_text()
        if re.search(r'ERROR:|TypeError|ReferenceError|Binding loop|Cannot filter events|Component is not ready', output):
            raise RuntimeError(output)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
