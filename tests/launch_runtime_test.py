#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Exercise the real desktop adapter with an owned, short-lived launch sentinel."""

import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import sys
import time


def owned_processes(script):
    result = []
    for process in Path('/proc').iterdir():
        if not process.name.isdigit():
            continue
        try:
            arguments = (process / 'cmdline').read_bytes().split(b'\0')
            if os.fsencode(script) in arguments:
                result.append(int(process.name))
        except (FileNotFoundError, PermissionError, ProcessLookupError):
            pass
    return result


def main():
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix='punchi-shell-launch-') as temporary:
        config = Path(temporary)
        directories = ('services', 'adapters')
        if '--window' in sys.argv:
            directories += ('components', 'config', 'modules')
        for directory in directories:
            shutil.copytree(root / directory, config / directory)
        captured = config / 'captured.jsonl'
        script = config / 'capture.py'
        script.write_text('import json, os, sys\n'
                          'assert not os.environ.get("PUNCHI_KDE_BOOTSTRAP_LIBRARY")\n'
                          'assert "libpunchikde.so" not in os.environ.get("LD_PRELOAD", "")\n'
                          'with open(sys.argv[1], "a") as output:\n'
                          ' output.write(json.dumps(sys.argv[2:]) + "\\n")\n')
        applications = Path(os.environ['XDG_DATA_HOME']) / 'applications'
        applications.mkdir()
        desktop = applications / 'punchi-shell-launch-sentinel.desktop'
        desktop.write_text('[Desktop Entry]\nType=Application\nName=Launch test sentinel\n'
                           f'Exec=/usr/bin/python3 "{script}" "{captured}" "argument with spaces" %U\n'
                           'Terminal=false\nStartupNotify=false\nActions=new-window;hidden;\n'
                           '[Desktop Action new-window]\nName=New sentinel window\nIcon=window-new\n'
                           f'Exec=/usr/bin/python3 "{script}" "{captured}" "native desktop action"\n'
                           '[Desktop Action hidden]\nName=Hidden sentinel\nNoDisplay=true\n'
                           'Exec=/punchi-shell-nonexistent-executable\n')
        broken = applications / 'punchi-shell-broken-sentinel.desktop'
        broken.write_text('[Desktop Entry]\nType=Application\nName=Broken launch sentinel\n'
                          'Exec=/punchi-shell-nonexistent-executable\nTerminal=false\nStartupNotify=false\n')
        (config / 'shell.qml').write_text('''import QtQuick
import QtQml.Models
import Quickshell
import "services"
import "adapters/kde"
ShellRoot {
    property int completed: 0
    property int failed: 0
    PunchiDesktopApplicationAdapter {
        id: adapter
        onLaunchFinished: function(desktopId, success, error) {
            if (desktopId === "punchi-shell-broken-sentinel") {
                if (success || error.length === 0) console.error("PUNCHI_LAUNCH_FAILED")
                failed++
            } else if (success) completed++
            else console.error("PUNCHI_LAUNCH_FAILED", error)
            if (completed === 3 && failed === 1) {
                console.warn("PUNCHI_LAUNCH_DISPATCHED")
                Qt.quit()
            }
        }
    }
    ListModel {
        id: entries
        ListElement { appId: "test"; desktopId: "punchi-shell-launch-sentinel" }
        ListElement { appId: "missing"; desktopId: "punchi-shell-missing-entry" }
        ListElement { appId: "broken"; desktopId: "punchi-shell-broken-sentinel" }
    }
    PunchiApplicationLaunchService { id: service; entries: entries; adapter: adapter }
    Timer {
        id: launchTimer
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            if (adapter.applicationCount === 0) return
            launchTimer.stop()
            const actions = service.actions("test")
            if (actions.length !== 1 || actions[0].actionId !== "new-window"
                    || actions[0].name !== "New sentinel window" || actions[0].icon !== "window-new"
                    || service.actions("not-configured").length !== 0
                    || adapter.actions("/tmp/untrusted.desktop").length !== 0
                    || adapter.canLaunchNewWindow("punchi-shell-launch-sentinel")) {
                console.error("PUNCHI_LAUNCH_FAILED_ACTION_DISCOVERY")
                Qt.quit()
                return
            }
            if (!service.launch("test") || !service.launch("test")
                    || service.launch("missing") || service.launch("not-configured")
                    || adapter.launch("/tmp/untrusted.desktop")
                    || adapter.launch("test; command") || !service.launch("broken")
                    || !service.launchAction("test", "new-window")
                    || service.launchAction("test", "hidden")
                    || service.launchAction("test", "unknown; command")
                    || service.launchAction("not-configured", "new-window")) {
                console.error("PUNCHI_LAUNCH_FAILED")
                Qt.quit()
            }
        }
    }
}
''')
        if '--window' in sys.argv:
            model = config / 'services/PunchiDockFixtureModel.qml'
            model.write_text(model.read_text().replace('desktopId: "org.kde.dolphin"',
                'desktopId: "punchi-shell-launch-sentinel"'))
            (config / 'shell.qml').write_text('''import QtQuick
import Quickshell
import "config"
import "modules/dock"
import "components"
ShellRoot {
    readonly property int applicationCount: DesktopEntries.applications.values.length
    property int completed: 0
    PunchiShellSettings { id: shellSettings }
    PunchiDockServices { id: dockServices; settings: shellSettings }
    Dock {
        id: dock
        services: dockServices
        onApplicationLaunchFinished: function(desktopId, success, error) {
            if (!success) {
                console.error("PUNCHI_LAUNCH_FAILED", error)
                Qt.quit()
                return
            }
            completed++
            if (completed === 2) Qt.quit()
        }
    }
    Timer {
        id: activationTimer
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            if (applicationCount === 0) return
            for (let i = 0; i < dock.contentItem.children.length; ++i) {
                const view = dock.contentItem.children[i] as PunchiDockView
                if (!view) continue
                for (let j = 0; j < view.children.length; ++j) {
                    const tile = view.children[j] as PunchiDockTile
                    if (!tile || tile.objectName !== "launcher-files") continue
                    activationTimer.stop()
                    tile.clicked()
                    tile.clicked()
                    if (!tile.feedbackRunning || view.currentIndex !== 0)
                        console.error("PUNCHI_LAUNCH_FAILED")
                    else console.warn("PUNCHI_LAUNCH_DISPATCHED")
                    return
                }
            }
            console.error("PUNCHI_LAUNCH_FAILED_NO_TILE")
            Qt.quit()
        }
    }
}
''')
        try:
            result = subprocess.run(['qs', '--path', str(config), '--no-color'],
                                    capture_output=True, text=True, timeout=8)
            output = result.stdout + result.stderr
            if result.returncode or 'PUNCHI_LAUNCH_DISPATCHED' not in output:
                raise RuntimeError(output)
            if any(message in output for message in ('ERROR', 'TypeError', 'Binding loop', 'PUNCHI_LAUNCH_FAILED')):
                raise RuntimeError(output)
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                lines = captured.read_text().splitlines() if captured.exists() else []
                expected_count = 2 if '--window' in sys.argv else 3
                if len(lines) == expected_count and not owned_processes(script):
                    break
                time.sleep(0.05)
            else:
                raise RuntimeError('Launch sentinel did not finish the expected requests.')
            expected = [['argument with spaces']] * 2
            if '--window' not in sys.argv: expected.append(['native desktop action'])
            assert sorted([json.loads(line) for line in lines]) == sorted(expected), lines
            print('KDE lookup, desktop actions, repeated launch, argument parsing, invalid IDs, and async errors: passed'
                  if '--window' not in sys.argv else
                  'Real dock activation → service → desktop launch, with coalesced bounce: passed')
        finally:
            # Detached launches have their own session; own their exact script path.
            for pid in owned_processes(script):
                try:
                    os.kill(pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
            deadline = time.monotonic() + 2
            while owned_processes(script) and time.monotonic() < deadline:
                time.sleep(0.05)
            if owned_processes(script):
                raise RuntimeError('Launch sentinel cleanup failed.')
            desktop.unlink(missing_ok=True)
            broken.unlink(missing_ok=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
