#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Exercise DND read validity and owner changes on an owned private bus."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

SERVICE = 'org.freedesktop.Notifications'
PATH = '/org/freedesktop/Notifications'


class FakeNotifications(dbus.service.Object):
    def __init__(self, bus, mode):
        self.bus = bus
        self.mode = mode
        self.owner = dbus.service.BusName(SERVICE, bus)
        super().__init__(self.owner, PATH)

    @dbus.service.method('org.freedesktop.DBus.Properties', in_signature='ss',
                         out_signature='v')
    def Get(self, interface, prop):
        if prop != 'Inhibited':
            raise dbus.exceptions.DBusException(
                'No such property', name='org.freedesktop.DBus.Error.UnknownProperty')
        if self.mode == 'unknown':
            raise dbus.exceptions.DBusException(
                'No such property', name='org.freedesktop.DBus.Error.UnknownProperty')
        if self.mode == 'invalid':
            return dbus.String('yes')
        return dbus.Boolean(self.mode == 'true')

    @dbus.service.signal('org.freedesktop.DBus.Properties', signature='sa{sv}as')
    def PropertiesChanged(self, interface, changed, invalidated):
        pass

    def retire(self):
        self.remove_from_connection()
        self.owner = None


def ipc(config, method):
    return subprocess.run(['qs', 'ipc', '--path', str(config), 'call', 'dnd', method],
                          capture_output=True, text=True, timeout=3)


def read_state(config):
    result = ipc(config, 'state')
    if result.returncode != 0:
        return None
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return None


def wait_for(config, predicate, deadline=8):
    end = time.monotonic() + deadline
    last = None
    while time.monotonic() < end:
        last = read_state(config)
        if last is not None and predicate(last):
            return last
        time.sleep(0.04)
    raise AssertionError(f'DND state did not settle: {last!r}')


def main():
    root = Path(__file__).resolve().parents[1]
    DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    loop = GLib.MainLoop()
    loop_thread = threading.Thread(target=loop.run, daemon=True)
    loop_thread.start()
    fake = FakeNotifications(bus, 'true')
    with tempfile.TemporaryDirectory(prefix='punchi-dnd-state-') as directory:
        work = Path(directory)
        shell = work / 'shell.qml'
        shell.write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import Punchi.Kde as Native
ShellRoot {
    Native.NotificationStateControl { id: dnd; monitoring: true }
    IpcHandler {
        target: "dnd"
        function state(): string {
            return JSON.stringify({available: dnd.available, reading: dnd.reading,
                valid: dnd.valid, inhibited: dnd.inhibited, lastError: dnd.lastError})
        }
        function read(): bool { dnd.refresh(); return true }
    }
}
''')
        env = os.environ.copy()
        env['QT_QPA_PLATFORM'] = 'offscreen'
        env.pop('QT_QUICK_CONTROLS_STYLE', None)
        process = subprocess.Popen(['qs', '-p', str(shell), '--no-color'],
                                   env=env, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True)
        try:
            wait_for(shell, lambda state: state['available'] and state['valid'])

            # A valid boolean is the only thing that may appear as a state.
            fake.mode = 'false'
            ipc(shell, 'read')
            state = wait_for(shell, lambda item: item['valid'] and not item['inhibited'])
            assert state['lastError'] == '', state

            # UnknownProperty invalidates instead of keeping the default Off.
            fake.mode = 'unknown'
            ipc(shell, 'read')
            state = wait_for(shell, lambda item: not item['valid'])
            assert state['available'] is True, state
            assert state['inhibited'] is False, state
            assert state['lastError'] == 'unknown-property', state

            # A wrongly typed reply is not coerced to a boolean.
            fake.mode = 'invalid'
            ipc(shell, 'read')
            state = wait_for(shell, lambda item: item['lastError'] == 'invalid-type')
            assert state['valid'] is False, state
            assert state['inhibited'] is False, state

            # Owner loss invalidates the state; a new owner can recover it.
            fake.retire()
            fake = None
            state = wait_for(shell, lambda item: not item['available'])
            assert state['valid'] is False, state
            assert state['lastError'] in ('no-service', 'owner-changed'), state

            fake = FakeNotifications(bus, 'false')
            state = wait_for(shell, lambda item: item['available'] and item['valid'])
            assert state['inhibited'] is False, state
            assert state['lastError'] == '', state
            print('DND read validity, UnknownProperty, invalid type and owner recovery: passed')
        finally:
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            if fake is not None:
                fake.retire()
            loop.quit()
            loop_thread.join(3)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
