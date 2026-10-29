#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Test the real Activities Stats model against owned SQLite and D-Bus data."""
import json
import multiprocessing
import os
from pathlib import Path
import shutil
import signal
import sqlite3
import subprocess
import tempfile
import time
from launch_runtime_test import owned_processes

ACTIVITY = '11111111-1111-1111-1111-111111111111'
AGENT = 'punchi-recent-sentinel'


def activity_fixture(database, ready, forgotten):
    import dbus
    import dbus.service
    from dbus.mainloop.glib import DBusGMainLoop
    from gi.repository import GLib
    DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    owner = dbus.service.BusName('org.kde.ActivityManager', bus)

    class Application(dbus.service.Object):
        @dbus.service.method('org.kde.ActivityManager.Application', out_signature='s')
        def serviceVersion(self):
            return '6.30.0'

    class Activities(dbus.service.Object):
        @dbus.service.method('org.kde.ActivityManager.Activities', out_signature='s')
        def CurrentActivity(self):
            return ACTIVITY

        @dbus.service.method('org.kde.ActivityManager.Activities', out_signature='a(ssssi)')
        def ListActivitiesWithInformation(self):
            return [(ACTIVITY, 'Owned test activity', '', '', 2)]

    class Scoring(dbus.service.Object):
        @dbus.service.signal('org.kde.ActivityManager.ResourcesScoring', signature='sss')
        def ResourceScoreDeleted(self, activity, agent, resource):
            pass

        @dbus.service.method('org.kde.ActivityManager.ResourcesScoring', in_signature='sss')
        def DeleteStatsForResource(self, activity, agent, resource):
            # Record the actual native cleaning query; never touch user history.
            Path(forgotten).write_text(json.dumps([str(activity), str(agent), str(resource)]))
            assert str(activity) == ':current' and str(agent) == AGENT and str(resource) == '*'
            with sqlite3.connect(database) as connection:
                connection.execute('DELETE FROM ResourceScoreCache WHERE usedActivity=? AND initiatingAgent=?',
                                   (ACTIVITY, AGENT))
            self.ResourceScoreDeleted(ACTIVITY, AGENT, '*')

    objects = [Application(owner, '/ActivityManager'), Activities(owner, '/ActivityManager/Activities'),
               Scoring(owner, '/ActivityManager/Resources/Scoring')]
    ready.set()
    GLib.MainLoop().run()


def main():
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix='punchi-recent-') as directory:
        config = Path(directory)
        for name in ('services', 'adapters', 'modules', 'components', 'config'):
            shutil.copytree(root / name, config / name)
        database = Path(os.environ['XDG_DATA_HOME']) / 'kactivitymanagerd/resources/database'
        database.parent.mkdir(parents=True)
        captured = config / 'opened.jsonl'
        forgotten = config / 'forgotten.json'
        script = config / 'capture.py'
        script.write_text('import json, sys\nwith open(sys.argv[1], "a") as output:\n output.write(json.dumps(sys.argv[2:]) + "\\n")\n')
        applications = Path(os.environ['XDG_DATA_HOME']) / 'applications'
        applications.mkdir()
        desktop = applications / f'{AGENT}.desktop'
        desktop.write_text('[Desktop Entry]\nType=Application\nName=Recent sentinel\n'
                           f'Exec=/usr/bin/python3 "{script}" "{captured}" %U\n'
                           'Terminal=false\nStartupNotify=false\nMimeType=image/png;\n')
        single = applications / 'punchi-single-sentinel.desktop'
        single.write_text('[Desktop Entry]\nType=Application\nName=Single sentinel\n'
                          'Exec=/punchi-nonexistent-test\nSingleMainWindow=true\n')
        with sqlite3.connect(database) as connection:
            connection.execute('PRAGMA journal_mode=WAL')
            connection.executescript('''
                CREATE TABLE ResourceScoreCache (usedActivity TEXT, initiatingAgent TEXT,
                    targettedResource TEXT, scoreType INTEGER, cachedScore FLOAT, firstUpdate INTEGER, lastUpdate INTEGER);
                CREATE TABLE ResourceInfo (targettedResource TEXT, title TEXT, mimetype TEXT, autoTitle INTEGER, autoMimetype INTEGER);
                CREATE TABLE ResourceLink (usedActivity TEXT, initiatingAgent TEXT, targettedResource TEXT);
            ''')
            for number in range(9):
                resource = str(config / f'picture {number}.png')
                Path(resource).touch()
                activity = ACTIVITY if number != 8 else '22222222-2222-2222-2222-222222222222'
                agent = AGENT if number != 7 else 'other-application'
                connection.execute('INSERT INTO ResourceScoreCache VALUES (?,?,?,?,?,?,?)',
                                   (activity, agent, resource, 0, 1.0, 1, number + 1))
                connection.execute('INSERT INTO ResourceInfo VALUES (?,?,?,?,?)', (resource, 'Fixture', 'image/png', 1, 1))
        (config / 'shell.qml').write_text('''import QtQuick
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
    function reject(reason: string) { console.error("PUNCHI_RECENT_FAILED", reason); Qt.quit() }
    FloatingWindow {
        visible: true
        implicitWidth: 480
        implicitHeight: 640
        PunchiDockContextContent { recentDocuments: context.recentDocuments; canLaunchNewWindow: context.canLaunchNewWindow; pinned: context.pinned }
    }
    PunchiDesktopApplicationAdapter {
        id: adapter
        onLaunchFinished: function(id, success, error) {
            if (!success) probe.reject(error)
            else probe.completed++
        }
    }
    QtObject { id: settings; property var pinnedIds: ["desktop:punchi-recent-sentinel.desktop"] }
    ListModel {
        id: entries
        ListElement { appId: "desktop:punchi-recent-sentinel.desktop"; desktopId: "punchi-recent-sentinel" }
    }
    PunchiApplicationContextService { id: context; entries: entries; settings: settings; adapter: adapter }
    Instantiator {
        id: rows
        model: context.recentDocuments
        delegate: QtObject { required property string resource; required property string name; required property string iconName }
    }
    Timer {
        interval: 150
        running: true
        repeat: true
        onTriggered: {
            if (++probe.ticks > 50) { probe.reject("model timed out"); return }
            if (probe.stage === 0) {
                if (adapter.applicationCount === 0) return
                context.select("desktop:punchi-recent-sentinel.desktop")
                probe.stage++
            } else if (probe.stage === 1) {
                if (rows.count !== 5) return
                if (rows.objectAt(0).name !== "picture 6.png"
                    || rows.objectAt(4).name !== "picture 2.png"
                    || !context.canLaunchNewWindow || !context.pinned || context.canPin
                    || adapter.canLaunchNewWindow("punchi-single-sentinel")
                    || adapter.canLaunchNewWindow("/tmp/unsafe.desktop")
                    || context.openRecent("/not-in-current-history.png")) {
                    probe.reject("scope, ordering or eligibility failed"); return
                }
                if (!context.openRecent(rows.objectAt(0).resource) || !context.openNewWindow()) {
                    probe.reject("native activation rejected"); return
                }
                probe.stage++
            } else if (probe.stage === 2) {
                if (probe.completed !== 2) return
                if (!context.forgetRecent()) { probe.reject("forget rejected"); return }
                probe.stage++
            } else if (probe.stage === 3) {
                if (rows.count !== 0) return
                if (!context.unpin() || context.pinned || !context.canPin || settings.pinnedIds.length !== 0 || context.unpin()) {
                    probe.reject("unpin did not update settings"); return
                }
                if (!context.pin() || !context.pinned || context.canPin
                    || settings.pinnedIds[0] !== "desktop:punchi-recent-sentinel.desktop" || context.pin()) {
                    probe.reject("pin did not add the eligible running app exactly once"); return
                }
                if (!context.unpin()) { probe.reject("could not reset pin eligibility fixture"); return }
                settings.pinnedIds = Array.from({length: 32}, function(_, index) {
                    return "desktop:pinned-limit-" + index + ".desktop"
                })
                if (context.canPin || context.pin()) {
                    probe.reject("maximum pin count was not enforced"); return
                }
                settings.pinnedIds = []
                context.select("not-configured")
                if (context.appId !== "" || context.canLaunchNewWindow || context.openNewWindow()) {
                    probe.reject("unknown app accepted"); return
                }
                console.warn("PUNCHI_RECENT_PASSED")
                Qt.quit()
            }
        }
    }
}
''')
        ready = multiprocessing.Event()
        fixture = multiprocessing.Process(target=activity_fixture, args=(str(database), ready, str(forgotten)))
        fixture.start()
        try:
            assert ready.wait(3), 'Owned Activities service did not start'
            command = ['qs', '--path', str(config), '--no-color']
            environment = os.environ.copy()
            environment.pop('WAYLAND_DISPLAY', None)
            result = subprocess.run(command, env=environment, capture_output=True, text=True, timeout=20)
            output = result.stdout + result.stderr
            print(output, end='')
            assert result.returncode == 0 and 'PUNCHI_RECENT_PASSED' in output, output
            assert not any(value in output for value in (' ERROR:', 'PUNCHI_RECENT_FAILED', 'Unable to assign',
                'ReferenceError', 'different thread', 'overrides a member', 'Error at ResultSetPrivate')), output
            deadline = time.monotonic() + 3
            while time.monotonic() < deadline:
                lines = captured.read_text().splitlines() if captured.exists() else []
                if len(lines) == 2:
                    break
                time.sleep(0.05)
            # KIO expands local %U resources to local paths, preserving spaces as one argument.
            assert sorted(map(json.loads, lines)) == [[], [str(config / 'picture 6.png')]], lines
            assert json.loads(forgotten.read_text()) == [':current', AGENT, '*']
            with sqlite3.connect(database) as connection:
                assert connection.execute('SELECT count(*) FROM ResourceScoreCache').fetchone()[0] == 2
            print('Native recent model: app/activity scope, five latest entries, URL launch, scoped clearing and unpin passed.')
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
                raise RuntimeError('Recent sentinel cleanup failed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
