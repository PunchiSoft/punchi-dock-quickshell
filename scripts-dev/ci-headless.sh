#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Headless validation graph, shared by GitHub Actions and local podman runs.
#
# Package lists come from the user setup assistant so CI and the documented
# installation cannot drift apart. `quickshell` and `dbus-run-session` stay
# required because CMakeLists.txt looks for both at configure time, even though
# the `session` tests are not selected here.
#
# Local run, without leaving root-owned files in the checkout:
#   podman run --rm -v "$PWD:/src:ro" fedora:44 \
#       bash -c 'mkdir /work && tar -C /src -cf - . | tar -xf - -C /work &&
#                 bash /work/scripts-dev/ci-headless.sh'
#
# Set PUNCHI_SKIP_PACKAGES=1 to reuse an image that already has the packages.
# PUNCHI_JUNIT names a repository-relative JUnit report, PUNCHI_CTEST_REGEX and
# PUNCHI_CTEST_REPEAT select and repeat tests, and tests/flaky-tests.json keeps
# quarantined tests out of the blocking run.

set -euo pipefail

script_dir="${BASH_SOURCE[0]%/*}"
if [[ "$script_dir" == "${BASH_SOURCE[0]}" ]]; then
    script_dir='.'
fi
repo_root="$(cd "$script_dir/.." && pwd)"

if [[ "${EUID}" -eq 0 ]]; then
    if [[ "${PUNCHI_SKIP_PACKAGES:-0}" != "1" ]]; then
        # shellcheck source=../scripts-user/lib/setup-deps.sh
        source "$repo_root/scripts-user/lib/setup-deps.sh"
        packages=()
        while IFS= read -r package; do
            packages+=("$package")
        done < <(
            {
                punchi_fedora_runtime_packages
                punchi_fedora_build_packages
                punchi_fedora_validation_packages
                # git and the KDE platform theme are not runtime dependencies of
                # the dock; breeze and qtsvg back the theme and icon checks, and
                # ruff checks the tooling scripts.
                printf '%s\n' git plasma-integration breeze-icon-theme qt6-qtsvg ruff
            } | sort -u
        )
        dnf install -y "${packages[@]}"
    fi

    # update_state waits for PackageKit's reply. Without a system bus the pending
    # call never settles; with an empty bus each source reports ServiceUnknown,
    # which is the fallback the test asserts.
    mkdir -p /run/dbus
    if [[ ! -S /run/dbus/system_bus_socket ]]; then
        dbus-daemon --system --fork --nopidfile
    fi

    # The setup scripts refuse to run as root, and running_state asserts the
    # checkout directory name. The tests therefore run as a desktop-like user
    # from a directory named like the repository, copied inside the container so
    # the mounted checkout keeps its ownership.
    if ! id -u punchi >/dev/null 2>&1; then
        useradd --create-home --shell /bin/bash punchi
    fi
    workspace=/home/punchi/punchi-dock-quickshell
    rm -rf "$workspace"
    mkdir -p "$workspace"
    tar -C "$repo_root" --exclude=./build --exclude='./build-*' --exclude=./.git \
        --exclude=./docs --exclude=./scratch -cf - . | tar -xf - -C "$workspace"
    chown -R punchi: "$workspace"
    status=0
    runuser -u punchi -- env HOME=/home/punchi PUNCHI_SKIP_PACKAGES=1 \
        bash "$workspace/scripts-dev/ci-headless.sh" || status=$?
    # The tests wrote their report inside the copy, and the mounted checkout is
    # where the workflow collects it, so it comes back here.
    if [[ -n "${PUNCHI_JUNIT:-}" && -f "$workspace/$PUNCHI_JUNIT" ]]; then
        mkdir -p "$repo_root/${PUNCHI_JUNIT%/*}"
        cp "$workspace/$PUNCHI_JUNIT" "$repo_root/$PUNCHI_JUNIT"
    fi
    exit "$status"
fi

cd "$repo_root"
cmake --preset dev
cmake --build --preset dev
ruff check tests scripts-dev

# Quarantined tests are excluded from the blocking run and re-run on their own, so
# a known flake reports itself without hiding a regression.
quarantined="$(python3 - <<'PYTHON'
import json
from pathlib import Path
entries = json.loads(Path('tests/flaky-tests.json').read_text())['quarantined']
print('|'.join(entry['test'] for entry in entries))
PYTHON
)"

ctest_args=(--test-dir build/dev --output-on-failure)
if [[ -n "${PUNCHI_JUNIT:-}" ]]; then
    # CTest resolves a relative report path inside the build directory, so the
    # repository-relative name is made absolute here.
    junit_report="$repo_root/$PUNCHI_JUNIT"
    mkdir -p "${junit_report%/*}"
    ctest_args+=("--output-junit" "$junit_report")
fi
if [[ -n "${PUNCHI_CTEST_REGEX:-}" ]]; then
    ctest_args+=(-R "$PUNCHI_CTEST_REGEX")
else
    ctest_args+=(-L 'unit|qml')
    if [[ -n "$quarantined" ]]; then
        ctest_args+=(-E "$quarantined")
    fi
fi
if [[ -n "${PUNCHI_CTEST_REPEAT:-}" ]]; then
    ctest_args+=("--repeat" "$PUNCHI_CTEST_REPEAT")
fi
ctest "${ctest_args[@]}"

if [[ -n "$quarantined" ]]; then
    echo "Quarantined tests (non-blocking): $quarantined"
    ctest --test-dir build/dev --output-on-failure -R "$quarantined" \
        --repeat until-pass:2 || echo "::warning::a quarantined test failed; see tests/flaky-tests.json"
fi
