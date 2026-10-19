#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Run one test tree with parent-owned temporary XDG directories."""

import argparse
import os
from pathlib import Path
import signal
import subprocess
import tempfile


def interrupted(signum, _frame):
    raise KeyboardInterrupt(f"Test interrupted by signal {signum}.")


def main():
    for signum in (signal.SIGTERM, signal.SIGHUP):
        signal.signal(signum, interrupted)
    parser = argparse.ArgumentParser()
    parser.add_argument('--session', action='store_true')
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        parser.error('A command is required.')
    env = os.environ.copy()
    # Read user-installed icon assets without writing into the user's data home.
    data_home = env.get('XDG_DATA_HOME', str(Path.home() / '.local/share'))
    data_dirs = env.get('XDG_DATA_DIRS', '/usr/local/share:/usr/share')
    with tempfile.TemporaryDirectory(prefix='punchi-shell-test-') as temporary:
        root = Path(temporary)
        for kind in ('CONFIG', 'CACHE', 'DATA', 'STATE', 'RUNTIME'):
            directory = root / kind.lower()
            directory.mkdir(mode=0o700)
            env[f'XDG_{kind}_HOME' if kind != 'RUNTIME' else 'XDG_RUNTIME_DIR'] = str(directory)
        # Expose user assets such as icons and color schemes without exposing
        # user service entries: a real applications/ copy would shadow
        # test-owned registrations.
        excluded_entries = {
            'applications', 'services', 'kservices5', 'kservices6',
            'desktop-directories', 'mime', 'dbus-1', 'kactivitymanagerd',
        }
        user_data = Path(data_home)
        if user_data.is_dir():
            for entry in user_data.iterdir():
                if entry.name in excluded_entries:
                    continue
                destination = root / 'data' / entry.name
                if not destination.exists() and not destination.is_symlink():
                    destination.symlink_to(entry)
        env['XDG_DATA_DIRS'] = os.pathsep.join((str(root / 'data'), data_dirs))
        env['QT_QUICK_CONTROLS_STYLE'] = 'Basic'
        native_imports = str(Path(__file__).resolve().parents[1] / 'build/qml')
        env['QML_IMPORT_PATH'] = os.pathsep.join(filter(None, (native_imports, env.get('QML_IMPORT_PATH', ''))))
        # Offscreen Qt otherwise lacks a platform theme for named KDE icons.
        env.setdefault('QT_QPA_PLATFORMTHEME', 'kde')
        env['QS_DISABLE_CRASH_HANDLER'] = '1'
        env['QS_DISABLE_CRASH_REPORTER'] = '1'
        if args.session:
            display = os.environ.get('WAYLAND_DISPLAY', '')
            runtime = os.environ.get('XDG_RUNTIME_DIR', '')
            if not display or not runtime:
                parser.error('A real Wayland session is required.')
            socket = Path(display) if Path(display).is_absolute() else Path(runtime) / display
            if not socket.is_socket():
                parser.error('The Wayland display socket is unavailable.')
            (root / 'runtime' / 'wayland-test').symlink_to(socket)
            env['WAYLAND_DISPLAY'] = 'wayland-test'
            env['QT_QPA_PLATFORM'] = 'wayland'
        else:
            env['QT_QPA_PLATFORM'] = 'offscreen'
        process = subprocess.Popen(command, env=env, start_new_session=True)
        try:
            return process.wait(timeout=35)
        except subprocess.TimeoutExpired:
            print('Test exceeded its 35-second deadline.', flush=True)
            return 1
        finally:
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
            # Ensure remaining members cannot write into directories being removed.
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass


if __name__ == '__main__':
    raise SystemExit(main())
