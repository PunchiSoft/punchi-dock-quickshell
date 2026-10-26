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
            'PUNCHI_ALLOW_NON_KDE': '1',
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


def check_dependency_maps(root: Path) -> None:
    common = root / 'scripts-user/lib/setup-common.sh'
    library = root / 'scripts-user/lib/setup-deps.sh'
    result = subprocess.run(
        ['bash', '-c',
         f'source "{common}"; source "{library}"; '
         'punchi_package_group debian runtime; echo ---; '
         'punchi_package_group arch build; echo ---; '
         'punchi_distro_family ubuntu debian'],
        cwd=root, capture_output=True, text=True, check=False)
    assert result.returncode == 0, result.stderr
    debian, arch, family = result.stdout.split('---')
    assert 'quickshell' in debian
    assert 'qml6-module-org-kde-kirigami' in debian
    assert 'qt6-base' in arch
    assert 'extra-cmake-modules' in arch
    assert family.strip() == 'debian'


def check_failure_log(root: Path) -> None:
    with tempfile.TemporaryDirectory(prefix='punchi-log-test-') as temporary:
        home = Path(temporary)
        transcript = home / 'build.log'
        transcript.write_text('compiler output for the failure\n')
        environment = os.environ.copy()
        environment.update({
            'HOME': str(home),
            'XDG_CONFIG_HOME': str(home / 'config'),
            'XDG_STATE_HOME': str(home / 'state'),
            'PUNCHI_INSTALL_PREFIX': str(home / 'install'),
            'NO_COLOR': '1',
            'TERM': 'dumb',
        })
        result = subprocess.run(
            ['bash', '-c',
             f'set -euo pipefail; punchi_project_root="{root}"; '
             f'source "{root}/scripts-user/lib/setup-common.sh"; '
             f'source "{root}/scripts-user/lib/setup-deps.sh"; '
             f'punchi_write_failure_log build "{transcript}"'],
            cwd=root, env=environment, capture_output=True, text=True,
            check=False, timeout=30)
        assert result.returncode == 0, result.stdout + result.stderr
        logs = list((home / 'Documents').glob('punchi-dock-quickshell-setup-*.log'))
        assert len(logs) == 1, logs
        content = logs[0].read_text()
        assert 'Punchi Dock Quickshell setup failure' in content
        assert 'Action: build' in content
        assert 'compiler output for the failure' in content


def check_restore_active_instance(root: Path, restore: Path) -> None:
    with tempfile.TemporaryDirectory(prefix='punchi-restore-test-') as temporary:
        home = Path(temporary)
        fake_bin = home / 'bin'
        fake_bin.mkdir()
        qs_log = home / 'qs.log'
        backend_log = home / 'backend.log'
        fake_qs = fake_bin / 'qs'
        fake_qs.write_text(
            '#!/usr/bin/env bash\n'
            f'printf "%s\\n" "$*" >> "{qs_log}"\n'
            'if [[ "${1:-}" == "list" ]]; then\n'
            f'    if [[ "${{3:-}}" == "{home / "active"}" ]]; then\n'
            f'        if [[ -f "{home / "killed"}" ]]; then echo "[]"; else echo \'[{{"id":"active"}}]\'; fi\n'
            '    else\n'
            '        echo "[]"\n'
            '    fi\n'
            '    exit 0\n'
            'fi\n'
            'if [[ "${1:-}" == "kill" ]]; then\n'
            f'    touch "{home / "killed"}"\n'
            '    exit 0\n'
            'fi\n'
            'exit 0\n')
        fake_qs.chmod(0o755)

        active = home / 'active'
        (active / 'scripts-user').mkdir(parents=True)
        (active / 'build').mkdir()
        (active / 'shell.qml').write_text('import "modules/dock"\n')
        (active / 'scripts-user/restore-kde.sh').write_text('#!/usr/bin/env bash\n')
        backend = active / 'build/punchi-window-state'
        backend.write_text(
            '#!/usr/bin/env bash\n'
            f'printf "%s\\n" "$*" >> "{backend_log}"\n')
        backend.chmod(0o755)

        runtime = home / 'runtime'
        lock_dir = runtime / f'punchi-dock-quickshell-{os.getuid()}'
        lock_dir.mkdir(parents=True)
        (lock_dir / 'instance.path').write_text(str(active) + '\n')

        environment = os.environ.copy()
        environment.update({
            'HOME': str(home),
            'XDG_STATE_HOME': str(home / 'state'),
            'XDG_RUNTIME_DIR': str(runtime),
            'PATH': f'{fake_bin}:{environment.get("PATH", "")}',
            'NO_COLOR': '1',
            'TERM': 'dumb',
        })
        result = subprocess.run(
            ['bash', str(restore)], cwd=root, env=environment,
            capture_output=True, text=True, check=False, timeout=20)
        assert result.returncode == 0, result.stdout + result.stderr
        qs_content = qs_log.read_text()
        assert f'kill --path {active}' in qs_content
        assert '--restore-desktop-settings' in backend_log.read_text()
        assert f'kill --path {root}' not in qs_content


def check_build_failure_log(root: Path) -> None:
    with tempfile.TemporaryDirectory(prefix='punchi-build-fail-test-') as temporary:
        home = Path(temporary)
        fake_bin = home / 'bin'
        fake_bin.mkdir()
        fake_cmake = fake_bin / 'cmake'
        fake_cmake.write_text('#!/usr/bin/env bash\nprintf "simulated compiler failure\\n" >&2\nexit 1\n')
        fake_cmake.chmod(0o755)
        environment = os.environ.copy()
        environment.update({
            'HOME': str(home),
            'TMPDIR': str(home),
            'XDG_CONFIG_HOME': str(home / 'config'),
            'XDG_STATE_HOME': str(home / 'state'),
            'PUNCHI_INSTALL_PREFIX': str(home / 'install'),
            'PATH': f'{fake_bin}:{environment.get("PATH", "")}',
            'NO_COLOR': '1',
            'TERM': 'dumb',
        })
        result = subprocess.run(
            ['bash', '-c',
             f'set -euo pipefail; punchi_project_root="{root}"; '
             f'source "{root}/scripts-user/lib/setup-common.sh"; '
             f'source "{root}/scripts-user/lib/setup-deps.sh"; '
             f'source "{root}/scripts-user/lib/setup-install.sh"; '
             'if punchi_build_checkout; then exit 10; fi'],
            cwd=root, env=environment, capture_output=True, text=True,
            check=False, timeout=30)
        assert result.returncode == 0, result.stdout + result.stderr
        logs = list((home / 'Documents').glob('punchi-dock-quickshell-setup-*.log'))
        assert len(logs) == 1, logs
        assert 'simulated compiler failure' in logs[0].read_text()


def check_qt_tool_resolution(root: Path) -> None:
    bash = shutil.which('bash') or '/bin/bash'
    with tempfile.TemporaryDirectory(prefix='punchi-qt-tools-test-') as temporary:
        base = Path(temporary)
        qt_bin = base / 'qt' / 'bin'
        qt_bin.mkdir(parents=True)
        fake_tool = qt_bin / 'qtpaths6'
        fake_tool.write_text('#!/usr/bin/env bash\nexit 0\n')
        fake_tool.chmod(0o755)
        empty_path = base / 'empty-path'
        empty_path.mkdir()

        environment = os.environ.copy()
        environment.update({
            'PATH': str(empty_path),
            'PUNCHI_QT_BIN_DIRS': str(qt_bin),
            'NO_COLOR': '1',
            'TERM': 'dumb',
        })
        result = subprocess.run(
            [bash, '-c',
             f'set -euo pipefail; punchi_project_root="{root}"; '
             f'source "{root}/scripts-user/lib/setup-common.sh"; '
             f'source "{root}/scripts-user/lib/setup-deps.sh"; '
             'punchi_resolve_command qtpaths6'],
            cwd=root, env=environment, capture_output=True, text=True,
            check=False, timeout=30)
        assert result.returncode == 0, result.stdout + result.stderr
        assert result.stdout.strip() == str(fake_tool), result.stdout


def check_update_check(root: Path) -> None:
    git = shutil.which('git')
    if not git:
        return

    with tempfile.TemporaryDirectory(prefix='punchi-updates-test-') as temporary:
        base = Path(temporary)
        remote = base / 'remote.git'
        source = base / 'source'
        clone = base / 'clone'
        home = base / 'home'
        home.mkdir()

        environment = os.environ.copy()
        environment.update({
            'HOME': str(home),
            'XDG_DATA_HOME': str(home / 'data'),
            'XDG_CONFIG_HOME': str(home / 'config'),
            'XDG_STATE_HOME': str(home / 'state'),
            'GIT_AUTHOR_NAME': 'Punchi Test',
            'GIT_AUTHOR_EMAIL': 'test@example.invalid',
            'GIT_COMMITTER_NAME': 'Punchi Test',
            'GIT_COMMITTER_EMAIL': 'test@example.invalid',
            'GIT_CONFIG_GLOBAL': os.devnull,
            'GIT_CONFIG_SYSTEM': os.devnull,
            'NO_COLOR': '1',
            'TERM': 'dumb',
        })

        def git_run(*arguments: str, cwd: Path) -> subprocess.CompletedProcess:
            result = subprocess.run(
                [git, *arguments], cwd=cwd, env=environment,
                capture_output=True, text=True, check=False, timeout=30)
            assert result.returncode == 0, result.stdout + result.stderr
            return result

        def write_version(target: Path, version: str) -> None:
            (target / 'CMakeLists.txt').write_text(
                'project(punchi-dock-quickshell VERSION '
                f'{version} LANGUAGES C CXX)\n')

        git_run('init', '--bare', '-b', 'main', str(remote), cwd=base)
        git_run('init', '-b', 'main', str(source), cwd=base)
        write_version(source, '0.1.20')
        git_run('add', 'CMakeLists.txt', cwd=source)
        git_run('commit', '-m', 'local checkout', cwd=source)
        git_run('remote', 'add', 'origin', str(remote), cwd=source)
        git_run('push', '-u', 'origin', 'main', cwd=source)
        git_run('clone', str(remote), str(clone), cwd=base)
        write_version(clone, '0.1.21')
        git_run('add', 'CMakeLists.txt', cwd=clone)
        git_run('commit', '-m', 'upstream delivery', cwd=clone)
        git_run('push', 'origin', 'main', cwd=clone)

        before = git_run('rev-parse', 'HEAD', cwd=source).stdout.strip()
        result = subprocess.run(
            ['bash', '-c',
             f'set -euo pipefail; punchi_project_root="{source}"; '
             f'source "{root}/scripts-user/lib/setup-common.sh"; '
             f'source "{root}/scripts-user/lib/setup-updates.sh"; '
             'punchi_check_updates'],
            cwd=root, env=environment, capture_output=True, text=True,
            check=False, timeout=60)
        combined = result.stdout + result.stderr
        assert result.returncode == 0, combined
        assert '1 commit(s) behind origin/main' in combined, combined
        assert '0.1.21' in combined, combined
        assert 'git pull --ff-only' in combined, combined

        after = git_run('rev-parse', 'HEAD', cwd=source).stdout.strip()
        assert before == after, 'The update check must not pull or rewrite HEAD'

        write_version(source, '0.1.20 locally edited')
        dirty = subprocess.run(
            ['bash', '-c',
             f'punchi_project_root="{source}"; '
             f'source "{root}/scripts-user/lib/setup-common.sh"; '
             f'source "{root}/scripts-user/lib/setup-updates.sh"; '
             'punchi_check_updates pull'],
            cwd=root, env=environment, capture_output=True, text=True,
            check=False, timeout=60)
        dirty_output = dirty.stdout + dirty.stderr
        assert dirty.returncode != 0, dirty_output
        assert 'Refusing to pull' in dirty_output, dirty_output
        assert git_run('rev-parse', 'HEAD', cwd=source).stdout.strip() == before

        git_run('checkout', '--', 'CMakeLists.txt', cwd=source)
        pulled = subprocess.run(
            ['bash', '-c',
             f'punchi_project_root="{source}"; '
             f'source "{root}/scripts-user/lib/setup-common.sh"; '
             f'source "{root}/scripts-user/lib/setup-updates.sh"; '
             'punchi_check_updates pull'],
            cwd=root, env=environment, capture_output=True, text=True,
            check=False, timeout=60)
        pulled_output = pulled.stdout + pulled.stderr
        assert pulled.returncode == 0, pulled_output
        assert 'Checkout updated' in pulled_output, pulled_output
        assert 'Rebuild and install now?' not in pulled_output, pulled_output
        assert git_run('rev-parse', 'HEAD', cwd=source).stdout.strip() \
            == git_run('rev-parse', 'HEAD', cwd=clone).stdout.strip()
        assert '0.1.21' in (source / 'CMakeLists.txt').read_text()

        # Interactive prompt mode offers to rebuild and install after a
        # successful pull. PUNCHI_ASSUME_YES drives both confirmations without
        # a TTY; the install callback is stubbed so the test never builds.
        write_version(clone, '0.1.22')
        git_run('add', 'CMakeLists.txt', cwd=clone)
        git_run('commit', '-m', 'upstream install prompt', cwd=clone)
        git_run('push', 'origin', 'main', cwd=clone)
        prompted_environment = environment.copy()
        prompted_environment['PUNCHI_ASSUME_YES'] = '1'
        prompted = subprocess.run(
            ['bash', '-c',
             f'punchi_project_root="{source}"; '
             f'source "{root}/scripts-user/lib/setup-common.sh"; '
             f'source "{root}/scripts-user/lib/setup-updates.sh"; '
             'punchi_action_install() { printf "INSTALL_CALLED\\n"; }; '
             'punchi_check_updates prompt'],
            cwd=root, env=prompted_environment, capture_output=True, text=True,
            check=False, timeout=60)
        prompted_output = prompted.stdout + prompted.stderr
        assert prompted.returncode == 0, prompted_output
        assert 'Checkout updated' in prompted_output, prompted_output
        assert 'INSTALL_CALLED' in prompted_output, prompted_output
        assert git_run('rev-parse', 'HEAD', cwd=source).stdout.strip() \
            == git_run('rev-parse', 'HEAD', cwd=clone).stdout.strip()
        assert '0.1.22' in (source / 'CMakeLists.txt').read_text()


def check_autostart_uninstall(root: Path) -> None:
    with tempfile.TemporaryDirectory(prefix='punchi-autostart-uninstall-') as temporary:
        home = Path(temporary)
        config = home / 'config'
        autostart = config / 'autostart'
        autostart.mkdir(parents=True)
        foreign = autostart / 'punchi-dock-quickshell.desktop'
        foreign.write_text('[Desktop Entry]\nName=Foreign\n')
        environment = os.environ.copy()
        environment.update({
            'HOME': str(home),
            'XDG_CONFIG_HOME': str(config),
            'TERM': 'dumb',
            'NO_COLOR': '1',
        })
        command = (
            f'punchi_project_root="{root}"; '
            f'source "{root}/scripts-user/lib/setup-common.sh"; '
            f'source "{root}/scripts-user/lib/setup-install.sh"; '
            'punchi_remove_autostart')
        foreign_result = subprocess.run(['bash', '-c', command], cwd=root, env=environment,
                                        capture_output=True, text=True, check=False, timeout=20)
        assert foreign_result.returncode == 0, foreign_result.stdout + foreign_result.stderr
        assert foreign.exists(), 'A foreign autostart entry was removed'
        foreign.write_text('[Desktop Entry]\nName=Punchi Dock Quickshell\n'
                           'X-Punchi-Dock-Quickshell-Owned=true\n')
        owned_result = subprocess.run(['bash', '-c', command], cwd=root, env=environment,
                                      capture_output=True, text=True, check=False, timeout=20)
        assert owned_result.returncode == 0, owned_result.stdout + owned_result.stderr
        assert not foreign.exists(), 'The Punchi-owned autostart entry was kept'


def check_git_missing(root: Path) -> None:
    bash = shutil.which('bash') or '/bin/bash'
    tr = shutil.which('tr')
    if not tr:
        return
    with tempfile.TemporaryDirectory(prefix='punchi-git-missing-test-') as temporary:
        base = Path(temporary)
        restricted = base / 'bin'
        restricted.mkdir()
        (restricted / 'tr').symlink_to(tr)
        os_release = base / 'os-release'
        os_release.write_text(
            'ID=fedora\n'
            'PRETTY_NAME="Fedora Linux 44"\n')
        environment = os.environ.copy()
        environment.update({
            'PATH': str(restricted),
            'PUNCHI_OS_RELEASE_FILE': str(os_release),
            'NO_COLOR': '1',
            'TERM': 'dumb',
        })
        result = subprocess.run(
            [bash, '-c',
             f'punchi_project_root="{root}"; '
             f'source "{root}/scripts-user/lib/setup-common.sh"; '
             f'source "{root}/scripts-user/lib/setup-updates.sh"; '
             'punchi_check_updates check'],
            cwd=root, env=environment, capture_output=True, text=True,
            check=False, timeout=30)
        combined = result.stdout + result.stderr
        assert result.returncode != 0, combined
        assert 'require git' in combined, combined
        assert 'sudo dnf install git' in combined, combined
        assert 'never installs git automatically' in combined, combined


def check_try_requires_checkout(root: Path) -> None:
    """--try/--test exist for the checkout and never install or build blindly."""
    with tempfile.TemporaryDirectory(prefix='punchi-try-test-') as temporary:
        home = Path(temporary)
        install = home / 'install'
        (install / 'scripts-user').mkdir(parents=True)
        shutil.copy2(root / 'scripts-user/setup.sh',
                     install / 'scripts-user/setup.sh')
        shutil.copytree(root / 'scripts-user/lib', install / 'scripts-user/lib')
        environment = os.environ.copy()
        environment.update({
            'HOME': str(home),
            'TMPDIR': str(home),
            'XDG_DATA_HOME': str(home / 'data'),
            'XDG_CONFIG_HOME': str(home / 'config'),
            'XDG_STATE_HOME': str(home / 'state'),
            'PUNCHI_INSTALL_PREFIX': str(install),
            'TERM': 'dumb',
            'NO_COLOR': '1',
        })
        for flag in ('--try', '--test'):
            result = subprocess.run(
                ['bash', str(install / 'scripts-user/setup.sh'), flag],
                cwd=install, env=environment, capture_output=True, text=True,
                check=False, timeout=30)
            combined = result.stdout + result.stderr
            assert result.returncode != 0, combined
            assert 'requires the source checkout' in combined, combined
            assert not (install / 'build').exists(), \
                'The try action started a build without a checkout'


def check_try_flow(root: Path) -> None:
    """The try action builds the checkout, runs it and installs nothing."""
    with tempfile.TemporaryDirectory(prefix='punchi-try-flow-test-') as temporary:
        home = Path(temporary)
        checkout = home / 'checkout'
        (checkout / 'scripts-user').mkdir(parents=True)
        shutil.copy2(root / 'scripts-user/setup.sh',
                     checkout / 'scripts-user/setup.sh')
        shutil.copytree(root / 'scripts-user/lib', checkout / 'scripts-user/lib')
        (checkout / 'CMakeLists.txt').write_text(
            'project(punchi-try-test VERSION 0.1.00)\n')
        (checkout / 'adapters/kde/native').mkdir(parents=True)
        (checkout / 'modules').mkdir()
        (checkout / 'build/qml/Punchi/Kde').mkdir(parents=True)
        (checkout / 'build/qml/Punchi/Kde/libpunchikdeplugin.so').write_text('')
        (checkout / 'build/libpunchikde.so').write_text('')
        backend = checkout / 'build/punchi-window-state'
        backend.write_text('#!/usr/bin/env bash\nexit 0\n')
        backend.chmod(0o755)
        start = checkout / 'scripts-user/start.sh'
        start.write_text('#!/usr/bin/env bash\nprintf "DOCK_STARTED %s\\n" "$*"\nexit 0\n')
        start.chmod(0o755)

        fake_bin = home / 'bin'
        fake_bin.mkdir()
        fake_cmake = fake_bin / 'cmake'
        fake_cmake.write_text('#!/usr/bin/env bash\nexit 0\n')
        fake_cmake.chmod(0o755)

        environment = os.environ.copy()
        environment.update({
            'HOME': str(home),
            'TMPDIR': str(home),
            'XDG_DATA_HOME': str(home / 'data'),
            'XDG_CONFIG_HOME': str(home / 'config'),
            'XDG_STATE_HOME': str(home / 'state'),
            'PATH': f'{fake_bin}:{environment.get("PATH", "")}',
            'TERM': 'dumb',
            'NO_COLOR': '1',
        })
        result = subprocess.run(
            ['bash', str(checkout / 'scripts-user/setup.sh'), '--try',
             '--no-color'],
            cwd=checkout, env=environment, capture_output=True, text=True,
            check=False, timeout=120)
        combined = result.stdout + result.stderr
        if '[1/3] OK Dependencies: Present' not in combined:
            print('try flow skipped: this environment does not satisfy the '
                  'dependency check')
            return
        assert result.returncode == 0, combined
        assert 'DOCK_STARTED' in combined, combined
        assert '[2/3] OK Build: Completed' in combined, combined
        assert '[3/3] OK Run: Completed' in combined, combined
        assert not (home / 'data/punchi-dock-quickshell').exists(), \
            'The try action installed the dock'
        assert not (home / 'data/applications').exists(), \
            'The try action wrote an application-menu launcher'


def check_presentation(root: Path) -> None:
    """The header, the phase lines and the step runner stay machine-readable."""
    bash = shutil.which('bash') or '/bin/bash'
    with tempfile.TemporaryDirectory(prefix='punchi-presentation-test-') as temporary:
        home = Path(temporary)
        log_file = home / 'step.log'
        environment = os.environ.copy()
        environment.update({
            'HOME': str(home),
            'XDG_CONFIG_HOME': str(home / 'config'),
            'XDG_STATE_HOME': str(home / 'state'),
            'TERM': 'dumb',
            'NO_COLOR': '1',
            'PUNCHI_JOBS': '3',
        })

        resources = subprocess.run(
            [bash, '-c',
             f'punchi_project_root="{root}"; '
             f'source "{root}/scripts-user/lib/setup-common.sh"; '
             'punchi_job_count; punchi_auto_job_count; punchi_format_ram_display'],
            cwd=root, env=environment, capture_output=True, text=True,
            check=False, timeout=20)
        assert resources.returncode == 0, resources.stdout + resources.stderr
        lines = resources.stdout.splitlines()
        assert len(lines) == 3, resources.stdout
        assert lines[0] == '3', resources.stdout
        assert lines[1].isdigit() and int(lines[1]) >= 1, resources.stdout
        assert lines[2].endswith(('GiB', 'MiB')), resources.stdout

        header = subprocess.run(
            [bash, '-c',
             f'source "{root}/scripts-user/lib/setup-terminal-ui.sh"; '
             'punchi_ui_render_header "Punchi Dock Quickshell · Setup" '
             '"Version 0.1.00 | Test" "RAM 8.0 GiB | CPU cores 4 | Build jobs 2"; '
             'punchi_ui_render_phase 1 2 success Dependencies Present'],
            cwd=root, env=environment, capture_output=True, text=True,
            check=False, timeout=20)
        assert header.returncode == 0, header.stdout + header.stderr
        assert '\x1b' not in header.stdout, 'ANSI escapes reached a plain stream'
        assert header.stdout.splitlines() == [
            'Punchi Dock Quickshell · Setup',
            'Version 0.1.00 | Test',
            'RAM 8.0 GiB | CPU cores 4 | Build jobs 2',
            '[1/2] OK Dependencies: Present',
        ], header.stdout

        failing = subprocess.run(
            [bash, '-c',
             f'source "{root}/scripts-user/lib/setup-progress.sh"; '
             'step() { echo "compiler output"; return 4; }; '
             f'punchi_run_step "{log_file}" step; printf "status=%s\\n" "$?"; '
             f'cat "{log_file}"'],
            cwd=root, env=environment, capture_output=True, text=True,
            check=False, timeout=30)
        combined = failing.stdout + failing.stderr
        assert 'status=4' in combined, combined
        assert 'compiler output' in combined, combined
        assert log_file.read_text() == 'compiler output\n', log_file.read_text()

        quiet = subprocess.run(
            [bash, '-c',
             f'source "{root}/scripts-user/lib/setup-progress.sh"; '
             'step() { echo "raw output"; }; '
             f'PUNCHI_NO_PROGRESS=1 punchi_run_step "{log_file}" step'],
            cwd=root, env=environment, capture_output=True, text=True,
            check=False, timeout=20)
        assert quiet.returncode == 0, quiet.stdout + quiet.stderr
        assert quiet.stdout == 'raw output\n', quiet.stdout


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
    for option in ('--install', '--check-deps', '--check-updates', '--pull',
                   '--uninstall', '--start', '--try', '--test',
                   '--instructions', '--prefix', '--remove-build'):
        assert option in help_result.stdout, option

    start_help = run_script(root, start, '--help')
    assert start_help.returncode == 0, start_help.stderr
    assert 'setup.sh' in start_help.stdout

    menu = run_script(root, setup, '--no-color', input_text='9\n')
    assert menu.returncode == 0, menu.stderr
    for label in (
        'Install or update',
        'Try it without installing',
        'Start the dock (needs',
        'Check runtime and build dependencies',
        'Check for updates',
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

    invalid_pull = run_script(root, setup, '--pull', '--yes')
    assert invalid_pull.returncode != 0
    assert 'requires --check-updates' in invalid_pull.stderr

    check_single_instance_guard(root, start)
    check_restore_active_instance(root, root / 'scripts-user/restore-kde.sh')
    check_dependency_maps(root)
    check_qt_tool_resolution(root)
    check_try_requires_checkout(root)
    check_try_flow(root)
    check_presentation(root)
    check_failure_log(root)
    check_build_failure_log(root)
    check_update_check(root)
    check_git_missing(root)
    check_autostart_uninstall(root)
    print('User setup scripts: syntax, help, menu, maps, Qt tools, logs, '
          'restore, instance guard, try path, presentation and update check passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
