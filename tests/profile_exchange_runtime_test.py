#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Exercise the real profile exchange through Quickshell and the native adapter."""
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile
import time


def file_url(path):
    return Path(path).absolute().as_uri()


def main():
    root = Path(__file__).resolve().parents[1]
    assert os.environ.get('QT_QPA_PLATFORM') == 'offscreen', 'Use the isolated offscreen runner.'
    with tempfile.TemporaryDirectory(prefix='punchi-profile-exchange-') as directory:
        work = Path(directory)
        config = work / 'config-tree'
        config.mkdir()
        for name in ('config', 'services', 'adapters'):
            shutil.copytree(root / name, config / name)
        pragmas = '\n'.join(line for line in (root / 'shell.qml').read_text().splitlines()
                            if line.startswith('//@ pragma '))
        (config / 'shell.qml').write_text(pragmas + '\n' + '''import QtQuick
import Quickshell
import Quickshell.Io
import "config"
import "services"
ShellRoot {
    PunchiShellSettings { id: settings }
    PunchiProfileExchangeService { id: exchange; target: settings }
    IpcHandler {
        target: "profile"
        function snapshot(): string { return JSON.stringify(settings.snapshot()) }
        function importFile(path: string): string {
            const accepted = exchange.importFrom(path)
            return JSON.stringify({ok: accepted, notice: exchange.notice,
                pending: exchange.hasPending, summary: exchange.pendingSummary})
        }
        function confirm(): string {
            return JSON.stringify({ok: exchange.confirmImport(), notice: exchange.notice})
        }
        function cancel(): bool { exchange.cancelImport(); return true }
        function exportFile(path: string): string {
            return JSON.stringify({ok: exchange.exportTo(path), notice: exchange.notice})
        }
    }
}
''')
        env = os.environ.copy()
        env['PUNCHI_DOCK_MODE'] = 'desktop'
        env.pop('WAYLAND_DISPLAY', None)
        log_path = work / 'runtime.log'
        with log_path.open('w') as log:
            process = subprocess.Popen(['qs', '--path', str(config), '--no-color'],
                                       env=env, stdout=log, stderr=log)
            try:
                def call(method, *args):
                    result = subprocess.run(
                        ['qs', 'ipc', '--path', str(config), 'call', 'profile', method, *args],
                        capture_output=True, text=True, timeout=4)
                    assert result.returncode == 0, result.stderr + log_path.read_text()
                    return json.loads(result.stdout)

                deadline = time.monotonic() + 8
                while time.monotonic() < deadline:
                    if process.poll() is not None:
                        raise RuntimeError(log_path.read_text())
                    try:
                        initial = call('snapshot')
                        break
                    except (AssertionError, json.JSONDecodeError):
                        time.sleep(0.05)
                else:
                    raise RuntimeError(log_path.read_text() + '\nProfile probe did not start.')

                imported = json.loads(json.dumps(initial))
                imported['panelMode'] = 'reserve'
                imported['sizePercent'] = 80
                imported['pinnedIds'] = ['files', 'item:trash']
                valid = work / 'valid profile.json'
                valid.write_text(json.dumps({
                    'schema': 'punchi-dock-quickshell/profile',
                    'version': 1,
                    'profile': imported,
                }))
                result = call('importFile', file_url(valid))
                assert result['ok'] is True, result
                assert result['pending'] is True, result
                assert result['summary'] == '2 dock items and 2 folder containers', result
                assert call('snapshot')['panelMode'] == 'overlay', call('snapshot')
                cancelled = call('cancel')
                assert cancelled is True
                assert call('snapshot')['panelMode'] == 'overlay'
                assert call('importFile', file_url(valid))['ok'] is True
                confirmed = call('confirm')
                assert confirmed['ok'] is True, confirmed
                applied = call('snapshot')
                assert applied['panelMode'] == 'reserve', applied
                assert applied['sizePercent'] == 80, applied
                assert applied['pinnedIds'] == ['files', 'item:trash'], applied

                invalid = work / 'invalid.json'
                invalid.write_text('{}')
                result = call('importFile', file_url(invalid))
                assert result['ok'] is False and result['pending'] is False, result
                assert result['notice'] == 'The file is not a Punchi Dock Quickshell profile.', result
                assert call('snapshot')['panelMode'] == 'reserve'

                oversized = work / 'oversized.json'
                oversized.write_text(' ' * (256 * 1024 + 1))
                result = call('importFile', file_url(oversized))
                assert result['ok'] is False, result
                assert result['notice'] == 'The file exceeds 256 KiB.', result

                fifo = work / 'pipe.json'
                os.mkfifo(fifo)
                result = call('importFile', file_url(fifo))
                assert result['ok'] is False, result
                assert result['notice'] == 'The path is not a regular file.', result

                exported = work / 'exported.json'
                result = call('exportFile', file_url(exported))
                assert result['ok'] is True, result
                document = json.loads(exported.read_text())
                assert document['schema'] == 'punchi-dock-quickshell/profile'
                assert document['version'] == 1
                assert document['profile']['panelMode'] == 'reserve'
                mode = stat.S_IMODE(exported.stat().st_mode)
                assert mode == 0o600, oct(mode)

                target = work / 'symlink-target.json'
                target.write_text('original')
                link = work / 'symlink.json'
                link.symlink_to(target)
                result = call('exportFile', file_url(link))
                assert result['ok'] is False, result
                assert result['notice'] == 'Symbolic links cannot be overwritten. Choose a new name.', result
                assert target.read_text() == 'original'
                print('Profile exchange through Quickshell and the native adapter: passed')
            finally:
                process.terminate()
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        output = log_path.read_text()
        assert not any(marker in output for marker in
                       ('ReferenceError', 'TypeError', 'Unable to assign', 'Binding loop')), output
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
