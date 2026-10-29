#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Exercise native KDE Places and KIO with parent-owned XDG data and bus."""
import json
import multiprocessing
import sqlite3
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time
from launch_runtime_test import owned_processes
from recent_runtime_test import activity_fixture


def main():
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix='punchi-places-') as directory:
        config = Path(directory)
        for name in ('services', 'adapters', 'modules', 'components', 'config'):
            shutil.copytree(root / name, config / name)
        database = Path(os.environ['XDG_DATA_HOME']) / 'kactivitymanagerd/resources/database'
        database.parent.mkdir(parents=True)
        with sqlite3.connect(database) as connection:
            connection.execute('PRAGMA journal_mode=WAL')
            connection.executescript('''
                CREATE TABLE ResourceScoreCache (usedActivity TEXT, initiatingAgent TEXT,
                    targettedResource TEXT, scoreType INTEGER, cachedScore FLOAT, firstUpdate INTEGER, lastUpdate INTEGER);
                CREATE TABLE ResourceInfo (targettedResource TEXT, title TEXT, mimetype TEXT, autoTitle INTEGER, autoMimetype INTEGER);
                CREATE TABLE ResourceLink (usedActivity TEXT, initiatingAgent TEXT, targettedResource TEXT);
            ''')
        captured = config / 'opened.jsonl'
        script = config / 'capture.py'
        script.write_text('import json, sys\nwith open(sys.argv[1], "a") as output:\n output.write(json.dumps(sys.argv[2:]) + "\\n")\n')
        applications = Path(os.environ['XDG_DATA_HOME']) / 'applications'
        applications.mkdir()
        for name, categories in [('punchi-places-sentinel', 'FileManager;'), ('punchi-other-sentinel', 'Utility;')]:
            (applications / f'{name}.desktop').write_text('[Desktop Entry]\nType=Application\nName=Places sentinel\n'
                f'Exec=/usr/bin/python3 "{script}" "{captured}" %U\n'
                f'Categories={categories}\nTerminal=false\nStartupNotify=false\n')
        (Path(os.environ['XDG_CONFIG_HOME']) / 'baloofilerc').write_text('[Basic Settings]\nIndexing-Enabled=false\n')
        paths = [config / f'place {number} ñ' for number in range(9)]
        for path in paths:
            path.mkdir()
        qml = '''import QtQuick
import QtQml.Models
import Quickshell
import "services"
import "adapters/kde"
import "modules/dock"
ShellRoot {
    id: probe
    property int stage: 0
    property int ticks: 0
    property int completed: 0
    property var urls: URL_FIXTURE
    property string staleResource: ""
    function reject(reason: string) { console.error("PUNCHI_PLACES_FAILED", reason); Qt.quit() }
    function sourceIndex(resource: string): var {
        const native = context.places.sourceModel
        for (let row = 0; row < native.rowCount(); ++row) {
            const index = native.index(row, 0)
            if (native.url(index).toString() === decodeURI(resource)) return index
        }
        return null
    }
    FloatingWindow {
        visible: true
        implicitWidth: 600
        implicitHeight: 800
        PunchiDockContextContent {
            places: context.places
            usesPlaces: context.usesPlaces
            recentDocuments: context.recentDocuments
            canLaunchNewWindow: context.canLaunchNewWindow
        }
    }
    PunchiDesktopApplicationAdapter {
        id: adapter
        onLaunchFinished: function(id, success, error) {
            if (!success) probe.reject(error)
            else probe.completed++
        }
    }
    QtObject { id: settings; property var pinnedIds: ["files", "other"] }
    ListModel {
        id: entries
        ListElement { appId: "files"; desktopId: "punchi-places-sentinel" }
        ListElement { appId: "other"; desktopId: "punchi-other-sentinel" }
    }
    PunchiApplicationContextService { id: context; entries: entries; settings: settings; adapter: adapter }
    Instantiator {
        id: rows
        model: context.places
        delegate: QtObject {
            required property string resource
            required property string name
            required property string iconName
            required property string groupName
            required property bool isGroup
            required property bool available
        }
    }
    Timer {
        interval: 150
        running: true
        repeat: true
        onTriggered: {
            if (++probe.ticks > 70) { probe.reject("native model timed out at stage " + probe.stage); return }
            if (probe.stage === 0) {
                if (adapter.applicationCount < 2) return
                context.select("files")
                const native = context.places.sourceModel
                if (!native) { probe.reject("missing native source"); return }
                // Device enumeration can complete later; hide these groups in owned XDG only.
                native.setGroupHidden(4, true)
                native.setGroupHidden(5, true)
                // This entire native model writes only the runner's owned bookmark home.
                for (let row = 0; row < native.rowCount(); ++row) native.setPlaceHidden(native.index(row, 0), true)
                for (let row = 0; row < 8; ++row) native.addPlace("Owned " + row, probe.urls[row], "folder-documents", "")
                native.addPlace("Owned hidden", probe.urls[8], "folder", "")
                native.setPlaceHidden(probe.sourceIndex(probe.urls[8]), true)
                native.addPlace("Owned remote A", "sftp://example.invalid/owned-a", "folder-remote", "")
                native.addPlace("Owned remote B", "sftp://example.invalid/owned-b", "folder-remote", "")
                probe.stage++
            } else if (probe.stage === 1) {
                if (rows.count !== 5) return
                if (!context.usesPlaces || context.places.remainingCount !== 4
                    || rows.objectAt(0).name !== "Owned 0" || rows.objectAt(4).name !== "Owned 4"
                    || rows.objectAt(0).iconName !== "folder-documents"
                    || context.openPlace(probe.urls[8]) || context.openPlace("file:///not-in-places")
                    || context.enterPlacesGroup("not-a-group")) {
                    probe.reject("filter, native data or membership failed"); return
                }
                context.showMorePlaces()
                probe.stage++
            } else if (probe.stage === 2) {
                if (rows.count !== 9) return
                const group = rows.objectAt(8)
                if (!group.isGroup || group.resource !== "" || context.places.remainingCount !== 0
                    || !context.enterPlacesGroup(group.groupName)) {
                    probe.reject("group expansion failed"); return
                }
                probe.stage++
            } else if (probe.stage === 3) {
                if (rows.count !== 2) return
                if (rows.objectAt(0).isGroup || rows.objectAt(0).name !== "Owned remote A"
                    || rows.objectAt(1).name !== "Owned remote B" || context.places.groupName.length === 0
                    || context.openPlace(probe.urls[0])) {
                    probe.reject("group projection failed"); return
                }
                context.leavePlacesGroup()
                probe.stage++
            } else if (probe.stage === 4) {
                if (rows.count !== 9) return
                context.select("files")
                probe.stage++
            } else if (probe.stage === 5) {
                if (rows.count !== 5) return
                if (context.places.showAll || context.places.groupName !== "") {
                    probe.reject("selection did not reset expansion"); return
                }
                probe.staleResource = rows.objectAt(0).resource
                if (!context.openPlace(probe.staleResource)) { probe.reject("KIO opening rejected"); return }
                context.places.sourceModel.editPlace(probe.sourceIndex(probe.urls[0]),
                    "Renamed owned place", probe.urls[0], "folder-pictures", "")
                probe.stage++
            } else if (probe.stage === 6) {
                if (probe.completed !== 1 || rows.objectAt(0).name !== "Renamed owned place") return
                if (rows.objectAt(0).iconName !== "folder-pictures") { probe.reject("native edit not reactive"); return }
                context.places.sourceModel.removePlace(probe.sourceIndex(probe.urls[0]))
                probe.stage++
            } else if (probe.stage === 7) {
                if (context.places.remainingCount !== 3) return
                if (context.openPlace(probe.staleResource)) { probe.reject("removed place accepted"); return }
                context.places.sourceModel.setPlaceHidden(probe.sourceIndex(probe.urls[7]), true)
                probe.stage++
            } else if (probe.stage === 8) {
                // At seven top-level entries KDE no longer truncates the menu.
                if (rows.count !== 7 || context.places.remainingCount !== 0) return
                if (context.openPlace(probe.urls[7])) { probe.reject("newly hidden place accepted"); return }
                context.select("other")
                probe.stage++
            } else if (probe.stage === 9) {
                if (rows.count !== 0) return
                if (context.usesPlaces || context.openPlace(probe.urls[1])) { probe.reject("non-file-manager accepted"); return }
                context.select("not-configured")
                if (context.openPlace(probe.urls[1])) { probe.reject("unconfigured app accepted"); return }
                console.warn("PUNCHI_PLACES_PASSED")
                Qt.quit()
            }
        }
    }
}
'''.replace('URL_FIXTURE', json.dumps([path.as_uri() for path in paths]))
        (config / 'shell.qml').write_text(qml)
        ready = multiprocessing.Event()
        fixture = multiprocessing.Process(target=activity_fixture,
            args=(str(database), ready, str(config / 'unused-forget.json')))
        fixture.start()
        try:
            assert ready.wait(3), 'Owned Activities fixture did not start'
            environment = os.environ.copy()
            environment.pop('WAYLAND_DISPLAY', None)
            result = subprocess.run(['qs', '--path', str(config), '--no-color'], env=environment,
                                    capture_output=True, text=True, timeout=23)
            output = result.stdout + result.stderr
            print(output, end='')
            assert result.returncode == 0 and 'PUNCHI_PLACES_PASSED' in output, output
            assert not any(value in output for value in (' ERROR:', 'PUNCHI_PLACES_FAILED', 'Unable to assign',
                'ReferenceError', 'TypeError', 'different thread', 'overrides a member', 'Binding loop')), output
            deadline = time.monotonic() + 3
            while time.monotonic() < deadline and not captured.exists():
                time.sleep(0.05)
            assert [json.loads(line) for line in captured.read_text().splitlines()] == [[str(paths[0])]]
            print('Native Places: grouping, expansion, hidden rows, reactive edit/removal, category scope and KIO URL launch passed.')
        finally:
            fixture.terminate()
            fixture.join(3)
            if fixture.is_alive():
                fixture.kill()
                fixture.join()
            for pid in owned_processes(script):
                try:
                    os.kill(pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
            deadline = time.monotonic() + 2
            while owned_processes(script) and time.monotonic() < deadline:
                time.sleep(0.05)
            if owned_processes(script):
                raise RuntimeError('Places sentinel cleanup failed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
