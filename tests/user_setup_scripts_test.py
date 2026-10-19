#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check the user setup scripts' syntax, help and menu contract."""

from pathlib import Path
from typing import Optional
import os
import shutil
import subprocess
import tempfile
import time


def run_script(root: Path, script: Path, *arguments: str,
               input_text: Optional[str] = None) -> subprocess.CompletedProcess:
    with tempfile.TemporaryDirectory(prefix='punchi-setup-test-') as temporary:
        home = Path(temporary)
        environment = os.environ.copy()
        environment.update({
            'HOME': str(home),
            'XDG_DATA_HOME': str(home / 'data'),
            'XDG_CONFIG_HOME': str(home / 'config'),
            'XDG_STATE_HOME': str(home / 'state'),
            'TERM': 'dumb',
            'NO_COLOR': '1',
        })
        return subprocess.run(
            ['bash', str(script), *arguments],
            cwd=root,
            env=environment,
            input=input_text,
            text=True,
            capture_output=True,
            check=False,
            timeout=30,
        )


def check_single_instance_guard(root: Path, start: Path) -> None:
    flock = shutil.which('flock')
    if not flock:
        return

    with tempfile.TemporaryDirectory(prefix='punchi-instance-test-') as temporary:
        home = Path(temporary)
        fake_bin = home / 'bin'
        fake_bin.mkdir()
        fake_qs = fake_bin / 'qs'
        fake_qs.write_text(
            '#!/usr/bin/env bash\n'
            'if [[ "${1:-}" == "list" ]]; then\n'
            '    if [[ "${3:-}" == "/tmp/punchi-other" ]]; then\n'
            '        printf \'%s\\n\' \'[{"id":"other"}]\'\n'
            '    else\n'
            '        printf \'%s\\n\' \'[]\'\n'
            '    fi\n'
            '    exit 0\n'
            'fi\n'
            'exit 0\n')
        fake_qs.chmod(0o755)

        runtime = home / 'runtime'
        runtime.mkdir()
        lock_dir = runtime / f'punchi-dock-quickshell-{os.getuid()}'
        lock_dir.mkdir()
        instance_path = lock_dir / 'instance.path'
        instance_path.write_text('/tmp/punchi-other\n')

        environment = os.environ.copy()
        environment.update({
            'HOME': str(home),
            'XDG_DATA_HOME': str(home / 'data'),
            'XDG_CONFIG_HOME': str(home / 'config'),
            'XDG_STATE_HOME': str(home / 'state'),
            'PUNCHI_RUNTIME_DIR': str(runtime),
            'PATH': f'{fake_bin}:{environment.get("PATH", "")}',
            'TERM': 'dumb',
            'NO_COLOR': '1',
        })

        holder = subprocess.Popen([
            'bash', '-c',
            f'exec 9>"{lock_dir / "instance.lock"}"; {flock} -n 9; exec sleep 10',
        ])
        try:
            time.sleep(0.2)
            blocked = subprocess.run(
                ['bash', str(start)], cwd=root, env=environment,
                capture_output=True, text=True, check=False, timeout=10)
            combined = blocked.stdout + blocked.stderr
            assert blocked.returncode != 0
            assert 'already running from' in combined
            assert '/tmp/punchi-other' in combined
        finally:
            holder.terminate()
            try:
                holder.wait(timeout=3)
            except subprocess.TimeoutExpired:
                holder.kill()
                holder.wait()

        instance_path.unlink()
        applications = home / 'data' / 'applications'
        applications.mkdir(parents=True)
        (applications / 'org.punchi.Shell.WindowState.desktop').write_text(
            '[Desktop Entry]\n'
            'Type=Application\n'
            'Name=Punchi Dock Quickshell Window State\n'
            'NoDisplay=true\n'
            'Terminal=false\n'
            'Exec="/tmp/punchi-other/build/punchi-window-state"\n'
            'X-KDE-Wayland-Interfaces=org_kde_plasma_window_management\n')
        detected = subprocess.run(
            ['bash', str(start)], cwd=root, env=environment,
            capture_output=True, text=True, check=False, timeout=10)
        combined = detected.stdout + detected.stderr
        assert detected.returncode != 0
        assert 'already running from' in combined
        assert '/tmp/punchi-other' in combined


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    scripts = sorted((root / 'scripts-user').rglob('*.sh'))
    assert scripts, 'No user scripts found'

    for script in scripts:
        result = subprocess.run(
            ['bash', '-n', str(script)],
            cwd=root,
            capture_output=True,
            text=True,
            check=False,
        )
        assert result.returncode == 0, f'Syntax error in {script}: {result.stderr}'

    setup = root / 'scripts-user/setup.sh'
    start = root / 'scripts-user/start.sh'

    help_result = run_script(root, setup, '--help')
    assert help_result.returncode == 0, help_result.stderr
    for option in ('--install', '--check-deps', '--uninstall', '--start',
                   '--instructions', '--prefix'):
        assert option in help_result.stdout, option

    start_help = run_script(root, start, '--help')
    assert start_help.returncode == 0, start_help.stderr
    assert 'setup.sh' in start_help.stdout

    menu = run_script(root, setup, '--no-color', input_text='8\n')
    assert menu.returncode == 0, menu.stderr
    for label in (
        'Install or update',
        'Check runtime and build dependencies',
        'Uninstall',
        'Instructions and README',
    ):
        assert label in menu.stdout, label

    relative_prefix = run_script(
        root, setup, '--uninstall', '--prefix', 'relative/path', '--yes')
    assert relative_prefix.returncode != 0
    assert 'absolute path' in relative_prefix.stderr

    invalid_settings = run_script(root, setup, '--remove-settings', '--yes')
    assert invalid_settings.returncode != 0
    assert 'requires --uninstall' in invalid_settings.stderr

    invalid_missing = run_script(root, setup, '--install-missing', '--yes')
    assert invalid_missing.returncode != 0
    assert 'requires --check-deps' in invalid_missing.stderr

    check_single_instance_guard(root, start)
    print('User setup scripts: syntax, help, menu and instance guard passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
