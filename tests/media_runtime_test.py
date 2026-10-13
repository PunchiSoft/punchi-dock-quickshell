#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Exercise the installed KDE MPRIS provider on an owned private bus."""
import multiprocessing
from pathlib import Path
import shutil
import subprocess
import tempfile


def player_fixture(ready, capture, name, desktop):
    import dbus
    import dbus.service
    from dbus.mainloop.glib import DBusGMainLoop
    from gi.repository import GLib
    DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    player_interface = 'org.mpris.MediaPlayer2.Player'
    root_interface = 'org.mpris.MediaPlayer2'
    owners = []

    class Player(dbus.service.Object):
        def __init__(self, name, desktop):
            self.player_bus = dbus.SessionBus(private=True)
            self.service_name = name
            self.owner = dbus.service.BusName(name, self.player_bus)
            owners.append(self.owner)
            self.desktop = desktop
            self.status = 'Playing'
            self.next_enabled = True
            super().__init__(self.owner, '/org/mpris/MediaPlayer2')

        def properties(self, interface):
            if interface == root_interface:
                return {'Identity': self.desktop, 'DesktopEntry': self.desktop,
                        'CanRaise': False, 'CanQuit': False, 'HasTrackList': False,
                        'SupportedUriSchemes': dbus.Array([], signature='s'),
                        'SupportedMimeTypes': dbus.Array([], signature='s')}
            return {'PlaybackStatus': self.status, 'CanControl': True,
                    'CanGoPrevious': True, 'CanGoNext': self.next_enabled,
                    'CanPlay': True, 'CanPause': True, 'CanSeek': False,
                    'Position': dbus.Int64(0), 'Rate': 1.0, 'MinimumRate': 1.0, 'MaximumRate': 1.0,
                    'Volume': 0.5, 'Shuffle': False, 'LoopStatus': 'None',
                    'Metadata': dbus.Dictionary({'xesam:title': 'Owned track',
                        'xesam:artist': dbus.Array(['Owned artist'], signature='s'),
                        'mpris:trackid': dbus.ObjectPath('/owned/track')}, signature='sv')}

        @dbus.service.method('org.freedesktop.DBus.Properties', in_signature='s', out_signature='a{sv}')
        def GetAll(self, interface):
            return self.properties(interface)

        @dbus.service.method('org.freedesktop.DBus.Properties', in_signature='ss', out_signature='v')
        def Get(self, interface, property):
            return self.properties(interface)[property]

        @dbus.service.signal('org.freedesktop.DBus.Properties', signature='sa{sv}as')
        def PropertiesChanged(self, interface, changed, invalidated):
            pass

        def record(self, command):
            with open(capture, 'a') as output:
                output.write(self.desktop + ':' + command + '\n')

        @dbus.service.method(player_interface)
        def PlayPause(self):
            self.record('PlayPause')
            self.status = 'Paused' if self.status == 'Playing' else 'Playing'
            self.PropertiesChanged(player_interface, {'PlaybackStatus': self.status}, [])

        @dbus.service.method(player_interface)
        def Previous(self):
            self.record('Previous')
            self.PropertiesChanged(player_interface, {'Metadata': dbus.Dictionary({
                'xesam:title': 'Previous owned track',
                'xesam:artist': dbus.Array(['Owned artist'], signature='s')}, signature='sv')}, [])

        @dbus.service.method(player_interface)
        def Next(self):
            self.record('Next')
            self.next_enabled = False
            self.PropertiesChanged(player_interface, {'CanGoNext': False}, [])

        @dbus.service.method(player_interface)
        def Stop(self):
            self.record('Stop')
            self.status = 'Stopped'
            self.PropertiesChanged(player_interface, {'PlaybackStatus': self.status}, [])
            def retire():
                self.remove_from_connection()
                self.player_bus.release_name(self.service_name)
                self.player_bus.close()
                owners.remove(self.owner)
                self.owner = None
                return False
            GLib.timeout_add(600, retire)

    objects = [Player(name, desktop)]
    ready.set()
    GLib.MainLoop().run()


def main():
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix='punchi-media-') as directory:
        capture = Path(directory) / 'commands.txt'
        fixtures, readiness = [], []
        for name, desktop in [('org.mpris.MediaPlayer2.punchiOwned', 'punchi-owned-media'),
                              ('org.mpris.MediaPlayer2.punchiOther', 'punchi-other-media')]:
            ready = multiprocessing.Event()
            fixture = multiprocessing.Process(target=player_fixture, args=(ready, str(capture), name, desktop))
            fixtures.append(fixture)
            readiness.append(ready)
            fixture.start()
        try:
            assert all(ready.wait(5) for ready in readiness), 'Owned player initialization timed out'
            runner = shutil.which('qmltestrunner') or '/usr/lib64/qt6/bin/qmltestrunner'
            result = subprocess.run([runner, '-input', str(root / 'tests/runtime/media')],
                                    capture_output=True, text=True, timeout=20)
            print(result.stdout + result.stderr, end='')
            assert result.returncode == 0
            assert capture.read_text().splitlines() == ['punchi-owned-media:' + command for command in
                ('PlayPause', 'Previous', 'Next', 'PlayPause', 'Stop')]
            print('KDE MPRIS: scoped discovery, native commands, live capabilities and departure passed.')
        finally:
            for fixture in fixtures:
                fixture.terminate()
                fixture.join(3)
                if fixture.is_alive():
                    fixture.kill()
                    fixture.join(3)
                if fixture.is_alive():
                    raise RuntimeError('Owned player cleanup failed')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
