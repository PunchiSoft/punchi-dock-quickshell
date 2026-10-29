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
    exec runuser -u punchi -- env HOME=/home/punchi PUNCHI_SKIP_PACKAGES=1 \
        bash "$workspace/scripts-dev/ci-headless.sh"
fi

cd "$repo_root"
cmake --preset dev
cmake --build --preset dev
ruff check tests scripts-dev
ctest --preset headless
