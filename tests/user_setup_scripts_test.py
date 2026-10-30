#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check the user setup scripts' syntax, help and menu contract."""

from pathlib import Path
from typing import Optional
import os
import pty
import select
import shlex
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
         'punchi_package_group debian build; echo ---; '
         'punchi_package_group arch build; echo ---; '
         'punchi_distro_family ubuntu debian'],
        cwd=root, capture_output=True, text=True, check=False)
    assert result.returncode == 0, result.stderr
    debian, debian_build, arch, family = result.stdout.split('---')
    assert 'quickshell' in debian
    assert 'qml6-module-org-kde-kirigami' in debian
    assert 'qml6-module-org-kde-desktop' in debian
    assert 'libkf6service-bin' in debian
    assert 'libplasmaactivitiesstats1' in debian
    # pkg-config is the build command no other Debian package in the list
    # depends on, so it has to be named: a live image ships it, a minimal
    # install does not.
    assert 'pkg-config' in debian_build
    assert 'qt6-base' in arch
    assert 'extra-cmake-modules' in arch
    assert family.strip() == 'debian'


def check_build_tree_layout(root: Path) -> None:
    """The build trees stay grouped under build/ and older layouts still resolve."""
    library = root / 'scripts-user/lib/build-dir.sh'

    def resolve(checkout: Path, distro: str, expression: str,
                override: str = '') -> str:
        os_release = checkout / 'os-release'
        os_release.write_text(f'ID={distro}\n')
        environment = f'PUNCHI_OS_RELEASE_FILE={shlex.quote(str(os_release))}; '
        if override:
            environment += f'PUNCHI_BUILD_DIR={shlex.quote(override)}; '
        result = subprocess.run(
            ['bash', '-c',
             f'punchi_project_root={shlex.quote(str(checkout))}; '
             f'{environment}'
             f'source {shlex.quote(str(library))}; {expression}'],
            capture_output=True, text=True, check=False)
        assert result.returncode == 0, result.stderr
        return result.stdout.strip()

    def make_tree(directory: Path) -> None:
        (directory / 'qml/Punchi/Kde').mkdir(parents=True)
        (directory / 'qml/Punchi/Kde/libpunchikdeplugin.so').write_text('')
        (directory / 'libpunchikde.so').write_text('')
        backend = directory / 'punchi-window-state'
        backend.write_text('')
        backend.chmod(0o755)

    with tempfile.TemporaryDirectory(prefix='punchi-build-layout-test-') as temporary:
        checkout = Path(temporary) / 'checkout'
        checkout.mkdir()
        grouped = checkout / 'build/build-debian'
        assert resolve(checkout, 'debian', 'punchi_build_dir') == str(grouped)
        assert resolve(checkout, 'fedora', 'punchi_build_dir') == \
            str(checkout / 'build/build-fedora'), 'Each distribution keeps its own tree'
        assert resolve(checkout, 'debian', 'punchi_build_dir_existing || echo') == \
            '', 'An empty checkout resolves no complete tree'

        flat = checkout / 'build-debian'
        make_tree(flat)
        assert resolve(checkout, 'debian', 'punchi_build_dir_existing') == str(flat), \
            'The flat build-<ID> tree stays readable'

        preset = checkout / 'build/dev'
        make_tree(preset)
        assert resolve(checkout, 'debian', 'punchi_build_dir_existing') == str(preset), \
            'The generic build/dev tree is preferred over the flat tree'

        make_tree(grouped)
        assert resolve(checkout, 'debian', 'punchi_build_dir_existing') == str(grouped), \
            'The distribution tree is preferred once it holds artifacts'

        override = Path(temporary) / 'custom'
        make_tree(override)
        assert resolve(checkout, 'debian', 'punchi_build_dir', str(override)) == \
            str(override), 'PUNCHI_BUILD_DIR overrides the location'
        assert resolve(checkout, 'debian', 'punchi_build_dir_existing', str(override)) == \
            str(override), 'The override is the first complete tree'


def check_debian_backports_offer(root: Path) -> None:
    """Quickshell without an apt candidate is installed from backports first."""
    probe = r'''
source scripts-user/lib/setup-common.sh
source scripts-user/lib/setup-deps.sh
PUNCHI_NO_PROGRESS=1
punchi_distro_id() { printf '%s\n' debian; }
punchi_os_release_value() {
    [[ "${1:-}" == VERSION_CODENAME ]] && printf '%s\n' trixie
}
punchi_missing_packages() {
    case "$1" in
        runtime) printf '%s\n' quickshell ;;
        build)
            if [[ "${PUNCHI_TEST_EXTRA_PACKAGE:-}" == 1 ]]; then
                printf '%s\n' cmake
            fi
            ;;
    esac
}
punchi_apt_config_dir() { printf '%s\n' "${PUNCHI_TEST_APT_DIR:?}"; }
punchi_confirm() {
    printf '%s\n' "$1" >> "${PUNCHI_TEST_PROMPT_LOG:?}"
    case "$1" in
        Add\ *) return "${PUNCHI_TEST_ACCEPT_BACKPORTS:-0}" ;;
        *) return 0 ;;
    esac
}
punchi_offer_dependency_install debian 1
'''

    with tempfile.TemporaryDirectory(prefix='punchi-backports-test-') as temporary:
        home = Path(temporary)
        fake_bin = home / 'bin'
        fake_bin.mkdir()
        apt_log = home / 'apt.log'
        prompt_log = home / 'prompts.log'
        prompt_log.write_text('')
        apt_config = home / 'apt'
        (apt_config / 'sources.list.d').mkdir(parents=True)

        (fake_bin / 'apt-cache').write_text(
            '#!/usr/bin/env bash\n'
            'if [[ "${1:-}" == "policy" ]]; then\n'
            '    printf "%s:\\n  Candidate: %s\\n" "${2:-}" '
            '"${PUNCHI_TEST_CANDIDATE:-(none)}"\n'
            'fi\n')
        (fake_bin / 'apt-get').write_text(
            '#!/usr/bin/env bash\n'
            f'printf "%s\\n" "$*" >> "{apt_log}"\n')
        (fake_bin / 'sudo').write_text(
            '#!/usr/bin/env bash\n'
            'exec "$@"\n')
        for command in (fake_bin / 'apt-cache', fake_bin / 'apt-get',
                        fake_bin / 'sudo'):
            command.chmod(0o755)

        def run(extra: Optional[dict] = None) -> subprocess.CompletedProcess:
            environment = os.environ.copy()
            environment.update({
                'TERM': 'dumb',
                'NO_COLOR': '1',
                'PATH': f'{fake_bin}:{environment.get("PATH", "")}',
                'PUNCHI_TEST_APT_DIR': str(apt_config),
                'PUNCHI_TEST_PROMPT_LOG': str(prompt_log),
            })
            if extra:
                environment.update(extra)
            return subprocess.run(
                [shutil.which('bash') or 'bash', '-c', probe],
                cwd=root, env=environment, capture_output=True, text=True,
                check=False, timeout=30)

        accepted = run({'PUNCHI_TEST_ACCEPT_BACKPORTS': '0'})
        assert accepted.returncode == 0, accepted.stdout + accepted.stderr
        sources = apt_config / 'sources.list.d' / 'debian-backports.list'
        assert sources.read_text().strip() == (
            'deb http://deb.debian.org/debian trixie-backports main')
        log = apt_log.read_text()
        assert 'update' in log, log
        assert 'install -y -t trixie-backports quickshell' in log, log
        assert 'Quickshell was installed from trixie-backports.' in accepted.stdout
        assert 'Missing dependencies (1)' in accepted.stdout, accepted.stdout
        assert 'Required repository' in accepted.stdout, accepted.stdout
        assert 'Repository added: trixie-backports' in accepted.stdout, accepted.stdout
        prompts = prompt_log.read_text().splitlines()
        assert prompts == [
            'Add trixie-backports? [y/N]: ',
            'Install the 1 missing package now? [y/N]: ',
        ], prompts
        apt_log.write_text('')
        prompt_log.write_text('')
        sources.unlink()

        declined = run({
            'PUNCHI_TEST_ACCEPT_BACKPORTS': '1',
            'PUNCHI_TEST_EXTRA_PACKAGE': '1',
        })
        assert declined.returncode == 0, declined.stdout + declined.stderr
        assert not sources.exists()
        log = apt_log.read_text()
        assert 'install -y cmake' in log, log
        assert 'quickshell' not in log, log
        assert 'Quickshell remains missing.' in declined.stdout
        assert 'sudo apt-get install -y -t trixie-backports quickshell' \
            in declined.stdout
        # The repository question and the install question stay separate, and a
        # declined repository keeps quickshell out of the batched apt call.
        assert 'Repository added' not in declined.stdout, declined.stdout
        prompts = prompt_log.read_text().splitlines()
        assert prompts == [
            'Add trixie-backports? [y/N]: ',
            'Install the 1 missing package now? [y/N]: ',
        ], prompts
        prompt_log.write_text('')

        apt_log.write_text('')
        available = run({'PUNCHI_TEST_CANDIDATE': '6.13.0-1'})
        assert available.returncode == 0, available.stdout + available.stderr
        assert not sources.exists()
        log = apt_log.read_text()
        assert 'install -y quickshell' in log, log
        assert '-t trixie-backports' not in log, log


def check_install_failure_clock_hint(root: Path) -> None:
    """A signature that is not valid yet is reported as a clock problem."""
    probe = r'''
source scripts-user/lib/setup-common.sh
source scripts-user/lib/setup-deps.sh
PUNCHI_NO_PROGRESS=1
punchi_run_install_step bash -c 'printf "%s\n" "${PUNCHI_TEST_APT_MESSAGE:?}" >&2; exit 100'
'''

    def run(message: str) -> subprocess.CompletedProcess:
        environment = os.environ.copy()
        environment.update({
            'TERM': 'dumb',
            'NO_COLOR': '1',
            'PUNCHI_TEST_APT_MESSAGE': message,
        })
        return subprocess.run(
            [shutil.which('bash') or 'bash', '-c', probe],
            cwd=root, env=environment, capture_output=True, text=True,
            check=False, timeout=30)

    ahead = run('W: signature verification failed: Not live until '
                '2999-01-01T00:00:00Z')
    assert ahead.returncode != 0
    assert 'the system clock is behind' in ahead.stdout, ahead.stdout
    assert '2999-01-01T00:00:00Z' in ahead.stdout, ahead.stdout
    assert 'timedatectl set-local-rtc 1' in ahead.stdout, ahead.stdout

    behind = run('W: signature verification failed: Not live until '
                 '2000-01-01T00:00:00Z')
    assert behind.returncode != 0
    assert 'the system clock is behind' not in behind.stdout, behind.stdout

    unrelated = run('E: Unable to locate package quickshell')
    assert unrelated.returncode != 0
    assert 'clock' not in unrelated.stdout, unrelated.stdout


def check_dependency_report_layout(root: Path) -> None:
    """The phase report stays compact; the detailed view keeps every item."""
    probe = r'''
source scripts-user/lib/setup-common.sh
source scripts-user/lib/setup-progress.sh
source scripts-user/lib/setup-deps.sh
PUNCHI_NO_PROGRESS=1
# setup.sh installs this teardown for the entry point; the probe calls the
# dependency check directly, so it installs the same trap and proves it runs.
trap punchi_setup_cleanup EXIT
# The report picks its package manager with command -v; this probe runs on
# hosts without rpm.
rpm() { return 0; }
punchi_distro_family() { printf '%s\n' fedora; }
punchi_distro_id() { printf '%s\n' fedora; }
punchi_distro_like() { :; }
punchi_system_name() { printf '%s\n' 'Test Linux'; }
punchi_git_install_hint() { printf '%s\n' 'dnf install git'; }
punchi_command_group() {
    case "$1" in
        runtime) printf '%s\n' bash sh ;;
        build)
            if [[ -n "${LAYOUT_MISSING_COMMAND:-}" ]]; then
                printf '%s\n' grep missing-command-xyz
            else
                printf '%s\n' grep sed
            fi
            ;;
        validation) printf '%s\n' head ;;
    esac
}
punchi_package_group() {
    case "$2" in
        runtime) printf '%s\n' pkg-one pkg-two ;;
        build) printf '%s\n' pkg-three ;;
        validation) printf '%s\n' pkg-four ;;
    esac
}
punchi_package_installed() { [[ "${1:-}" != pkg-three ]]; }
punchi_kde_session_detected() { return 0; }
punchi_dependency_check 0 "$1"
printf 'STATUS=%s\n' "$?"
'''

    def run(detail: str, columns: str = '100',
            extra: Optional[dict] = None) -> subprocess.CompletedProcess:
        environment = os.environ.copy()
        environment.update({
            'TERM': 'dumb',
            'NO_COLOR': '1',
            'COLUMNS': columns,
        })
        if extra:
            environment.update(extra)
        with tempfile.TemporaryDirectory(prefix='punchi-deps-layout-') as temporary:
            environment['TMPDIR'] = temporary
            result = subprocess.run(
                [shutil.which('bash') or 'bash', '-c', probe, 'layout', detail],
                cwd=root, env=environment, capture_output=True, text=True,
                check=False, timeout=30)
            leftovers = sorted(path.name for path in Path(temporary).iterdir())
            assert not leftovers, \
                'the dependency report left temporary files: ' + ', '.join(leftovers)
            return result

    compact = run('0')
    assert compact.returncode == 0, compact.stdout + compact.stderr
    compact_lines = compact.stdout.splitlines()
    assert 'Runtime commands' in compact.stdout, compact.stdout
    assert '2/2 ready' in compact.stdout, compact.stdout
    assert 'Fedora packages' in compact.stdout, compact.stdout
    assert 'runtime 2/2, build 0/1, validation 1/1' in compact.stdout, compact.stdout
    assert '[missing] pkg-three' in compact.stdout, compact.stdout
    assert '[ok] bash' not in compact.stdout, \
        'The compact report expanded installed items'
    assert 'STATUS=1' in compact.stdout, compact.stdout
    assert 'Dependency check' not in compact.stdout, \
        'The phase summary repeated the phase title:\n' + compact.stdout
    assert 'Distribution:' not in compact.stdout, \
        'The phase summary repeated the distribution line:\n' + compact.stdout
    assert not any(line and set(line) == {'-'} for line in compact_lines), \
        'The phase summary printed rules:\n' + compact.stdout
    body = [line for line in compact_lines if not line.startswith('STATUS=')]
    assert len(body) <= 9, 'The compact report is not compact:\n' + compact.stdout

    missing_command = run('0', extra={'LAYOUT_MISSING_COMMAND': '1'})
    assert '1/2 ready' in missing_command.stdout, missing_command.stdout
    assert '[missing] missing-command-xyz' in missing_command.stdout, \
        missing_command.stdout

    detailed = run('1')
    assert detailed.returncode == 0, detailed.stdout + detailed.stderr
    detail_lines = detailed.stdout.splitlines()
    assert 'Dependency check' in detailed.stdout, detailed.stdout
    assert 'Distribution: Test Linux (fedora)' in detailed.stdout, detailed.stdout
    assert '[missing] pkg-three' in detailed.stdout, detailed.stdout
    assert any('[ok] bash' in line and '[ok] sh' in line for line in detail_lines), \
        'The detailed report did not use columns'
    assert any('[ok] pkg-one' in line and '[ok] pkg-two' in line
               for line in detail_lines), detailed.stdout
    assert 'STATUS=1' in detailed.stdout, detailed.stdout

    narrow = run('1', columns='40')
    assert narrow.returncode == 0, narrow.stdout + narrow.stderr
    assert any('[ok] bash' in line and '[ok] sh' not in line
               for line in narrow.stdout.splitlines()), \
        'A narrow terminal must fall back to one item per line'

    measured = run('1', columns='100', extra={'PUNCHI_UI_COLUMNS': '40'})
    assert measured.returncode == 0, measured.stdout + measured.stderr
    assert any('[ok] bash' in line and '[ok] sh' not in line
               for line in measured.stdout.splitlines()), \
        'The width measured by the progress runner must win over COLUMNS'


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
        start.write_text('#!/usr/bin/env bash\nprintf "DOCK_STARTED %s\\n" "$*"\n'
                         'printf "DOCK_PROFILE %s\\n" "${PUNCHI_PROFILE_DIR:-}"\n'
                         'exit "${PUNCHI_FAKE_START_STATUS:-0}"\n')
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
            'XDG_RUNTIME_DIR': str(home / 'run'),
            'PATH': f'{fake_bin}:{environment.get("PATH", "")}',
            'TERM': 'dumb',
            'NO_COLOR': '1',
        })
        environment.pop('PUNCHI_RUNTIME_DIR', None)
        # Synthetic checkouts name their own tree, so the host distribution
        # never decides where the fixture builds.
        environment['PUNCHI_BUILD_DIR'] = str(checkout / 'build')
        (home / 'run').mkdir()
        result = subprocess.run(
            ['bash', str(checkout / 'scripts-user/setup.sh'), '--try',
             '--no-color'],
            cwd=checkout, env=environment, stdin=subprocess.DEVNULL,
            capture_output=True, text=True, check=False, timeout=120)
        combined = result.stdout + result.stderr
        if '[1/3] OK Dependencies: Present' not in combined:
            print('try flow skipped: this environment does not satisfy the '
                  'dependency check')
            return
        assert result.returncode == 0, combined
        assert 'DOCK_STARTED' in combined, combined
        assert '[2/3] OK Build: Completed' in combined, combined
        assert '[3/3] OK Run: Completed' in combined, combined
        profiles = [line.split(' ', 1)[1] for line in combined.splitlines()
                    if line.startswith('DOCK_PROFILE ')]
        assert profiles and profiles[0].startswith(str(home)), combined
        assert not Path(profiles[0]).exists(), \
            'The try cleanup kept the trial profile'
        assert not (checkout / 'build').exists(), \
            'The try cleanup kept the build output'
        assert not (home / 'data/punchi-dock-quickshell').exists(), \
            'The try action installed the dock'
        assert not (home / 'data/applications').exists(), \
            'The try action wrote an application-menu launcher'

        # Ctrl+C stops the dock; the phase reports a stop, not a failure, and
        # the cleanup still runs.
        (checkout / 'build/qml/Punchi/Kde').mkdir(parents=True, exist_ok=True)
        (checkout / 'build/qml/Punchi/Kde/libpunchikdeplugin.so').write_text('')
        (checkout / 'build/libpunchikde.so').write_text('')
        backend.write_text('#!/usr/bin/env bash\nexit 0\n')
        backend.chmod(0o755)
        stopped_environment = dict(environment, PUNCHI_FAKE_START_STATUS='130')
        stopped = subprocess.run(
            ['bash', str(checkout / 'scripts-user/setup.sh'), '--try',
             '--no-color'],
            cwd=checkout, env=stopped_environment, stdin=subprocess.DEVNULL,
            capture_output=True, text=True, check=False, timeout=120)
        combined = stopped.stdout + stopped.stderr
        assert stopped.returncode == 130, combined
        assert 'Run: Stopped' in combined, combined
        assert 'The trial stopped.' in combined, combined
        assert 'Exit status 130' not in combined, combined
        assert not (checkout / 'build').exists(), \
            'A stopped trial skipped the cleanup'


def check_dock_stop_status(root: Path) -> None:
    """Ctrl+C and a logout are reported as a stop, not as a failure."""
    script = (
        'source scripts-user/setup.sh\n'
        'punchi_report_dock_exit 130\n'
        'punchi_report_dock_exit 143\n'
        'punchi_report_dock_exit 0\n'
        'punchi_report_dock_exit 7 || true\n'
        'punchi_status_is_stopped 130 && echo IS_STOPPED_130\n'
        'punchi_status_is_stopped 7 || echo NOT_STOPPED_7\n'
    )
    environment = os.environ.copy()
    environment.update({'TERM': 'dumb', 'NO_COLOR': '1'})
    result = subprocess.run(
        [shutil.which('bash') or 'bash', '-c', script], cwd=root,
        env=environment, capture_output=True, text=True, check=False,
        timeout=30)
    combined = result.stdout + result.stderr
    assert result.returncode == 0, combined
    assert combined.count('The dock stopped.') == 2, combined
    assert 'The dock closed.' in combined, combined
    assert 'The dock exited with status 7.' in combined, combined
    assert 'IS_STOPPED_130' in combined and 'NOT_STOPPED_7' in combined, combined


def check_trial_prompt(root: Path) -> None:
    """The cleanup asks to end the trial instead of warning about a failure."""
    with tempfile.TemporaryDirectory(prefix='punchi-trial-prompt-') as temporary:
        home = Path(temporary)
        environment = session_environment(
            home, desktop='KDE', session_type='wayland', plasma=True)
        profile = home / 'run' / 'punchi-dock-quickshell-1000' / 'trial-profile'
        profile.mkdir(parents=True)
        (profile / 'settings.json').write_text('{}')
        script = (
            f'punchi_project_root="{root}"; '
            f'source "{root}/scripts-user/lib/setup-common.sh"; '
            f'source "{root}/scripts-user/lib/setup-install.sh"; '
            f'punchi_trial_cleanup "{profile}"; echo "CLEANUP_STATUS=$?"'
        )
        output, status = run_in_pty(
            [shutil.which('bash') or 'bash', '-c', script], environment, root,
            input_text='n\n')
        assert status == 0, output
        assert 'End the trial and remove what it created? It deletes the build output,' \
            in output, output
        assert 'Your installed dock and its settings stay untouched. [Y/n]:' in output, output
        assert 'Trial files kept:' in output, output
        assert profile.exists(), 'Declining the cleanup removed the trial profile'


def check_trial_cleanup(root: Path) -> None:
    """Trial cleanup removes the profile, build output, registration and lock."""
    with tempfile.TemporaryDirectory(prefix='punchi-trial-cleanup-') as temporary:
        home = Path(temporary)
        checkout = home / 'checkout'
        (checkout / 'scripts-user').mkdir(parents=True)
        shutil.copytree(root / 'scripts-user/lib', checkout / 'scripts-user/lib')
        (checkout / 'CMakeLists.txt').write_text(
            'project(punchi-trial VERSION 0.1.00)\n')
        (checkout / 'adapters/kde/native').mkdir(parents=True)
        (checkout / 'modules').mkdir()
        build = checkout / 'build'
        build.mkdir()
        (build / 'artifact.bin').write_text('x')

        data = home / 'data'
        applications = data / 'applications'
        applications.mkdir(parents=True)
        registration = applications / 'org.punchi.Shell.WindowState.desktop'
        registration.write_text(
            '[Desktop Entry]\nType=Application\n'
            'Name=Punchi Dock Quickshell Window State\nNoDisplay=true\n'
            f'Exec="{checkout}/build/punchi-window-state"\n'
            'X-KDE-Wayland-Interfaces=org_kde_plasma_window_management\n')

        runtime = home / 'run'
        runtime.mkdir()
        instance = runtime / f'punchi-dock-quickshell-{os.getuid()}'
        instance.mkdir()
        (instance / 'instance.lock').write_text('')
        (instance / 'instance.path').write_text(f'{checkout}\n')
        profile = instance / 'trial-profile'
        profile.mkdir()
        (profile / 'punchi-dock-quickshell.json').write_text('{"version": 11}\n')

        fake_bin = home / 'bin'
        fake_bin.mkdir()
        sycoca = fake_bin / 'kbuildsycoca6'
        sycoca.write_text('#!/usr/bin/env bash\nexit 0\n')
        sycoca.chmod(0o755)

        environment = os.environ.copy()
        environment.update({
            'HOME': str(home),
            'XDG_DATA_HOME': str(data),
            'XDG_CONFIG_HOME': str(home / 'config'),
            'XDG_STATE_HOME': str(home / 'state'),
            'XDG_RUNTIME_DIR': str(runtime),
            'PATH': f'{fake_bin}:{environment.get("PATH", "")}',
            'TERM': 'dumb',
            'NO_COLOR': '1',
        })
        environment.pop('PUNCHI_ASSUME_YES', None)
        environment['PUNCHI_BUILD_DIR'] = str(build)
        command = (
            f'punchi_project_root="{checkout}"; '
            f'source "{checkout}/scripts-user/lib/setup-common.sh"; '
            f'source "{checkout}/scripts-user/lib/setup-install.sh"; '
            f'punchi_trial_cleanup "{profile}"')
        result = subprocess.run(['bash', '-c', command], cwd=checkout,
                                env=environment, stdin=subprocess.DEVNULL,
                                capture_output=True, text=True, check=False,
                                timeout=30)
        combined = result.stdout + result.stderr
        assert result.returncode == 0, combined
        assert not profile.exists(), combined
        assert not build.exists(), 'The trial cleanup kept the build output'
        assert not registration.exists(), 'The window-state entry was kept'
        assert not instance.exists(), 'The runtime lock was kept'
        assert not (home / 'config/punchi-dock-quickshell.json').exists(), \
            'The trial cleanup touched the owned preferences'
        assert sycoca.exists()


def check_trial_refuses_running_copy(root: Path) -> None:
    """A trial never builds or cleans while this checkout is running."""
    with tempfile.TemporaryDirectory(prefix='punchi-trial-running-') as temporary:
        home = Path(temporary)
        checkout = home / 'checkout'
        (checkout / 'scripts-user').mkdir(parents=True)
        shutil.copy2(root / 'scripts-user/setup.sh', checkout / 'scripts-user/setup.sh')
        shutil.copytree(root / 'scripts-user/lib', checkout / 'scripts-user/lib')
        (checkout / 'CMakeLists.txt').write_text(
            'project(punchi-trial VERSION 0.1.00)\n')
        (checkout / 'adapters/kde/native').mkdir(parents=True)
        (checkout / 'modules').mkdir()
        build = checkout / 'build'
        build.mkdir()
        (build / 'artifact.bin').write_text('x')

        fake_bin = home / 'bin'
        fake_bin.mkdir()
        fake_qs = fake_bin / 'qs'
        fake_qs.write_text(
            '#!/usr/bin/env bash\n'
            'printf \'%s\\n\' \'[{"id":"checkout"}]\'\n')
        fake_qs.chmod(0o755)

        environment = os.environ.copy()
        environment.update({
            'HOME': str(home),
            'TMPDIR': str(home),
            'XDG_DATA_HOME': str(home / 'data'),
            'XDG_CONFIG_HOME': str(home / 'config'),
            'XDG_STATE_HOME': str(home / 'state'),
            'XDG_RUNTIME_DIR': str(home / 'run'),
            'PATH': f'{fake_bin}:{environment.get("PATH", "")}',
            'TERM': 'dumb',
            'NO_COLOR': '1',
        })
        environment.pop('PUNCHI_RUNTIME_DIR', None)
        environment['PUNCHI_BUILD_DIR'] = str(build)
        (home / 'run').mkdir()

        result = subprocess.run(
            ['bash', str(checkout / 'scripts-user/setup.sh'), '--try', '--no-color'],
            cwd=checkout, env=environment, stdin=subprocess.DEVNULL,
            capture_output=True, text=True, check=False, timeout=60)
        combined = result.stdout + result.stderr
        assert result.returncode != 0, combined
        assert 'already running' in combined, combined
        assert (build / 'artifact.bin').exists(), \
            'The trial removed build output of a running copy'

        profile = checkout / 'profile'
        profile.mkdir()
        command = (
            f'punchi_project_root="{checkout}"; '
            f'source "{checkout}/scripts-user/lib/setup-common.sh"; '
            f'source "{checkout}/scripts-user/lib/setup-install.sh"; '
            f'punchi_trial_cleanup "{profile}"')
        result = subprocess.run(['bash', '-c', command], cwd=checkout,
                                env=environment, stdin=subprocess.DEVNULL,
                                capture_output=True, text=True, check=False,
                                timeout=30)
        combined = result.stdout + result.stderr
        assert result.returncode != 0, combined
        assert 'already running' in combined, combined
        assert profile.exists(), 'The cleanup removed a profile while a copy runs'
        assert (build / 'artifact.bin').exists(), combined


def check_uninstall_cleanup_modes(root: Path) -> None:
    """Uninstall keeps data by default and removes it all in clean mode."""
    def prepare(base: Path) -> dict:
        checkout = base / 'checkout'
        (checkout / 'scripts-user').mkdir(parents=True)
        shutil.copytree(root / 'scripts-user/lib', checkout / 'scripts-user/lib')
        (checkout / 'CMakeLists.txt').write_text(
            'project(punchi-clean VERSION 0.1.00)\n')
        (checkout / 'adapters/kde/native').mkdir(parents=True)
        (checkout / 'modules').mkdir()
        build = checkout / 'build'
        build.mkdir()
        (build / 'artifact.bin').write_text('x')

        install = base / 'install'
        (install / 'bin').mkdir(parents=True)
        (install / '.punchi-dock-quickshell-install').write_text('')
        (install / '.punchi-dock-quickshell-files').write_text('bin/tool\n')
        (install / 'bin/tool').write_text('')

        data = base / 'data'
        applications = data / 'applications'
        applications.mkdir(parents=True)
        launcher = applications / 'punchi-dock-quickshell.desktop'
        launcher.write_text(f'[Desktop Entry]\nX-Punchi-Install-Root={install}\n')
        registration = applications / 'org.punchi.Shell.WindowState.desktop'
        registration.write_text(
            '[Desktop Entry]\nType=Application\n'
            'Name=Punchi Dock Quickshell Window State\nNoDisplay=true\n'
            f'Exec="{install}/build/punchi-window-state"\n'
            'X-KDE-Wayland-Interfaces=org_kde_plasma_window_management\n')

        config = base / 'config'
        (config / 'autostart').mkdir(parents=True)
        (config / 'autostart/punchi-dock-quickshell.desktop').write_text(
            '[Desktop Entry]\nName=Punchi Dock Quickshell\n'
            'X-Punchi-Dock-Quickshell-Owned=true\n')
        preferences = config / 'punchi-dock-quickshell.json'
        preferences.write_text('{}')
        legacy = config / 'punchi-shell.json'
        legacy.write_text('{}')

        runtime = base / 'run'
        runtime.mkdir()
        instance = runtime / f'punchi-dock-quickshell-{os.getuid()}'
        instance.mkdir()
        (instance / 'instance.lock').write_text('')
        (instance / 'instance.path').write_text(f'{install}\n')

        fake_bin = base / 'bin'
        fake_bin.mkdir()
        sycoca = fake_bin / 'kbuildsycoca6'
        sycoca.write_text('#!/usr/bin/env bash\nexit 0\n')
        sycoca.chmod(0o755)

        environment = os.environ.copy()
        environment.update({
            'HOME': str(base),
            'XDG_DATA_HOME': str(data),
            'XDG_CONFIG_HOME': str(config),
            'XDG_STATE_HOME': str(base / 'state'),
            'XDG_RUNTIME_DIR': str(runtime),
            'PUNCHI_INSTALL_PREFIX': str(install),
            'PATH': f'{fake_bin}:{environment.get("PATH", "")}',
            'TERM': 'dumb',
            'NO_COLOR': '1',
        })
        environment['PUNCHI_BUILD_DIR'] = str(build)
        return {
            'checkout': checkout, 'build': build, 'install': install,
            'launcher': launcher, 'registration': registration,
            'preferences': preferences, 'legacy': legacy, 'instance': instance,
            'environment': environment,
        }

    def uninstall(paths: dict, mode: str) -> subprocess.CompletedProcess:
        command = (
            f'punchi_project_root="{paths["checkout"]}"; '
            f'source "{paths["checkout"]}/scripts-user/lib/setup-common.sh"; '
            f'source "{paths["checkout"]}/scripts-user/lib/setup-install.sh"; '
            f'PUNCHI_ASSUME_YES=1; punchi_uninstall_local {mode}')
        return subprocess.run(['bash', '-c', command], cwd=paths['checkout'],
                              env=paths['environment'], stdin=subprocess.DEVNULL,
                              capture_output=True, text=True, check=False,
                              timeout=30)

    with tempfile.TemporaryDirectory(prefix='punchi-uninstall-keep-') as temporary:
        paths = prepare(Path(temporary))
        result = uninstall(paths, '0 0 0')
        combined = result.stdout + result.stderr
        assert result.returncode == 0, combined
        assert not paths['install'].exists(), combined
        assert paths['preferences'].exists(), 'The keep mode deleted preferences'
        assert paths['legacy'].exists(), 'The keep mode deleted the legacy file'
        assert paths['build'].exists(), 'The keep mode deleted build output'
        assert not paths['registration'].exists(), \
            'Uninstall kept the window-state registration'
        assert not paths['instance'].exists(), 'Uninstall kept the runtime lock'

    with tempfile.TemporaryDirectory(prefix='punchi-uninstall-all-') as temporary:
        paths = prepare(Path(temporary))
        result = uninstall(paths, '1 1 1')
        combined = result.stdout + result.stderr
        assert result.returncode == 0, combined
        assert not paths['install'].exists(), combined
        assert not paths['preferences'].exists(), combined
        assert not paths['legacy'].exists(), combined
        assert not paths['build'].exists(), combined
        assert not paths['launcher'].exists(), combined
        assert not paths['registration'].exists(), combined
        assert not paths['instance'].exists(), combined
        assert (paths['checkout'] / 'scripts-user/lib').is_dir(), \
            'The clean mode removed the source checkout'


def run_in_terminal(command: str, environment: dict,
                    timeout: float = 20.0) -> tuple[str, float]:
    """Run a command with a pseudo-terminal and report elapsed seconds."""
    master, slave = pty.openpty()
    started = time.monotonic()
    process = subprocess.Popen(['bash', '-c', command],
                               stdin=subprocess.DEVNULL, stdout=slave,
                               stderr=slave, env=environment)
    os.close(slave)
    output = b''
    deadline = started + timeout
    while time.monotonic() < deadline:
        try:
            ready, _, _ = select.select([master], [], [], 0.2)
            if not ready:
                if process.poll() is not None:
                    break
                continue
            chunk = os.read(master, 65536)
            if not chunk:
                break
            output += chunk
        except OSError:
            break
    process.wait(timeout=timeout)
    os.close(master)
    return output.decode('utf-8', 'replace'), time.monotonic() - started


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

        replay = subprocess.run(
            [bash, '-c',
             f'source "{root}/scripts-user/lib/setup-progress.sh"; '
             'report() { printf "Runtime\\n[ok] qs\\n"; }; '
             f'punchi_run_report_step "{log_file}" report'],
            cwd=root, env=environment, capture_output=True, text=True,
            check=False, timeout=20)
        assert replay.returncode == 0, replay.stdout + replay.stderr
        replayed = replay.stdout.splitlines()
        assert replayed[-2:] == ['Runtime', '[ok] qs'], replay.stdout
        assert not any('Operation completed' in line for line in replayed), \
            'The report step must not add a completion frame'
        assert log_file.read_text() == 'Runtime\n[ok] qs\n', log_file.read_text()

        pacing = subprocess.run(
            [bash, '-c',
             f'source "{root}/scripts-user/lib/setup-progress.sh"; '
             'punchi_progress_seconds_to_ms 0.9; '
             'punchi_progress_seconds_to_ms 0.4; '
             'punchi_progress_seconds_to_ms 2; '
             'punchi_progress_seconds_to_ms bogus'],
            cwd=root, env=environment, capture_output=True, text=True,
            check=False, timeout=20)
        assert pacing.stdout.split() == ['900', '400', '2000', '0'], pacing.stdout

        terminal_environment = dict(environment)
        terminal_environment.update({
            'TERM': 'xterm-256color',
            'PUNCHI_PROGRESS_MIN_SECONDS': '0.6',
            'PUNCHI_PROGRESS_SETTLE_SECONDS': '0',
        })
        paced, paced_seconds = run_in_terminal(
            f'source "{root}/scripts-user/lib/setup-progress.sh"; '
            'step() { :; }; punchi_run_step /dev/null step',
            terminal_environment)
        assert '100%' in paced, paced
        assert paced_seconds >= 0.55, paced_seconds

        impatient = dict(environment)
        impatient.update({
            'PUNCHI_PROGRESS_MIN_SECONDS': '5',
            'PUNCHI_PROGRESS_SETTLE_SECONDS': '5',
        })
        started = time.monotonic()
        subprocess.run(
            [bash, '-c',
             f'source "{root}/scripts-user/lib/setup-progress.sh"; '
             'step() { :; }; punchi_run_step /dev/null step'],
            cwd=root, env=impatient, capture_output=True, text=True,
            check=False, timeout=20)
        assert time.monotonic() - started < 3, \
            'Redirected output must not wait for the visible minimum'

        quiet = subprocess.run(
            [bash, '-c',
             f'source "{root}/scripts-user/lib/setup-progress.sh"; '
             'step() { echo "raw output"; }; '
             f'PUNCHI_NO_PROGRESS=1 punchi_run_step "{log_file}" step'],
            cwd=root, env=environment, capture_output=True, text=True,
            check=False, timeout=20)
        assert quiet.returncode == 0, quiet.stdout + quiet.stderr
        assert quiet.stdout == 'raw output\n', quiet.stdout


SESSION_TOOLS = ('awk', 'bash', 'basename', 'cat', 'chmod', 'cut', 'date',
                 'dirname', 'env', 'flock', 'grep', 'head', 'ls', 'mkdir',
                 'mktemp', 'nproc', 'rm', 'sed', 'sh', 'sleep', 'sort', 'stat',
                 'tail', 'tr', 'uname', 'uniq', 'wc')


def session_environment(home: Path, *, desktop: Optional[str],
                        session_type: Optional[str], plasma: bool,
                        gui: bool = True, dialog: str = '0') -> dict:
    """Isolate a run that reports one desktop session on a clean PATH."""
    bin_dir = home / 'bin'
    bin_dir.mkdir(parents=True)
    for tool in SESSION_TOOLS:
        path = shutil.which(tool)
        if path:
            os.symlink(path, bin_dir / tool)
    (bin_dir / 'pgrep').write_text('#!/bin/sh\nexit 1\n')
    (bin_dir / 'pgrep').chmod(0o755)
    empty = home / 'no-sessions'
    empty.mkdir()
    sessions = empty
    if plasma:
        sessions = home / 'sessions'
        sessions.mkdir()
        (sessions / 'plasma.desktop').write_text(
            '[Desktop Entry]\nName=Plasma\nDesktopNames=KDE\n')
    (home / 'run').mkdir()
    environment = {
        'HOME': str(home),
        'PATH': str(bin_dir),
        'XDG_DATA_HOME': str(home / 'data'),
        'XDG_CONFIG_HOME': str(home / 'config'),
        'XDG_STATE_HOME': str(home / 'state'),
        'XDG_RUNTIME_DIR': str(home / 'run'),
        'TERM': 'dumb',
        'NO_COLOR': '1',
        'PUNCHI_WAYLAND_SESSIONS_DIR': str(sessions),
        'PUNCHI_XSESSIONS_DIR': str(empty),
        'PUNCHI_NOTICE_DIALOG': dialog,
    }
    if desktop is not None:
        environment['XDG_CURRENT_DESKTOP'] = desktop
    if session_type is not None:
        environment['XDG_SESSION_TYPE'] = session_type
    if gui:
        environment['WAYLAND_DISPLAY'] = 'wayland-1'
    return environment


def run_session_probe(root: Path, environment: dict) -> dict:
    script = ('source scripts-user/lib/session-detect.sh; '
              'printf "cause=%s\\n" "$(punchi_environment_cause)"; '
              'printf "label=%s\\n" "$(punchi_desktop_label)"; '
              'printf "message=%s\\n" "$(punchi_environment_message)"')
    result = subprocess.run(
        [shutil.which('bash') or 'bash', '-c', script], cwd=root,
        env=environment, capture_output=True, text=True, check=False, timeout=20)
    assert result.returncode == 0, result.stdout + result.stderr
    return dict(line.split('=', 1) for line in result.stdout.strip().splitlines())


def check_environment_messages(root: Path) -> None:
    """Every session reports the cause and the next step for its own case."""
    with tempfile.TemporaryDirectory(prefix='punchi-session-test-') as temporary:
        home = Path(temporary)
        wayland = run_session_probe(root, session_environment(
            home / 'kde', desktop='KDE', session_type='wayland', plasma=True))
        assert wayland['cause'] == 'supported', wayland

        x11 = run_session_probe(root, session_environment(
            home / 'kde-x11', desktop='KDE', session_type='x11', plasma=True))
        assert x11['cause'] == 'kde-not-wayland', x11
        assert 'You are using KDE Plasma on X11.' in x11['message']
        assert 'needs a Wayland session' in x11['message']

        available = run_session_probe(root, session_environment(
            home / 'gnome', desktop='GNOME', session_type='wayland', plasma=True))
        assert available['cause'] == 'plasma-available', available
        assert 'You are using GNOME on Wayland.' in available['message']
        assert 'not your current session' in available['message']

        missing = run_session_probe(root, session_environment(
            home / 'gnome-missing', desktop='GNOME', session_type='wayland',
            plasma=False))
        assert missing['cause'] == 'plasma-missing', missing
        assert 'KDE Plasma is not installed on this system.' in missing['message']

        ubuntu = run_session_probe(root, session_environment(
            home / 'ubuntu', desktop='ubuntu:GNOME', session_type='wayland',
            plasma=True))
        assert ubuntu['label'] == 'Ubuntu', ubuntu
        assert 'You are using Ubuntu on Wayland.' in ubuntu['message']

        cinnamon = run_session_probe(root, session_environment(
            home / 'cinnamon', desktop='X-Cinnamon', session_type='x11',
            plasma=True))
        assert cinnamon['label'] == 'Cinnamon', cinnamon

        odd = run_session_probe(root, session_environment(
            home / 'odd', desktop='bad\x01name', session_type='wayland',
            plasma=True))
        assert odd['label'] == 'badname', odd
        assert '\x01' not in odd['message'], odd

        glob = run_session_probe(root, session_environment(
            home / 'glob', desktop='*', session_type='wayland', plasma=True))
        assert glob['label'] == '*', glob
        assert 'AGENTS.md' not in glob['message'], \
            'The unquoted desktop value expanded as a pathname'

        headless = run_session_probe(root, session_environment(
            home / 'headless', desktop=None, session_type=None, plasma=True,
            gui=False))
        assert headless['cause'] == 'unknown-session', headless
        assert 'The current session could not be detected.' in headless['message']


def write_dialog_stub(bin_dir: Path, name: str, log: Path) -> None:
    (bin_dir / name).write_text(
        f'#!/bin/sh\nprintf "%s\\n" "$*" >> "{log}"\nexit 0\n')
    (bin_dir / name).chmod(0o755)


def run_in_pty(arguments: list, environment: dict, cwd: Path,
               input_text: str = '', timeout: float = 25.0) -> tuple[str, int]:
    """Run a command with a pseudo-terminal so interactive paths are reachable."""
    master, slave = pty.openpty()
    process = subprocess.Popen(arguments, cwd=cwd, env=environment,
                               stdin=slave, stdout=slave, stderr=slave)
    os.close(slave)
    if input_text:
        os.write(master, input_text.encode())
    output = b''
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            ready, _, _ = select.select([master], [], [], 0.2)
            if not ready:
                if process.poll() is not None:
                    break
                continue
            chunk = os.read(master, 65536)
            if not chunk:
                break
            output += chunk
        except OSError:
            break
    process.wait(timeout=timeout)
    os.close(master)
    return output.decode('utf-8', 'replace'), process.returncode


def check_start_environment_notice(root: Path, start: Path) -> None:
    """The startup guard names the session and uses the native dialog."""
    approved = (
        'KDE Plasma is required\n'
        'You are using GNOME on Wayland. KDE Plasma is not installed on this '
        'system. Install KDE Plasma first, then open the dock again.\n')
    with tempfile.TemporaryDirectory(prefix='punchi-notice-test-') as temporary:
        home = Path(temporary)
        environment = session_environment(
            home, desktop='GNOME', session_type='wayland', plasma=False,
            dialog='1')
        log = home / 'dialog.log'
        write_dialog_stub(home / 'bin', 'kdialog', log)

        result = subprocess.run(
            [str(start)], cwd=root, env=environment, capture_output=True,
            text=True, check=False, timeout=30)
        assert result.returncode == 3, result.stdout + result.stderr
        assert result.stderr == approved, result.stderr
        dialog = log.read_text()
        assert '--title Punchi Dock Quickshell' in dialog, dialog
        assert '--error' in dialog, dialog
        assert 'KDE Plasma is required' in dialog, dialog
        assert 'GNOME on Wayland' in dialog, dialog

        # Zenity is the GTK fallback.
        (home / 'bin/kdialog').unlink()
        log.unlink()
        write_dialog_stub(home / 'bin', 'zenity', log)
        result = subprocess.run(
            [str(start)], cwd=root, env=environment, capture_output=True,
            text=True, check=False, timeout=30)
        assert result.returncode == 3, result.stderr
        dialog = log.read_text()
        assert '--error' in dialog and '--no-markup' in dialog, dialog

        # No dialog tool leaves the same text on stderr.
        (home / 'bin/zenity').unlink()
        log.unlink()
        result = subprocess.run(
            [str(start)], cwd=root, env=environment, capture_output=True,
            text=True, check=False, timeout=30)
        assert result.returncode == 3, result.stderr
        assert result.stderr == approved, result.stderr
        assert not log.exists(), 'A dialog was started without any tool'

        # PUNCHI_NOTICE_DIALOG=0 keeps the terminal path only.
        write_dialog_stub(home / 'bin', 'kdialog', log)
        disabled = dict(environment, PUNCHI_NOTICE_DIALOG='0')
        result = subprocess.run(
            [str(start)], cwd=root, env=disabled, capture_output=True,
            text=True, check=False, timeout=30)
        assert result.returncode == 3, result.stderr
        assert result.stderr == approved, result.stderr
        assert not log.exists(), 'PUNCHI_NOTICE_DIALOG=0 still opened a dialog'

        # A terminal launch reads the text and gets no dialog.
        interactive = dict(environment, PUNCHI_NOTICE_DIALOG='auto')
        output, status = run_in_pty([str(start)], interactive, root)
        assert status == 3, output
        assert 'KDE Plasma is required' in output, output
        assert not log.exists(), 'A terminal launch opened a dialog'

        # The launcher does not repeat the failure notice after the dialog.
        launcher_root = home / 'launcher-root'
        (launcher_root / 'scripts-user').mkdir(parents=True)
        (launcher_root / 'assets/icons').mkdir(parents=True)
        (launcher_root / 'assets/icons/punchi-dock-quickshell.svg').write_text(
            '<svg xmlns="http://www.w3.org/2000/svg"/>\n')
        shutil.copy2(root / 'scripts-user/launcher.sh',
                     launcher_root / 'scripts-user/launcher.sh')
        shutil.copytree(root / 'scripts-user/lib', launcher_root / 'scripts-user/lib')
        notify_log = home / 'notify.log'
        write_dialog_stub(home / 'bin', 'notify-send', notify_log)
        fake_start = launcher_root / 'scripts-user/start.sh'
        fake_start.write_text('#!/bin/sh\necho "environment notice"\nexit 3\n')
        fake_start.chmod(0o755)
        result = subprocess.run(
            ['bash', str(launcher_root / 'scripts-user/launcher.sh'), 'start'],
            cwd=launcher_root, env=environment, capture_output=True, text=True,
            check=False, timeout=30)
        assert result.returncode == 3, result.stdout + result.stderr
        assert not notify_log.exists(), \
            'The launcher repeated the notice after the environment dialog'

        # Without any dialog tool the notice never reached the user, so the
        # launcher must fall back to its notification.
        (home / 'bin/kdialog').unlink()
        result = subprocess.run(
            ['bash', str(launcher_root / 'scripts-user/launcher.sh'), 'start'],
            cwd=launcher_root, env=environment, capture_output=True, text=True,
            check=False, timeout=30)
        assert result.returncode == 3, result.stdout + result.stderr
        assert notify_log.exists(), \
            'A suppressed environment dialog left the launcher silent'
        assert 'could not start' in notify_log.read_text(), notify_log.read_text()
        notify_log.unlink()

        fake_start.write_text('#!/bin/sh\necho "boom"\nexit 1\n')
        fake_start.chmod(0o755)
        result = subprocess.run(
            ['bash', str(launcher_root / 'scripts-user/launcher.sh'), 'start'],
            cwd=launcher_root, env=environment, capture_output=True, text=True,
            check=False, timeout=30)
        assert result.returncode == 1, result.stdout + result.stderr
        assert notify_log.exists(), 'A generic failure lost its notification'


def check_install_environment_guard(root: Path, setup: Path) -> None:
    """Install and trial refuse an unsupported session before writing."""
    guard = ('source scripts-user/lib/setup-common.sh; '
             'source scripts-user/lib/setup-environment.sh; '
             'punchi_require_kde_environment install; '
             'echo "GUARD_STATUS=$?"')
    with tempfile.TemporaryDirectory(prefix='punchi-guard-test-') as temporary:
        home = Path(temporary)
        environment = session_environment(
            home, desktop='GNOME', session_type='wayland', plasma=False)
        install_root = home / 'data/punchi-dock-quickshell'

        result = subprocess.run(
            [str(setup), '--install', '--yes', '--no-color'], cwd=root,
            env=environment, capture_output=True, text=True, check=False,
            timeout=60)
        combined = result.stdout + result.stderr
        assert result.returncode != 0, combined
        assert 'Punchi Dock Quickshell requires KDE Plasma on Wayland.' in combined
        assert 'You are using GNOME on Wayland.' in combined
        assert 'KDE Plasma is not installed on this system.' in combined
        assert 'Install KDE Plasma first, then open the dock again.' in combined
        assert 'Nothing was installed.' in combined
        assert not install_root.exists(), \
            'A refused install wrote the install prefix'

        installed = session_environment(
            home / 'plasma-host', desktop='GNOME', session_type='wayland',
            plasma=True)
        result = subprocess.run(
            [str(setup), '--install', '--yes', '--no-color'], cwd=root,
            env=installed, capture_output=True, text=True, check=False,
            timeout=60)
        combined = result.stdout + result.stderr
        assert result.returncode != 0, combined
        assert 'not your current session' in combined, combined

        result = subprocess.run(
            [str(setup), '--try', '--yes', '--no-color'], cwd=root,
            env=environment, capture_output=True, text=True, check=False,
            timeout=60)
        combined = result.stdout + result.stderr
        assert result.returncode != 0, combined
        assert 'requires KDE Plasma on Wayland' in combined, combined

        override = dict(environment, PUNCHI_ALLOW_NON_KDE='1')
        result = subprocess.run(
            [shutil.which('bash') or 'bash', '-c', guard], cwd=root,
            env=override, capture_output=True, text=True, check=False,
            timeout=20)
        assert 'GUARD_STATUS=0' in result.stdout, result.stdout + result.stderr
        assert 'requires KDE Plasma' not in result.stdout, result.stdout

        headless = session_environment(
            home / 'headless', desktop=None, session_type=None, plasma=True,
            gui=False)
        result = subprocess.run(
            [shutil.which('bash') or 'bash', '-c', guard], cwd=root,
            env=headless, capture_output=True, text=True, check=False,
            timeout=20)
        assert 'GUARD_STATUS=0' in result.stdout, result.stdout + result.stderr
        assert 'No graphical session was detected.' in result.stdout, result.stdout

        result = subprocess.run(
            [str(setup), '--uninstall', '--yes', '--no-color'], cwd=root,
            env=environment, capture_output=True, text=True, check=False,
            timeout=60)
        combined = result.stdout + result.stderr
        assert 'requires KDE Plasma on Wayland' not in combined, \
            'Uninstall was blocked by the environment guard'

        output, status = run_in_pty(
            [str(setup), '--install', '--no-color'], environment, root,
            input_text='n\n')
        assert status != 0, output
        assert 'Continue anyway? [y/N]' in output, output
        assert 'Nothing was installed.' in output, output
        assert not install_root.exists(), 'A cancelled install wrote the prefix'

        output, status = run_in_pty(
            [shutil.which('bash') or 'bash', '-c', guard], environment, root,
            input_text='y\n')
        assert status == 0, output
        assert 'GUARD_STATUS=0' in output, output


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
    check_build_tree_layout(root)
    check_debian_backports_offer(root)
    check_install_failure_clock_hint(root)
    check_dependency_report_layout(root)
    check_qt_tool_resolution(root)
    check_try_requires_checkout(root)
    check_try_flow(root)
    check_trial_prompt(root)
    check_dock_stop_status(root)
    check_trial_cleanup(root)
    check_trial_refuses_running_copy(root)
    check_uninstall_cleanup_modes(root)
    check_presentation(root)
    check_failure_log(root)
    check_build_failure_log(root)
    check_environment_messages(root)
    check_start_environment_notice(root, start)
    check_install_environment_guard(root, setup)
    check_update_check(root)
    check_git_missing(root)
    check_autostart_uninstall(root)
    print('User setup scripts: syntax, help, menu, maps, build trees, Qt tools, '
          'logs, environment notices, restore, instance guard, try path, '
          'presentation and update check passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
