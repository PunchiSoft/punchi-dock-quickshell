#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check the CMake install layout and its uninstall target."""

from pathlib import Path
import os
import subprocess
import tempfile


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    build = root / 'build'
    if not (build / 'punchi-window-state').is_file():
        print('Build artifacts are unavailable; run this test after building.')
        return 0

    with tempfile.TemporaryDirectory(prefix='punchi-cmake-install-test-') as temporary:
        prefix = Path(temporary) / 'prefix'
        install = subprocess.run(
            ['cmake', '--install', str(build), '--prefix', str(prefix)],
            cwd=root, capture_output=True, text=True, check=False, timeout=120)
        assert install.returncode == 0, install.stdout + install.stderr

        launcher = prefix / 'bin/punchi-dock-quickshell'
        desktop = prefix / 'share/applications/punchi-dock-quickshell.desktop'
        icon = prefix / 'share/icons/hicolor/scalable/apps/punchi-dock-quickshell.svg'
        backend = prefix / 'libexec/punchi-dock-quickshell/punchi-window-state'
        data_root = prefix / 'share/punchi-dock-quickshell'
        assert launcher.is_file() and os.access(launcher, os.X_OK)
        assert desktop.is_file()
        assert icon.is_file()
        assert backend.is_file() and os.access(backend, os.X_OK)
        assert (data_root / 'shell.qml').is_file()
        assert (data_root / 'qml/Punchi/Kde/libpunchikdeplugin.so').is_file()
        assert (data_root / 'qml/Punchi/Kde/libpunchikde.so').is_file()
        assert (data_root / 'scripts-user/launcher.sh').is_file()
        assert (data_root / 'scripts-user/lib/session-detect.sh').is_file()
        assert (data_root / 'scripts-user/lib/notice-dialog.sh').is_file()
        assert 'Exec=punchi-dock-quickshell' in desktop.read_text()

        help_result = subprocess.run(
            [str(launcher), '--help'], cwd=root, capture_output=True, text=True,
            check=False, timeout=20)
        assert help_result.returncode == 0, help_result.stdout + help_result.stderr
        assert 'Usage:' in help_result.stdout

        uninstall = subprocess.run(
            ['cmake', '--build', str(build), '--target', 'uninstall'],
            cwd=root, capture_output=True, text=True, check=False, timeout=120)
        assert uninstall.returncode == 0, uninstall.stdout + uninstall.stderr
        assert not launcher.exists()
        assert not desktop.exists()
        assert not icon.exists()
        assert not backend.exists()

    print('CMake install/uninstall: layout and targets passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
