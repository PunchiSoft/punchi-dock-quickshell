#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# One build tree per distribution, so testing several systems keeps its objects,
# caches and generated QML metadata apart and a stale cache can never be reused
# by the wrong one.
#
# Shared by the setup assistant, the start script and the restore script, which
# run without loading the rest of the setup libraries.

punchi_build_root() {
    local root="${punchi_project_root:-${project_root:-}}"
    if [[ -z "$root" ]]; then
        root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
    fi
    printf '%s\n' "$root"
}

# Lowercased distribution ID, or an empty string when it cannot be read.
punchi_build_distro_id() {
    local file="${PUNCHI_OS_RELEASE_FILE:-/etc/os-release}"
    local name=""
    local value=""
    [[ -r "$file" ]] || return 1
    while IFS='=' read -r name value; do
        [[ "$name" == "ID" ]] || continue
        value="${value%$'\r'}"
        value="${value#\"}"
        value="${value%\"}"
        value="${value#\'}"
        value="${value%\'}"
        [[ -n "$value" ]] || return 1
        printf '%s\n' "${value,,}"
        return 0
    done < "$file"
    return 1
}

# The tree a build writes to. PUNCHI_BUILD_DIR is an explicit override; the
# setup assistant validates it before it is used and removed.
punchi_build_dir() {
    local root=""
    local distro=""
    root="$(punchi_build_root)"
    if [[ -n "${PUNCHI_BUILD_DIR:-}" ]]; then
        printf '%s\n' "$PUNCHI_BUILD_DIR"
        return 0
    fi
    if distro="$(punchi_build_distro_id)"; then
        printf '%s/build-%s\n' "$root" "$distro"
        return 0
    fi
    printf '%s/build\n' "$root"
}

punchi_build_artifacts_ready() {
    local dir="${1:-}"
    [[ -n "$dir" ]] || dir="$(punchi_build_dir)"
    [[ -f "$dir/qml/Punchi/Kde/libpunchikdeplugin.so" \
        && -f "$dir/libpunchikde.so" \
        && -x "$dir/punchi-window-state" ]]
}

# A complete tree to run or install from: the distribution tree first, then the
# plain build/ written before the per-distribution layout existed.
punchi_build_dir_existing() {
    local dir=""
    dir="$(punchi_build_dir)" || return 1
    if punchi_build_artifacts_ready "$dir"; then
        printf '%s\n' "$dir"
        return 0
    fi
    dir="$(punchi_build_root)/build"
    if punchi_build_artifacts_ready "$dir"; then
        printf '%s\n' "$dir"
        return 0
    fi
    return 1
}
