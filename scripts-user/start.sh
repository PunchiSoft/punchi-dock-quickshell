#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
for punchi_library in session-detect notice-dialog; do
    if [[ ! -r "$project_root/scripts-user/lib/$punchi_library.sh" ]]; then
        printf 'Punchi Dock Quickshell is incomplete: scripts-user/lib/%s.sh is missing. Reinstall it.\n' \
            "$punchi_library" >&2
        exit 1
    fi
done
unset punchi_library
# shellcheck source=lib/session-detect.sh
source "$project_root/scripts-user/lib/session-detect.sh"
# shellcheck source=lib/notice-dialog.sh
source "$project_root/scripts-user/lib/notice-dialog.sh"
usage() {
    printf '%s\n' 'Usage: start.sh [reserve|autohide|dodge-windows|overlay]'
    printf '%s\n' 'Starts Punchi Dock Quickshell in the foreground. Plasma stays running.'
    printf '%s\n' 'Run scripts-user/setup.sh for the guided install/update menu.'
}
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi
if (($# > 1)); then
    usage >&2
    exit 2
fi
panel_mode="${1:-${PUNCHI_DOCK_MODE:-}}"
case "$panel_mode" in
    desktop) panel_mode="dodge-windows" ;; # Legacy below-windows setting.
    ""|overlay|reserve|autohide|dodge-windows) ;;
    *) printf '%s\n' 'Invalid panel mode.' >&2; exit 2 ;;
esac
# The session decides whether this dock can run at all, so it is checked
# before the runtime dependencies.
if [[ "${PUNCHI_ALLOW_NON_KDE:-0}" != "1" ]] && ! punchi_environment_supported; then
    notice_text="$(punchi_environment_notice_text)"
    printf '%s\n' "$notice_text" >&2
    punchi_show_notice "Punchi Dock Quickshell" "$notice_text" || true
    exit 3
fi

if ! command -v qs >/dev/null 2>&1; then
    printf '%s\n' 'Quickshell is required. Install it before starting Punchi Dock Quickshell.' >&2
    exit 1
fi

punchi_running() {
    local path="${1:?path is required}"
    local output=""
    if ! output="$(qs list --path "$path" --json 2>/dev/null)"; then
        return 1
    fi
    [[ -n "$output" ]] || return 1
    if [[ "$output" == '[]' || "$output" == 'No running instances for '* ]]; then
        return 1
    fi
    return 0
}

existing_registration_root() {
    local registration="${XDG_DATA_HOME:-$HOME/.local/share}/applications/org.punchi.Shell.WindowState.desktop"
    local executable=""
    local root=""
    if [[ ! -f "$registration" || -L "$registration" ]]; then
        return 1
    fi
    executable="$(sed -n 's/^Exec="\(.*\)"$/\1/p' "$registration" | head -n 1)"
    [[ -n "$executable" ]] || return 1
    case "$executable" in
        */build/punchi-window-state)
            root="${executable%/build/punchi-window-state}"
            ;;
        *)
            return 1
            ;;
    esac
    [[ -n "$root" && "$root" != "$project_root" ]] || return 1
    punchi_running "$root" || return 1
    printf '%s\n' "$root"
}

acquire_instance_lock() {
    local runtime_root="${PUNCHI_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-}}"
    local lock_dir=""
    local lock_file=""
    local instance_file=""
    local running_path=""

    if [[ -z "$runtime_root" || ! -d "$runtime_root" ]]; then
        runtime_root="${TMPDIR:-/tmp}"
    fi
    lock_dir="$runtime_root/punchi-dock-quickshell-$UID"
    if [[ ! -d "$lock_dir" ]]; then
        mkdir -m 700 -- "$lock_dir" 2>/dev/null || true
    fi
    if [[ ! -d "$lock_dir" || -L "$lock_dir" || ! -O "$lock_dir" ]]; then
        printf '%s\n' 'Warning: the runtime lock directory is unavailable; duplicate detection is limited.' >&2
        return 0
    fi
    if ! command -v flock >/dev/null 2>&1; then
        printf '%s\n' 'Warning: flock is unavailable; duplicate detection is limited.' >&2
        return 0
    fi

    lock_file="$lock_dir/instance.lock"
    instance_file="$lock_dir/instance.path"
    exec 9>"$lock_file"
    if ! flock -n 9; then
        running_path=""
        if [[ -r "$instance_file" ]]; then
            IFS= read -r running_path < "$instance_file" || true
        fi
        if [[ -n "$running_path" ]]; then
            printf 'Punchi Dock Quickshell is already running from:\n  %s\n' "$running_path" >&2
            printf 'Stop it first:\n  %s/scripts-user/restore-kde.sh\n' "$running_path" >&2
        else
            printf '%s\n' 'Punchi Dock Quickshell is already starting.' >&2
        fi
        exit 1
    fi
    printf '%s\n' "$project_root" > "$instance_file" 2>/dev/null || true
}

if punchi_running "$project_root"; then
    if (($# > 0)); then
        qs ipc --path "$project_root" call dock setMode "$panel_mode" >/dev/null
    fi
    exec qs ipc --path "$project_root" call dock revealDock
fi

acquire_instance_lock

if existing_root="$(existing_registration_root)"; then
    printf 'Punchi Dock Quickshell is already running from:\n  %s\n' "$existing_root" >&2
    printf 'Stop it first:\n  %s/scripts-user/restore-kde.sh\n' "$existing_root" >&2
    exit 1
fi

export PUNCHI_DOCK_MODE="$panel_mode"
qml_root="$project_root/build/qml"
if [[ ! -f "$qml_root/Punchi/Kde/libpunchikdeplugin.so" ]]; then
    qml_root="$project_root/qml"
fi
if [[ ! -f "$qml_root/Punchi/Kde/libpunchikdeplugin.so" ]]; then
    printf '%s\n' 'Build the KDE launcher first: cmake -S . -B build && cmake --build build' >&2
    exit 1
fi
# The plugin loads this library from a relative path; a build that was only
# partially replaced would otherwise fail later with a missing QML type.
if [[ ! -f "$qml_root/Punchi/Kde/libpunchikde.so" \
    && ! -f "$project_root/build/libpunchikde.so" ]]; then
    printf '%s\n' 'The native QML library is missing. Rebuild and reinstall: cmake --build build' >&2
    exit 1
fi
backend="$project_root/build/punchi-window-state"
if [[ ! -x "$backend" ]]; then
    backend="$project_root/../../libexec/punchi-dock-quickshell/punchi-window-state"
fi
if [[ ! -x "$backend" ]]; then
    backend="$project_root/../../lib/punchi-dock-quickshell/punchi-window-state"
fi
if [[ ! -x "$backend" ]]; then
    printf '%s\n' 'Build the KDE window backend first: cmake -S . -B build && cmake --build build' >&2
    exit 1
fi
export QML_IMPORT_PATH="$qml_root${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
"$backend" --register
export PUNCHI_WINDOW_BACKEND="$backend"
exec qs --path "$project_root" --no-duplicate
