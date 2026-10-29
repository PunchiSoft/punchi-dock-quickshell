#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# One build tree per distribution, grouped under a single `build/` directory, so
# testing several systems keeps its objects, caches and generated QML metadata
# apart, keeps the checkout ordered, and a stale cache can never be reused by the
# wrong one.
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

# The tree a build writes to: `build/build-<distribution ID>` inside the shared
# `build/` directory. PUNCHI_BUILD_DIR is an explicit override; the setup
# assistant validates it before it is used and removed.
punchi_build_dir() {
    local root=""
    local distro=""
    root="$(punchi_build_root)"
    if [[ -n "${PUNCHI_BUILD_DIR:-}" ]]; then
        printf '%s\n' "$PUNCHI_BUILD_DIR"
        return 0
    fi
    if distro="$(punchi_build_distro_id)"; then
        printf '%s/build/build-%s\n' "$root" "$distro"
        return 0
    fi
    printf '%s/build/build\n' "$root"
}

punchi_build_artifacts_ready() {
    local dir="${1:-}"
    [[ -n "$dir" ]] || dir="$(punchi_build_dir)"
    [[ -f "$dir/qml/Punchi/Kde/libpunchikdeplugin.so" \
        && -f "$dir/libpunchikde.so" \
        && -x "$dir/punchi-window-state" ]]
}

# Every complete tree a run or an install may use, most specific first: the
# distribution tree, the generic `build/dev` tree written by `cmake --preset dev`,
# and the flat trees written before the trees were grouped under `build/`.
punchi_build_dir_candidates() {
    local root=""
    local distro=""
    root="$(punchi_build_root)"
    punchi_build_dir
    printf '%s\n' "$root/build/dev"
    if distro="$(punchi_build_distro_id)"; then
        printf '%s\n' "$root/build-$distro"
    fi
    printf '%s\n' "$root/build"
}

# A complete tree to run or install from. A `build/` directory that only holds the
# per-distribution trees carries no artifacts of its own and is skipped here.
punchi_build_dir_existing() {
    local dir=""
    while IFS= read -r dir; do
        if punchi_build_artifacts_ready "$dir"; then
            printf '%s\n' "$dir"
            return 0
        fi
    done < <(punchi_build_dir_candidates)
    return 1
}
