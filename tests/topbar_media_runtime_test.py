#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Select and control one of two owned MPRIS players through the top panel."""
import json
import multiprocessing
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
from media_runtime_test import player_fixture  # noqa: E402


def ipc(config, method, *args):
    return subprocess.run(['qs', 'ipc', '--path', str(config), 'call', 'media', method, *args],
                          capture_output=True, text=True, timeout=3)


def main():
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix='punchi-topbar-media-') as directory:
        work = Path(directory)
        capture = work / 'commands.txt'
        fixtures, readiness = [], []
        for name, desktop, status in [
                ('org.mpris.MediaPlayer2.punchiPlaying', 'punchi-playing-media', 'Playing'),
                ('org.mpris.MediaPlayer2.punchiPaused', 'punchi-paused-media', 'Paused')]:
            ready = multiprocessing.Event()
            fixture = multiprocessing.Process(
                target=player_fixture, args=(ready, str(capture), name, desktop, status))
            fixtures.append(fixture)
            readiness.append(ready)
            fixture.start()
        try:
            assert all(ready.wait(5) for ready in readiness), 'Owned player initialization timed out'
            config = work / 'config'
            (config / 'adapters' / 'kde').mkdir(parents=True)
            (config / 'services').mkdir()
            shutil.copy(root / 'adapters/kde/PunchiMprisAdapter.qml', config / 'adapters/kde')
            shutil.copy(root / 'services/PunchiMediaControlService.qml', config / 'services')
            shell = config / 'shell.qml'
            shell.write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import "adapters/kde"
import "services"
ShellRoot {
    PunchiMprisAdapter { id: mpris; active: true }
    PunchiMediaControlService { id: media; provider: mpris }
    IpcHandler {
        target: "media"
        function state(): string {
            return JSON.stringify({available: media.available,
                playerName: media.playerName, title: media.title,
                artist: media.artist, playing: media.playing,
                canPrevious: media.canPrevious, canNext: media.canNext,
                canPlayPause: media.canPlayPause})
        }
        function command(value: string): bool { return media.dispatch(value) }
    }
}
''')
            process = subprocess.Popen(['qs', '-p', str(shell), '--no-color'],
                                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            try:
                deadline = time.monotonic() + 10
                state = None
                while time.monotonic() < deadline:
                    result = ipc(config, 'state')
                    if result.returncode == 0:
                        try:
                            state = json.loads(result.stdout)
                        except json.JSONDecodeError:
                            state = None
                        if state is not None and state['available']:
                            break
                    if process.poll() is not None:
                        raise RuntimeError(process.stdout.read())
                    time.sleep(0.03)
                assert state is not None, 'media state timed out'
                # The playing player wins even though the paused one is present.
                assert state['playerName'] == 'punchi-playing-media', state
                assert state['playing'] is True, state
                assert state['canNext'] is True, state
                assert ipc(config, 'command', 'next').stdout.strip() == 'true'
                assert ipc(config, 'command', 'previous').stdout.strip() == 'true'
                deadline = time.monotonic() + 3
                lines = []
                while time.monotonic() < deadline:
                    if capture.exists():
                        lines = capture.read_text().splitlines()
                        if len(lines) >= 2:
                            break
                    time.sleep(0.03)
                assert lines == ['punchi-playing-media:Next', 'punchi-playing-media:Previous'], lines
                print('Top-panel MPRIS: playing-player selection and announced commands passed.')
            finally:
                process.terminate()
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        finally:
            for fixture in fixtures:
                fixture.terminate()
                fixture.join(3)
                if fixture.is_alive():
                    fixture.kill()
                    fixture.join(3)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
