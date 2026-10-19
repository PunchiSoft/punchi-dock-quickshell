#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Application-menu launcher with a persistent start log and failure notice.
set -u
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/punchi-dock-quickshell"
log_file="$log_dir/start.log"
icon="$project_root/assets/icons/punchi-dock-quickshell.svg"

notify_failure() {
    local summary="${1:?summary is required}"
    local detail="${2:-}"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send --app-name="Punchi Dock Quickshell" --icon="$icon" \
            "$summary" "$detail" >/dev/null 2>&1 || true
    elif command -v kdialog >/dev/null 2>&1; then
        kdialog --title "Punchi Dock Quickshell" --error "$summary

$detail" >/dev/null 2>&1 || true
    fi
}

case "${1:-start}" in
    start)
        shift || true
        mkdir -p "$log_dir" && chmod 700 "$log_dir" 2>/dev/null || true
        "$project_root/scripts-user/start.sh" "$@" >"$log_file" 2>&1
        status=$?
        if (( status != 0 )); then
            detail="$(tail -n 8 "$log_file" 2>/dev/null | tr '\n' ' ' | cut -c1-500)"
            if grep -q 'already running' "$log_file" 2>/dev/null; then
                notify_failure "Punchi Dock Quickshell is already running" "$detail"
            else
                notify_failure "Punchi Dock Quickshell could not start" "$detail"
            fi
        fi
        exit "$status"
        ;;
    stop)
        exec "$project_root/scripts-user/restore-kde.sh"
        ;;
    settings)
        exec "$project_root/scripts-user/settings.sh"
        ;;
    -h|--help)
        printf 'Usage: %s [start [mode]|stop|settings]\n' "$(basename "$0")"
        printf '%s\n' 'Starts Punchi Dock Quickshell through the application launcher.'
        ;;
    *)
        printf 'Usage: %s [start [mode]|stop|settings]\n' "$(basename "$0")" >&2
        exit 2
        ;;
esac
