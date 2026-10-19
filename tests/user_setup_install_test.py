#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Exercise the user-local install and uninstall flow in isolated XDG paths."""

from pathlib import Path
import os
import re
import shutil
import subprocess
import tempfile


def project_version(root: Path) -> str:
    content = (root / 'CMakeLists.txt').read_text()
    match = re.search(r'^project\([^)]*\bVERSION\s+([0-9.]+)', content, re.M)
    assert match, 'Project version not found'
    return match.group(1)


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    version = project_version(root)
    build = root / 'build'
    if not (build / 'qml/Punchi/Kde/libpunchikdeplugin.so').is_file() \
            or not (build / 'punchi-window-state').is_file():
        print('Build artifacts are unavailable; run this test after building.')
        return 0

    setup = root / 'scripts-user/setup.sh'
    with tempfile.TemporaryDirectory(prefix='punchi-install-test-') as temporary:
        home = Path(temporary)
        install_root = home / 'install'
        config = home / 'config'
        config.mkdir()
        preferences = config / 'punchi-dock-quickshell.json'
        preferences.write_text('{"schemaVersion": 6}\n')

        environment = os.environ.copy()
        environment.update({
            'HOME': str(home),
            'XDG_DATA_HOME': str(home / 'data'),
            'XDG_CONFIG_HOME': str(config),
            'XDG_STATE_HOME': str(home / 'state'),
            'XDG_RUNTIME_DIR': str(home / 'runtime'),
            'TERM': 'dumb',
            'NO_COLOR': '1',
        })
        (home / 'runtime').mkdir(mode=0o700)

        install = subprocess.run(
            ['bash', str(setup), '--install', '--prefix', str(install_root),
             '--yes', '--no-color'],
            cwd=root, env=environment, capture_output=True, text=True,
            check=False, timeout=180)
        assert install.returncode == 0, install.stdout + install.stderr

        marker = install_root / '.punchi-dock-quickshell-install'
        manifest = install_root / '.punchi-dock-quickshell-files'
        version_file = install_root / '.punchi-dock-quickshell-version'
        launcher = home / 'data/applications/punchi-dock-quickshell.desktop'
        installed_launcher = install_root / 'scripts-user/launcher.sh'
        assert marker.is_file()
        assert manifest.is_file()
        assert version_file.read_text().strip() == version
        assert installed_launcher.is_file() and os.access(installed_launcher, os.X_OK)
        assert launcher.is_file()
        desktop_entry = launcher.read_text()
        assert f'Exec="{install_root}/scripts-user/launcher.sh"' in desktop_entry
        assert 'Actions=Stop;Settings;' in desktop_entry
        assert '[Desktop Action Stop]' in desktop_entry
        assert '[Desktop Action Settings]' in desktop_entry
        assert preferences.is_file()
        assert (root / 'build').is_dir()

        qs = shutil.which('qs')
        if qs:
            listed = subprocess.run(
                [qs, 'list', '--path', str(install_root), '--json'],
                cwd=root, env=environment, capture_output=True, text=True,
                check=False, timeout=10)
            output = listed.stdout.strip()
            assert output == '[]' or output.startswith('No running instances'), output

        uninstall = subprocess.run(
            ['bash', str(setup), '--uninstall', '--prefix', str(install_root),
             '--yes', '--no-color'],
            cwd=root, env=environment, capture_output=True, text=True,
            check=False, timeout=60)
        assert uninstall.returncode == 0, uninstall.stdout + uninstall.stderr
        assert not install_root.exists()
        assert not launcher.exists()
        assert preferences.is_file()
        assert (root / 'build').is_dir()

        remove_settings = subprocess.run(
            ['bash', str(setup), '--uninstall', '--prefix', str(install_root),
             '--remove-settings', '--yes', '--no-color'],
            cwd=root, env=environment, capture_output=True, text=True,
            check=False, timeout=60)
        assert remove_settings.returncode == 0, \
            remove_settings.stdout + remove_settings.stderr
        assert not preferences.exists()
        assert (root / 'build').is_dir()

    print('User setup install/uninstall: isolated cycle passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
