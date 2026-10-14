#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

restore_owned_desktop_settings() {
    local backend="$project_root/build/punchi-window-state"
    local state_home="${XDG_STATE_HOME:-}"
    if [[ -z "$state_home" || "$state_home" != /* ]]; then
        state_home="$HOME/.local/state"
    fi
    local recovery_record="$state_home/punchi-dock-quickshell/owned-settings.json"
    local legacy_recovery_record="$state_home/punchi-shell/owned-settings.json"
    if [[ -x "$backend" ]]; then
        "$backend" --restore-desktop-settings
    elif [[ -e "$recovery_record" || -L "$recovery_record" \
        || -e "$legacy_recovery_record" || -L "$legacy_recovery_record" ]]; then
        return 1
    fi
}

if ! command -v qs >/dev/null 2>&1; then
    restore_owned_desktop_settings
    printf '%s\n' 'Quickshell is not installed.'
    exit 0
fi

# Select this exact configuration. Never stop Plasma or another shell config.
stopped=0
for ((attempt=0; attempt<32; attempt++)); do
    instances="$(qs list --path "$project_root" --json)"
    if [[ "$instances" == '[]' || "$instances" == 'No running instances for '* ]]; then
        restore_owned_desktop_settings
        if ((stopped)); then
            printf '%s\n' 'Punchi Dock Quickshell stopped. Plasma remains running.'
        else
            printf '%s\n' 'Punchi Dock Quickshell is already stopped. Plasma remains running.'
        fi
        exit 0
    fi
    qs kill --path "$project_root"
    stopped=1
    # IPC acknowledges shutdown before the instance registry necessarily updates.
    for ((wait_step=0; wait_step<50; wait_step++)); do
        sleep 0.1
        remaining="$(qs list --path "$project_root" --json)"
        if [[ "$remaining" != "$instances" ]]; then
            break
        fi
    done
    if [[ "$remaining" == "$instances" ]]; then
        printf '%s\n' 'Punchi Dock Quickshell did not finish shutting down.' >&2
        exit 1
    fi
done
printf '%s\n' 'Punchi Dock Quickshell still has running instances. Run this script again.' >&2
exit 1
