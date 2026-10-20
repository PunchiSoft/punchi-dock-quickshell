#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check dock wiring with an owned offscreen host; compositor anchors need KWin."""
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
    with tempfile.TemporaryDirectory(prefix='punchi-vertical-runtime-') as directory:
        config = Path(directory)
        downloads = config / 'Owned Downloads'
        downloads.mkdir()
        (downloads / 'owned.txt').write_text('Owned folder content.\n')
        (Path(os.environ['XDG_CONFIG_HOME']) / 'user-dirs.dirs').write_text(f'XDG_DOWNLOAD_DIR="{downloads}"\n')
        for name in ('modules', 'components', 'config', 'services', 'adapters'):
            shutil.copytree(root / name, config / name)
        # Quickshell has no PanelWindow backend on Qt's offscreen platform.
        # Substitute only the host contract in this owned copy, keeping the
        # production wiring/content. Native edge protocol is tested separately.
        dock_path = config / 'modules/dock/Dock.qml'
        dock_source = dock_path.read_text().replace('PanelWindow {', 'OffscreenDockHost {', 1)
        dock_source = dock_source.replace('anchors.bottom:', 'panelAnchors.bottom:')
        dock_source = dock_source.replace('anchors.top:', 'panelAnchors.top:')
        dock_source = dock_source.replace('anchors.left:', 'panelAnchors.left:')
        dock_source = dock_source.replace('anchors.right:', 'panelAnchors.right:')
        dock_source = dock_source.replace('margins.', 'panelMargins.')
        dock_source = re.sub(r'^    WlrLayershell\.(?:layer|namespace):.*\n', '', dock_source, flags=re.MULTILINE)
        dock_source = re.sub(r'^    WlrLayershell\.keyboardFocus:.*\n        \?.*\n', '', dock_source, flags=re.MULTILINE)
        dock_source = dock_source.replace('layer: root.WlrLayershell.layer,', 'layer: 0,')
        dock_path.write_text(dock_source)
        (config / 'modules/dock/OffscreenDockHost.qml').write_text('''
import QtQuick
import Quickshell
FloatingWindow {
    component EdgeFlags: QtObject {
        property bool top: false
        property bool bottom: false
        property bool left: false
        property bool right: false
    }
    component EdgeMargins: QtObject {
        property real bottom: 0
        property real left: 0
        property real right: 0
    }
    property EdgeFlags panelAnchors: EdgeFlags {}
    property EdgeMargins panelMargins: EdgeMargins {}
    property int exclusiveZone: 0
    property int exclusionMode: 0
    visible: true
}
''')
        backend = config / 'backend.py' 
        backend.write_text('#!/usr/bin/python3\nimport sys\n'
                           'print(\'{"version":1,"available":false,"desktopIds":[]}\',flush=True)\n'
                           'sys.stdin.read()\n')
        backend.chmod(0o700)
        pragmas = '\n'.join(line for line in (root / 'shell.qml').read_text().splitlines()
                            if line.startswith('//@ pragma '))
        (config / 'shell.qml').write_text(pragmas + '''
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "modules/dock"
import "services"
ShellRoot {
    Dock { id: dock; configuring: true }
    SettingsStore { settings: dock.preferences }
    function find(item: var, name: string): var {
        if (!item) return null
        if (item.objectName === name) return item
        const children = item.data || item.children
        if (children) for (let row = 0; row < children.length; ++row) {
            const found = find(children[row], name)
            if (found) return found
        }
        return null
    }
    IpcHandler {
        target: "verticalProbe"
        function edge(value: string): bool { dock.preferences.dockEdge = value; return true }
        function mode(value: string): bool { dock.preferences.panelMode = value; return true }
        function toggleDownloads(): bool {
            const tile = find(dock.contentItem,"launcher-item:downloads")
            if (!tile) return false
            tile.activated("item:downloads")
            return true
        }
        function folderView(value: string): bool { return dock.preferences.setContainerLayout("item:downloads", value) }
        function state(): string {
            const tile = find(dock.contentItem,"launcher-files")
            const folder = find(dock.contentItem,"downloadsPopup")
            const view = find(dock.contentItem,"dock-view")
            const fan = folder && folder.contentItem ? find(folder.contentItem,"folderFanView") : null
            return JSON.stringify({edge:dock.preferences.dockEdge,
                top:dock.panelAnchors.top, bottom:dock.panelAnchors.bottom, left:dock.panelAnchors.left, right:dock.panelAnchors.right,
                width:dock.width, height:dock.height, screenWidth:dock.screen ? dock.screen.width : 0,
                dockViewX:view ? view.x : 0, dockViewWidth:view ? view.width : 0,
                zone:dock.exclusiveZone,
                configuring:dock.configuring, tile:tile ? {x:tile.x,y:tile.y,edge:tile.dockEdge}:null,
                folder:folder ? {visible:folder.visible,active:folder.contents.active,loading:folder.contents.loading,
                    count:folder.contents.count,view:folder.contentItem ? folder.contentItem.viewMode : 'grid',edge:folder.dockEdge}:null,
                fan:fan ? {visible:fan.visible,width:fan.width,height:fan.height,rows:fan.totalRowCount,iconsOnRight:fan.iconsOnRight}:null})
        }
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
                def call(method, *args):
                    result = subprocess.run(['qs','ipc','--path',str(config),'call','verticalProbe',method,*args],
                                            capture_output=True,text=True,timeout=3)
                    if result.returncode != 0: return None
                    try: return json.loads(result.stdout)
                    except json.JSONDecodeError:
                        raise AssertionError(log_path.read_text() + '\nUnexpected IPC output: ' + result.stdout)
                def wait_state(predicate):
                    deadline = time.monotonic() + 5
                    state = None
                    while time.monotonic() < deadline and process.poll() is None:
                        state = call('state')
                        if state and predicate(state): return state
                        time.sleep(0.03)
                    raise AssertionError(f'{log_path.read_text()}\nState timeout: {state}')
                wait_state(lambda s:s['bottom'] and s['tile'] is not None)
                for edge in ('left','right','bottom'):
                    assert call('edge',edge) is True
                    state = wait_state(lambda s:s['edge'] == edge and s[edge] and s['tile']['edge'] == edge)
                    assert sum(state[key] for key in ('top','bottom','left','right')) == (1 if edge == 'bottom' else 3)
                    assert state['width'] > 0 and state['height'] > 0
                    assert call('toggleDownloads') is True
                    state = wait_state(lambda s:s['folder'] and s['folder']['visible'] and not s['folder']['loading'])
                    assert state['folder']['count'] == 1 and state['folder']['active']
                    assert state['folder']['edge'] == edge
                    if edge == 'bottom':
                        assert state['width'] == state['screenWidth'], state
                        assert state['dockViewX'] > 0
                        assert abs(state['dockViewX'] * 2 + state['dockViewWidth'] - state['width']) < 2
                    assert call('folderView','detail') is True
                    wait_state(lambda s:s['folder']['view'] == 'detail')
                    # The arc belongs to horizontal panels: it loads under the
                    # real Quickshell process on the bottom edge, while a
                    # vertical one keeps the stored choice and presents Grid.
                    assert call('folderView','fan') is True
                    if edge == 'bottom':
                        state = wait_state(lambda s:s['folder']['view'] == 'fan'
                            and s['fan'] and s['fan']['visible'])
                        assert state['fan']['width'] > 0 and state['fan']['height'] > 0
                        assert state['fan']['rows'] == state['folder']['count'] + 1
                    else:
                        state = wait_state(lambda s:s['folder']['view'] == 'grid')
                        assert not state['fan'] or not state['fan']['visible']
                    assert call('folderView','detail') is True
                    wait_state(lambda s:s['folder']['view'] == 'detail')
                    assert call('toggleDownloads') is True
                    state = wait_state(lambda s:not s['folder']['visible'] and not s['folder']['active'])
                    if edge == 'bottom':
                        assert state['width'] == state['screenWidth']
                        assert abs(state['dockViewX'] * 2 + state['dockViewWidth'] - state['width']) < 2
                    for mode in ('reserve','autohide','dodge-windows','overlay'):
                        assert call('mode',mode) is True
                        state = wait_state(lambda s:(s['zone'] > 0) == (mode == 'reserve'))
                        assert state['configuring']
                    saved = Path(env['XDG_CONFIG_HOME']) / 'punchi-dock-quickshell.json'
                    deadline = time.monotonic() + 3
                    while time.monotonic() < deadline:
                        if saved.exists():
                            profile = json.loads(saved.read_text())
                            containers = profile.get('containers', [])
                            if (profile.get('dockEdge') == edge
                                    and any(item.get('id') == 'downloads' and item.get('layout') == 'detail'
                                            for item in containers)): break
                        time.sleep(0.02)
                    else: raise AssertionError('Position did not reach the owned SettingsStore file')
            finally:
                process.terminate()
                try: process.wait(timeout=3)
                except subprocess.TimeoutExpired: process.kill(); process.wait()
        output = log_path.read_text()
        print(output,end='')
        assert not re.search(r'\bERROR\b|ReferenceError|TypeError|Binding loop|Unable to assign|at engine destruction',output), output
        print('Offscreen-hosted dock wiring: reactive edge selection, native-style content and four mode reservations passed; KWin placement untested.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
