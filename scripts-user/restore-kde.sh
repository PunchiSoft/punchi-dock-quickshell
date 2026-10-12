#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v qs >/dev/null 2>&1; then
    printf '%s\n' 'Quickshell is not installed. This project has not changed Plasma.'
    exit 0
fi
# Select this exact configuration. Never stop Plasma or another shell config.
stopped=0
for ((attempt=0; attempt<32; attempt++)); do
    instances="$(qs list --path "$project_root" --json)"
    if [[ "$instances" == '[]' || "$instances" == 'No running instances for '* ]]; then
        if ((stopped)); then
            printf '%s\n' 'Punchi Shell stopped. Plasma has not been changed.'
        else
            printf '%s\n' 'Punchi Shell is already stopped. Plasma has not been changed.'
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
        printf '%s\n' 'Punchi Shell did not finish shutting down.' >&2
        exit 1
    fi
done
printf '%s\n' 'Punchi Shell still has running instances. Run this script again.' >&2
exit 1
