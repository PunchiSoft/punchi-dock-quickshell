#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check the CMake install layout, its installed entry points and uninstall."""

from pathlib import Path
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts-dev'))
from build_dir import resolve_build_dir  # noqa: E402


def write_executable(path: Path, content: str) -> None:
    path.write_text(content)
    path.chmod(0o755)


def script_environment(home: Path, fake_bin: Path, qs_log: Path) -> dict:
    for name in ('config', 'cache', 'data', 'state', 'runtime'):
        (home / name).mkdir(mode=0o700)
    environment = os.environ.copy()
    environment.update({
        'HOME': str(home),
        'TMPDIR': str(home),
        'XDG_CONFIG_HOME': str(home / 'config'),
        'XDG_CACHE_HOME': str(home / 'cache'),
        'XDG_DATA_HOME': str(home / 'data'),
        'XDG_STATE_HOME': str(home / 'state'),
        'XDG_RUNTIME_DIR': str(home / 'runtime'),
        'PATH': f'{fake_bin}:{environment.get("PATH", "")}',
        'PUNCHI_ALLOW_NON_KDE': '1',
        'PUNCHI_TEST_QS_LOG': str(qs_log),
        'QML_IMPORT_PATH': '',
        'NO_COLOR': '1',
        'TERM': 'dumb',
    })
    return environment


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    build = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else resolve_build_dir(root)
    if not (build / 'punchi-window-state').is_file():
        print('Build artifacts are unavailable; run this test after building.')
        return 0

    with tempfile.TemporaryDirectory(prefix='punchi-cmake-install-test-') as temporary:
        workspace = Path(temporary)
        prefix = workspace / 'prefix'
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
        plugin = data_root / 'qml/Punchi/Kde/libpunchikdeplugin.so'
        native_library = data_root / 'qml/Punchi/Kde/libpunchikde.so'
        assert plugin.is_file()
        assert native_library.is_file()
        for entry in ('start.sh', 'restore-kde.sh', 'settings.sh', 'launcher.sh'):
            script = data_root / 'scripts-user' / entry
            assert script.is_file() and os.access(script, os.X_OK), entry
        for helper in ('build-dir.sh', 'notice-dialog.sh', 'session-detect.sh'):
            assert (data_root / 'scripts-user/lib' / helper).is_file(), helper
        assert 'Exec=punchi-dock-quickshell' in desktop.read_text()

        help_result = subprocess.run(
            [str(launcher), '--help'], cwd=root, capture_output=True, text=True,
            check=False, timeout=20)
        assert help_result.returncode == 0, help_result.stdout + help_result.stderr
        assert 'Usage:' in help_result.stdout

        home = workspace / 'home'
        home.mkdir()
        fake_bin = home / 'bin'
        fake_bin.mkdir()
        qs_log = home / 'qs.log'
        write_executable(fake_bin / 'qs', '''#!/usr/bin/env bash
printf 'ARGS=%s\\n' "$*" >> "$PUNCHI_TEST_QS_LOG"
if [[ "${1:-}" == "list" ]]; then printf '[]\\n'; exit 0; fi
printf 'QML_IMPORT_PATH=%s\\n' "${QML_IMPORT_PATH:-}" >> "$PUNCHI_TEST_QS_LOG"
printf 'PUNCHI_WINDOW_BACKEND=%s\\n' "${PUNCHI_WINDOW_BACKEND:-}" >> "$PUNCHI_TEST_QS_LOG"
exit 0
''')
        write_executable(fake_bin / 'kbuildsycoca6', '#!/usr/bin/env bash\nexit 0\n')
        environment = script_environment(home, fake_bin, qs_log)

        start_script = data_root / 'scripts-user/start.sh'
        start_help = subprocess.run(
            [str(start_script), '--help'], cwd=home, env=environment,
            capture_output=True, text=True, check=False, timeout=20)
        assert start_help.returncode == 0, start_help.stdout + start_help.stderr
        assert 'Usage:' in start_help.stdout
        assert 'missing' not in start_help.stderr.lower(), start_help.stderr

        restore_script = data_root / 'scripts-user/restore-kde.sh'
        restore = subprocess.run(
            [str(restore_script)], cwd=home, env=environment,
            capture_output=True, text=True, check=False, timeout=30)
        assert restore.returncode == 0, restore.stdout + restore.stderr
        assert 'already stopped' in restore.stdout, restore.stdout

        qs_log.unlink(missing_ok=True)
        start = subprocess.run(
            [str(start_script)], cwd=home, env=environment,
            capture_output=True, text=True, check=False, timeout=30)
        assert start.returncode == 0, start.stdout + start.stderr
        captured = qs_log.read_text()
        lines = captured.splitlines()
        arguments = [line.removeprefix('ARGS=') for line in lines if line.startswith('ARGS=')]
        assert f'--path {data_root} --no-duplicate' in arguments, captured
        qml_path = next(line.removeprefix('QML_IMPORT_PATH=') for line in lines
            if line.startswith('QML_IMPORT_PATH='))
        backend_path = next(line.removeprefix('PUNCHI_WINDOW_BACKEND=') for line in lines
            if line.startswith('PUNCHI_WINDOW_BACKEND='))
        assert Path(qml_path).resolve() == (data_root / 'qml').resolve(), qml_path
        assert Path(backend_path).resolve() == backend.resolve(), backend_path
        assert str(root) not in captured, captured

        registration = home / 'data/applications/org.punchi.Shell.WindowState.desktop'
        assert registration.is_file()
        registration_text = registration.read_text()
        assert f'Exec="{backend.resolve()}"' in registration_text, registration_text
        assert 'Name=Punchi Dock Quickshell Window State' in registration_text

        uninstall = subprocess.run(
            ['cmake', '--build', str(build), '--target', 'uninstall'],
            cwd=root, capture_output=True, text=True, check=False, timeout=120)
        assert uninstall.returncode == 0, uninstall.stdout + uninstall.stderr
        assert not launcher.exists()
        assert not desktop.exists()
        assert not icon.exists()
        assert not backend.exists()
        assert not start_script.exists()
        assert not (data_root / 'scripts-user/lib/build-dir.sh').exists()

    print('CMake install/uninstall: layout, entry points, runtime resolution and targets passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
