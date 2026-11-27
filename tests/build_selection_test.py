#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Prove the isolated runner uses the requested build tree, not another one."""

from pathlib import Path
import os
import subprocess
import sys
import tempfile


PROJECT = Path(__file__).resolve().parents[1]
RUNNER = PROJECT / 'scripts-dev' / 'run-isolated.py'
PROBE = (
    'import os\n'
    'print(os.environ["PUNCHI_BUILD_DIR"])\n'
    'print(os.environ["QML_IMPORT_PATH"].split(os.pathsep)[0])\n'
)


def make_tree(directory: Path) -> None:
    (directory / 'qml/Punchi/Kde').mkdir(parents=True)
    (directory / 'qml/Punchi/Kde/libpunchikdeplugin.so').write_text('')
    (directory / 'qml/Punchi/Kde/libpunchikde.so').write_text('')
    (directory / 'libpunchikde.so').write_text('')
    backend = directory / 'punchi-window-state'
    backend.write_text('#!/usr/bin/env bash\nexit 0\n')
    backend.chmod(0o755)


def selected(environment: dict, *arguments: str) -> tuple[Path, Path]:
    result = subprocess.run(
        [sys.executable, str(RUNNER), *arguments, '--',
         sys.executable, '-c', PROBE],
        cwd=PROJECT, env=environment, capture_output=True, text=True,
        check=False, timeout=30,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    lines = result.stdout.splitlines()
    assert len(lines) == 2, result.stdout
    return Path(lines[0]), Path(lines[1])


def main() -> int:
    with tempfile.TemporaryDirectory(prefix='punchi-build-selection-') as temporary:
        base = Path(temporary)
        first = base / 'build' / 'build-debian'
        second = base / 'build' / 'build-fedora'
        make_tree(first)
        make_tree(second)
        data_home = base / 'data'
        data_home.mkdir()
        environment = os.environ.copy()
        environment.pop('PUNCHI_BUILD_DIR', None)
        environment['XDG_DATA_HOME'] = str(data_home)

        build_dir, qml_path = selected(environment, '--build-dir', str(second))
        assert build_dir == second, build_dir
        assert qml_path == second / 'qml', qml_path

        build_dir, qml_path = selected(environment, '--build-dir', str(first))
        assert build_dir == first, build_dir
        assert qml_path == first / 'qml', qml_path

        # The explicit argument wins over a caller-provided override.
        conflicting = environment.copy()
        conflicting['PUNCHI_BUILD_DIR'] = str(first)
        build_dir, qml_path = selected(conflicting, '--build-dir', str(second))
        assert build_dir == second, build_dir
        assert qml_path == second / 'qml', qml_path

        # Manual and distribution CTest runs can still name their own tree.
        override = environment.copy()
        override['PUNCHI_BUILD_DIR'] = str(first)
        build_dir, qml_path = selected(override)
        assert build_dir == first, build_dir
        assert qml_path == first / 'qml', qml_path

    registrations = [
        line for line in (PROJECT / 'CMakeLists.txt').read_text().splitlines()
        if 'scripts-dev/run-isolated.py' in line
    ]
    assert registrations, 'No isolated runner registrations found'
    for line in registrations:
        assert '--build-dir ${CMAKE_BINARY_DIR}' in line, line

    print('Build selection: explicit CTest tree and configured override both resolve '
          'the intended artifacts, and every isolated registration names its build.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
