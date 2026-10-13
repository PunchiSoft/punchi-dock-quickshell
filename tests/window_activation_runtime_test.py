#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Exercise actual click -> native pipe -> activation result or owned KDE launch."""
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
    with tempfile.TemporaryDirectory(prefix='punchi-activate-runtime-') as directory:
        config = Path(directory)
        for name in ('modules', 'components', 'config', 'services', 'adapters'):
            shutil.copytree(root / name, config / name)
        captured = config / 'launched'
        sentinel = config / 'sentinel.py'
        sentinel.write_text('import pathlib,sys\n'
            'with pathlib.Path(sys.argv[1]).open("a") as stream: stream.write(sys.argv[2]+"\\n")\n')
        applications = Path(os.environ['XDG_DATA_HOME']) / 'applications'
        applications.mkdir()
        for name in ('open', 'closed', 'failed', 'transient'):
            (applications / f'punchi-activate-{name}.desktop').write_text('[Desktop Entry]\nType=Application\n'
                f'Name=Owned activation {name}\nIcon=utilities-terminal\n'
                f'Exec=/usr/bin/python3 "{sentinel}" "{captured}" {name}\n')
        subprocess.run(['kbuildsycoca6', '--noincremental'], capture_output=True, check=True, timeout=10)
        observer = config / 'observer.py'
        observer.write_text('''#!/usr/bin/python3
import json,pathlib,sys
root=pathlib.Path(__file__).parent
print(json.dumps(dict(version=1,available=True,desktopIds=['punchi-activate-open','punchi-activate-transient'],activationAvailable=True)),flush=True)
open_clicks=0
for line in sys.stdin:
 q=json.loads(line)
 with (root/'requests').open('a') as stream: stream.write(json.dumps(q)+'\\n')
 app=q['desktopId']
 status={'punchi-activate-open':'activated','punchi-activate-closed':'not-found','punchi-activate-failed':'unavailable','punchi-activate-transient':'activated'}[app]
 if app=='punchi-activate-open':
  open_clicks+=1
  if open_clicks==2: status='minimized'
 if q['type']=='new-instance' and app=='punchi-activate-open': status='new-instance'
 print(json.dumps(dict(version=1,type='activation-result',requestId=q['requestId'],desktopId=app,status=status)),flush=True)
 if app=='punchi-activate-transient':
  print(json.dumps(dict(version=1,available=True,desktopIds=['punchi-activate-open'],activationAvailable=True)),flush=True)
(root/'closed').write_text('EOF')
''')
        observer.chmod(0o700)
        (config / 'shell.qml').write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import Punchi.Kde as Native
import "modules/dock"
import "services"
import "adapters/kde"
ShellRoot {
    id: probe
    property int activated: 0
    property int rejected: 0
    property int launches: 0
    ListModel {
        id: entries
        ListElement { appId: "open"; desktopId: "punchi-activate-open.desktop"; title: "Open sentinel"; iconName: "utilities-terminal" }
        ListElement { appId: "closed"; desktopId: "punchi-activate-closed"; title: "Closed sentinel"; iconName: "utilities-terminal" }
        ListElement { appId: "failed"; desktopId: "punchi-activate-failed"; title: "Failed sentinel"; iconName: "utilities-terminal" }
    }
    ApplicationCatalog { id: catalog }
    RunningApplications { id: running; catalog: catalog }
    Native.DockApplicationsModel {
        id: dockEntries
        pinned: entries
        catalog: catalog
        runningDesktopIds: running.desktopIds
    }
    FloatingWindow {
        visible: true
        implicitWidth: dock.implicitWidth
        implicitHeight: dock.implicitHeight
        DockView {
            id: dock
            anchors.fill: parent
            entries: dockEntries
            reducedMotion: true
            onItemActivated: function(appId) { activation.activate(appId) }
            onItemNewWindowRequested: function(appId) { activation.newWindow(appId) }
        }
    }
    DesktopApplicationAdapter { id: adapter; activationItem: dock }
    ApplicationLaunchService {
        id: launcher
        entries: dockEntries
        adapter: adapter
        onLaunchCompleted: function(desktopId, success, error) {
            if (!success) console.error("OWNED_ACTIVATION_LAUNCH_FAILED", error)
            else probe.launches++
        }
    }
    ApplicationActivationService {
        id: activation
        entries: dockEntries
        launcher: launcher
        windowState: running
        onActivationDispatched: probe.activated++
        onActivationRejected: probe.rejected++
    }
    IpcHandler {
        target: "activationProbe"
        function state(): string { return JSON.stringify({ready: running.windowActivation.available,
            activated: probe.activated, rejected: probe.rejected, launches: probe.launches, items: dock.itemCount}) }
        function click(appId: string): bool {
            for (const item of dock.children) {
                if (item.objectName === "launcher-" + appId) { item.clicked(); return true }
            }
            return false
        }
        function newWindow(appId: string): bool { dock.itemNewWindowRequested(appId); return true }
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
                    result = subprocess.run(['qs', 'ipc', '--path', str(config), 'call', 'activationProbe', method, *args],
                        capture_output=True, text=True, timeout=3)
                    assert result.returncode == 0, result.stderr + log_path.read_text()
                    return json.loads(result.stdout)

                def wait_for(predicate):
                    deadline = time.monotonic() + 4
                    while time.monotonic() < deadline:
                        if process.poll() is not None:
                            raise RuntimeError(log_path.read_text())
                        try:
                            state = call('state')
                            if predicate(state): return state
                        except (AssertionError, json.JSONDecodeError):
                            pass
                        time.sleep(0.03)
                    raise RuntimeError(log_path.read_text() + '\nActivation observation timed out.')

                wait_for(lambda s: s['ready'] and s['items'] == 4)
                assert call('click', 'open') is True
                assert call('click', 'open') is True
                wait_for(lambda s: s['activated'] == 2)
                assert not captured.exists(), 'Existing-window activation launched another process'
                assert call('click', 'closed') is True
                wait_for(lambda s: s['launches'] == 1 and captured.exists())
                assert captured.read_text().splitlines() == ['closed']
                assert call('click', 'closed') is True
                time.sleep(0.05)
                assert captured.read_text().splitlines() == ['closed'], 'Startup click launched twice'
                assert call('click', 'failed') is True
                wait_for(lambda s: s['rejected'] == 1)
                assert captured.read_text().splitlines() == ['closed']
                assert call('newWindow', 'open') is True
                wait_for(lambda s: s['activated'] == 3)
                assert captured.read_text().splitlines() == ['closed']
                assert call('newWindow', 'closed') is True
                wait_for(lambda s: s['launches'] == 2 and len(captured.read_text().splitlines()) == 2)
                assert captured.read_text().splitlines() == ['closed', 'closed']
                assert call('click', 'desktop:punchi-activate-transient.desktop') is True
                wait_for(lambda s: s['activated'] == 4 and s['items'] == 3)
                assert captured.read_text().splitlines() == ['closed', 'closed']
                requests = [json.loads(line) for line in (config / 'requests').read_text().splitlines()]
                assert [q['desktopId'] for q in requests] == ['punchi-activate-open', 'punchi-activate-open',
                    'punchi-activate-closed', 'punchi-activate-failed', 'punchi-activate-open',
                    'punchi-activate-closed', 'punchi-activate-transient']
                assert [q['type'] for q in requests] == ['activate'] * 4 + ['new-instance'] * 2 + ['activate']
                assert len({q['requestId'] for q in requests}) == 7
                assert call('stopBackend') is True
                assert (config / 'closed').read_text() == 'EOF'
            finally:
                process.terminate()
                try: process.wait(timeout=3)
                except subprocess.TimeoutExpired: process.kill(); process.wait()
        output = log_path.read_text()
        print(output, end='')
        assert not re.search(r'\bERROR\b|ReferenceError|TypeError|Binding loop|Failed to load|'
            r'Unable to assign|OWNED_ACTIVATION_LAUNCH_FAILED|at engine destruction', output), output
        print('Click -> native command/result -> activate/minimize or owned KDE launch; failure, new window and EOF passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
