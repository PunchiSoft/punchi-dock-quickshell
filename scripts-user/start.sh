#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if (($# > 1)); then
    printf '%s\n' 'Usage: start.sh [overlay|reserve|desktop|autohide]' >&2
    exit 2
fi
panel_mode="${1:-${PUNCHI_DOCK_MODE:-}}"
case "$panel_mode" in
    ""|overlay|reserve|desktop|autohide) ;;
    *) printf '%s\n' 'Invalid panel mode.' >&2; exit 2 ;;
esac
if ! command -v qs >/dev/null 2>&1; then
    printf '%s\n' 'Quickshell is required. Install it before starting Punchi Shell.' >&2
    exit 1
fi
instances="$(qs list --path "$project_root" --json)"
if [[ "$instances" != '[]' && "$instances" != 'No running instances for '* ]]; then
    if (($# > 0)); then
        qs ipc --path "$project_root" call dock setMode "$panel_mode" >/dev/null
    fi
    exec qs ipc --path "$project_root" call dock revealDock
fi
export PUNCHI_DOCK_MODE="$panel_mode"
if [[ ! -f "$project_root/build/qml/Punchi/Kde/libpunchikdeplugin.so" ]]; then
    printf '%s\n' 'Build the KDE launcher first: cmake -S . -B build && cmake --build build' >&2
    exit 1
fi
export QML_IMPORT_PATH="$project_root/build/qml${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
if [[ ! -x "$project_root/build/punchi-window-state" ]]; then
    printf '%s\n' 'Build the KDE window backend first: cmake -S . -B build && cmake --build build' >&2
    exit 1
fi
"$project_root/build/punchi-window-state" --register
export PUNCHI_WINDOW_BACKEND="$project_root/build/punchi-window-state"
exec qs --path "$project_root" --no-duplicate
