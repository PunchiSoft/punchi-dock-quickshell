#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Prove a build cache only authorizes removal when it names this checkout."""

from pathlib import Path
import shlex
import subprocess
import tempfile


PROJECT = Path(__file__).resolve().parents[1]
BUILD_DIR_LIBRARY = PROJECT / 'scripts-user' / 'lib' / 'build-dir.sh'


def ownership(root: Path, directory: Path) -> int:
    script = (
        f'source {shlex.quote(str(BUILD_DIR_LIBRARY))} || exit 2\n'
        f'punchi_project_root={shlex.quote(str(root))}\n'
        f'punchi_build_cache_owned_by_project {shlex.quote(str(directory))}\n'
    )
    result = subprocess.run(['bash', '-c', script], check=False,
                            capture_output=True, text=True, timeout=10)
    assert result.returncode in (0, 1), result.stderr
    return result.returncode


def write_cache(directory: Path, source: str) -> None:
    (directory / 'CMakeCache.txt').write_text(
        '# This is the CMakeCache file.\n'
        f'CMAKE_HOME_DIRECTORY:INTERNAL={source}\n'
        'CMAKE_CACHEFILE_DIR:INTERNAL=/tmp/ignored\n',
        encoding='utf-8',
    )


def main() -> int:
    assert BUILD_DIR_LIBRARY.is_file(), BUILD_DIR_LIBRARY
    with tempfile.TemporaryDirectory(prefix='punchi-build-owner-') as temporary:
        base = Path(temporary)
        checkout = base / 'checkout with space'
        checkout.mkdir()
        owned = base / 'owned'
        owned.mkdir()
        write_cache(owned, str(checkout))
        assert ownership(checkout, owned) == 0, 'the project cache was not owned'

        foreign = base / 'foreign'
        foreign.mkdir()
        write_cache(foreign, str(base / 'another-project'))
        assert ownership(checkout, foreign) == 1, 'a foreign cache was accepted'

        missing = base / 'missing'
        missing.mkdir()
        assert ownership(checkout, missing) == 1, 'a tree without a cache was accepted'

        unrecorded = base / 'unrecorded'
        unrecorded.mkdir()
        (unrecorded / 'CMakeCache.txt').write_text('CMAKE_CACHEFILE_DIR:INTERNAL=/tmp\n')
        assert ownership(checkout, unrecorded) == 1, 'a cache without a source was accepted'

        symlinked = base / 'symlinked'
        symlinked.mkdir()
        (symlinked / 'CMakeCache.txt').symlink_to(owned / 'CMakeCache.txt')
        assert ownership(checkout, symlinked) == 1, 'a symlinked cache was accepted'

        assert ownership(checkout, base / 'does-not-exist') == 1, 'a missing tree was accepted'

        script = (
            f'source {shlex.quote(str(BUILD_DIR_LIBRARY))} || exit 2\n'
            f'punchi_project_root={shlex.quote(str(checkout))}\n'
            'punchi_build_cache_owned_by_project ""\n'
        )
        result = subprocess.run(['bash', '-c', script], check=False,
                                capture_output=True, text=True, timeout=10)
        assert result.returncode == 1, 'an empty path was accepted'

    print('Build cache ownership: project, foreign, missing, unrecorded, '
          'symlinked and empty inputs behave as specified.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
