#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -r "$project_root/scripts-user/lib/build-dir.sh" ]]; then
    # shellcheck source=lib/build-dir.sh
    source "$project_root/scripts-user/lib/build-dir.sh"
fi

punchi_instance_path() {
    local runtime_root="${PUNCHI_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-}}"
    if [[ -z "$runtime_root" || ! -d "$runtime_root" ]]; then
        runtime_root="${TMPDIR:-/tmp}"
    fi
    printf '%s/punchi-dock-quickshell-%s/instance.path\n' "$runtime_root" "$UID"
}

punchi_owned_root() {
    local path="${1:-}"
    [[ -n "$path" && "$path" == /* && -d "$path" && ! -L "$path" ]] || return 1
    [[ -f "$path/shell.qml" ]] || return 1
    grep -q 'modules/dock' "$path/shell.qml" 2>/dev/null || return 1
    [[ -f "$path/scripts-user/restore-kde.sh" \
        || -f "$path/.punchi-dock-quickshell-install" ]] || return 1
    printf '%s\n' "$path"
}

punchi_active_root() {
    local instance_file=""
    local path=""
    instance_file="$(punchi_instance_path)"
    [[ -r "$instance_file" ]] || return 1
    IFS= read -r path < "$instance_file" || return 1
    [[ -n "$path" && "$path" != "$project_root" ]] || return 1
    punchi_owned_root "$path"
}

punchi_running_path() {
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

punchi_backend_for() {
    local root=""
    local candidate=""
    local distro_build=""
    for root in "$@"; do
        distro_build=""
        # Match the per-distribution tree the setup builds, then the plain one.
        if declare -F punchi_build_distro_id >/dev/null 2>&1 \
            && distro_build="$(punchi_build_distro_id 2>/dev/null)" \
            && [[ -n "$distro_build" ]]; then
            distro_build="$root/build-$distro_build/punchi-window-state"
        else
            distro_build=""
        fi
        for candidate in \
            ${distro_build:+"$distro_build"} \
            "$root/build/punchi-window-state" \
            "$root/../../libexec/punchi-dock-quickshell/punchi-window-state" \
            "$root/../../lib/punchi-dock-quickshell/punchi-window-state"; do
            if [[ -n "$candidate" && -x "$candidate" ]]; then
                printf '%s\n' "$candidate"
                return 0
            fi
        done
    done
    return 1
}

restore_owned_desktop_settings() {
    local backend=""
    local state_home="${XDG_STATE_HOME:-}"
    if [[ -z "$state_home" || "$state_home" != /* ]]; then
        state_home="$HOME/.local/state"
    fi
    local recovery_record="$state_home/punchi-dock-quickshell/owned-settings.json"
    local legacy_recovery_record="$state_home/punchi-shell/owned-settings.json"
    backend="$(punchi_backend_for "$@" || true)"
    if [[ -n "$backend" ]]; then
        "$backend" --restore-desktop-settings
    elif [[ -e "$recovery_record" || -L "$recovery_record" \
        || -e "$legacy_recovery_record" || -L "$legacy_recovery_record" ]]; then
        printf '%s\n' 'The KWin recovery record exists but no Punchi window backend is available.' >&2
        return 1
    fi
}

stop_path() {
    local path="${1:?path is required}"

    printf 'Stopping the configuration at %s...\n' "$path"
    for ((attempt=0; attempt<32; attempt++)); do
        if ! punchi_running_path "$path"; then
            return 0
        fi
        if ! qs kill --path "$path"; then
            if punchi_running_path "$path"; then
                printf 'Punchi Dock Quickshell at %s could not be stopped.\n' "$path" >&2
                return 1
            fi
            return 0
        fi
        # IPC acknowledges shutdown before the instance registry necessarily updates.
        for ((wait_step=0; wait_step<50; wait_step++)); do
            sleep 0.1
            if ! punchi_running_path "$path"; then
                return 0
            fi
        done
    done
    printf 'Punchi Dock Quickshell at %s did not finish shutting down.\n' "$path" >&2
    return 1
}

declare -a roots=()
active_root="$(punchi_active_root || true)"
if [[ -n "$active_root" ]]; then
    roots+=("$active_root")
fi
roots+=("$project_root")

if ! command -v qs >/dev/null 2>&1; then
    if ! restore_owned_desktop_settings "${roots[@]}"; then
        printf '%s\n' 'Quickshell is not installed and KWin settings could not be restored.' >&2
        exit 1
    fi
    printf '%s\n' 'Quickshell is not installed.'
    exit 0
fi

stopped=0
for root in "${roots[@]}"; do
    if punchi_running_path "$root"; then
        if ! stop_path "$root"; then
            exit 1
        fi
        stopped=1
    fi
done

if ! restore_owned_desktop_settings "${roots[@]}"; then
    printf '%s\n' 'Punchi Dock Quickshell stopped, but KWin settings could not be restored.' >&2
    exit 1
fi

if ((stopped)); then
    printf '%s\n' 'Punchi Dock Quickshell stopped. Plasma remains running.'
else
    printf '%s\n' 'Punchi Dock Quickshell is already stopped. Plasma remains running.'
fi
