#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Drive native-provider snapshots through catalog matching and the actual dock."""
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
    with tempfile.TemporaryDirectory(prefix='punchi-running-runtime-') as directory:
        config = Path(directory)
        for name in ('modules', 'components', 'config', 'services', 'adapters'):
            shutil.copytree(root / name, config / name)
        applications = Path(os.environ['XDG_DATA_HOME']) / 'applications'
        applications.mkdir()
        (applications / 'punchi-running-sentinel.desktop').write_text('[Desktop Entry]\n'
            'Type=Application\nName=Owned running fixture\nIcon=utilities-terminal\nExec=/bin/false\n')
        subprocess.run(['kbuildsycoca6', '--noincremental'], capture_output=True, check=True, timeout=10)
        backend = config / 'observer.py'
        backend.write_text('''#!/usr/bin/python3
import pathlib,sys,select
root=pathlib.Path(__file__).parent
last=None
while True:
 if select.select([sys.stdin],[],[],0.02)[0] and sys.stdin.read(1)=='':
  (root/'closed').write_text('EOF'); break
 current=(root/'state.json').read_bytes()
 if current!=last:
  sys.stdout.buffer.write(current+b'\\n'); sys.stdout.flush(); last=current
''')
        backend.chmod(0o700)
        def write_state(available, ids, applications=None):
            temporary = config / 'next.json'
            temporary.write_text(json.dumps({'version': 1, 'available': available, 'desktopIds': ids,
                'applications': applications or []}))
            temporary.replace(config / 'state.json')
        write_state(False, [])
        pragmas = '\n'.join(line for line in (root / 'shell.qml').read_text().splitlines()
                            if line.startswith('//@ pragma '))
        (config / 'shell.qml').write_text(pragmas + '''
import QtQuick
import Quickshell
import Quickshell.Io
import Punchi.Kde as Native
import "modules/dock"
import "services"
ShellRoot {
    ApplicationCatalog { id: catalog }
    RunningApplications { id: running; catalog: catalog }
    PinnedApplications { id: pins; catalog: catalog; pinnedIds: ["desktop:punchi-running-sentinel.desktop"] }
    Native.DockApplicationsModel {
        id: entries
        pinned: pins
        catalog: catalog
        runningDesktopIds: running.available ? running.desktopIds : []
        runningApplications: running.available ? running.applicationEntries : []
    }
    FloatingWindow {
        visible: true
        implicitWidth: dock.implicitWidth
        implicitHeight: dock.implicitHeight
        DockView { id: dock; anchors.fill: parent; entries: entries; applicationState: running; reducedMotion: true }
    }
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
    IpcHandler {
        target: "markerProbe"
        function state(): string {
            const tile = find(dock, "launcher-desktop:punchi-running-sentinel.desktop")
            const marker = find(dock, "launcher-running-marker-desktop:punchi-running-sentinel.desktop")
            const transientId = "desktop:org.punchi.plasmoid-settings.desktop"
            const transient = find(dock, "launcher-" + transientId)
            const transientDot = find(dock, "launcher-running-marker-" + transientId)
            const transientEntry = entries.get(1)
            return JSON.stringify({available: running.available, count: dock.itemCount,
                running: tile ? tile.running : false, marker: marker ? marker.visible : false,
                transientRunning: transient ? transient.running : false,
                transientMarker: transientDot ? transientDot.visible : false,
                transientTitle: transientEntry ? transientEntry.title : "",
                transientIcon: transientEntry ? transientEntry.iconName : ""})
        }
        function stopBackend(): bool { running.backend.enabled = false; return true }
    }
}
''')
        env = os.environ.copy()
        env['PUNCHI_WINDOW_BACKEND'] = str(backend)
        env['QT_NO_XDG_DESKTOP_PORTAL'] = '1'
        env.pop('WAYLAND_DISPLAY', None)
        log_path = config / 'runtime.log'
        with log_path.open('w') as log:
            process = subprocess.Popen(['qs', '--path', str(config), '--no-color'], env=env, stdout=log, stderr=log)
            try:
                def call(method):
                    result = subprocess.run(['qs', 'ipc', '--path', str(config), 'call', 'markerProbe', method],
                                            capture_output=True, text=True, timeout=3)
                    if result.returncode:
                        return None
                    return json.loads(result.stdout)
                def state_when(predicate):
                    deadline = time.monotonic() + 4
                    while time.monotonic() < deadline:
                        state = call('state')
                        if state and predicate(state): return state
                        if process.poll() is not None: break
                        time.sleep(0.03)
                    raise RuntimeError(log_path.read_text() + '\nMarker observation timed out: ' + json.dumps(state))
                state_when(lambda s: s['count'] == 1 and not s['marker'] and not s['available'])
                write_state(True, ['punchi-running-sentinel'])
                state_when(lambda s: s['available'] and s['running'] and s['marker'])
                write_state(True, ['punchi-running-sentinel', 'org.punchi.plasmoid-settings'],
                    [{'desktopId': 'org.punchi.plasmoid-settings', 'name': 'Plasma Applet Settings',
                      'iconName': 'preferences-system-windows'}])
                state_when(lambda s: s['count'] == 2 and s['transientRunning']
                    and s['transientMarker'] and s['transientTitle'] == 'Plasma Applet Settings'
                    and s['transientIcon'] == 'preferences-system-windows')
                write_state(True, ['punchi-running-sentinel'])
                state_when(lambda s: s['count'] == 1 and not s['transientRunning'])
                write_state(True, ['other-app'])
                state_when(lambda s: s['available'] and not s['running'] and not s['marker'])
                write_state(True, ['punchi-running-sentinel.desktop'])
                state_when(lambda s: s['marker'])
                write_state(True, [])
                state_when(lambda s: s['available'] and not s['marker'])
                write_state(False, [])
                state_when(lambda s: not s['available'] and not s['marker'])
                assert call('stopBackend') is True
                deadline = time.monotonic() + 3
                while not (config / 'closed').exists() and time.monotonic() < deadline: time.sleep(0.03)
                assert (config / 'closed').exists(), 'Provider did not close its owned backend pipe'
            finally:
                process.terminate()
                try: process.wait(timeout=3)
                except subprocess.TimeoutExpired: process.kill(); process.wait()
        output = log_path.read_text()
        print(output, end='')
        assert not re.search(r'\bERROR\b|ReferenceError|TypeError|Binding loop|Unable to assign|at engine destruction', output), output
        print('Native provider -> catalog identity -> actual dock marker, unavailable/empty distinction and shutdown passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
