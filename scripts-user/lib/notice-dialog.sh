#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Blocking system notice used when the dock cannot run in this session.
#
# There is no single cross-desktop dialog in Linux, so the native one available
# is preferred: kdialog on KDE, zenity on GTK desktops, xmessage on X11. When
# none is available the caller has already written the same text to stderr.

punchi_notice_title='Punchi Dock Quickshell'

punchi_notice_dialog_enabled() {
    case "${PUNCHI_NOTICE_DIALOG:-auto}" in
        0|no|false) return 1 ;;
        1|yes|true) return 0 ;;
    esac
    # Auto: a graphical launch has no controlling terminal.
    [[ ! -t 0 && ! -t 1 ]]
}

punchi_notice_tool_available() {
    if command -v kdialog >/dev/null 2>&1; then
        return 0
    fi
    if command -v zenity >/dev/null 2>&1; then
        return 0
    fi
    command -v xmessage >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]
}

# Whether calling punchi_show_notice would present anything. The launcher uses
# it to avoid staying silent when no dialog tool exists.
punchi_notice_available() {
    punchi_notice_dialog_enabled || return 1
    punchi_gui_session_available || return 1
    punchi_notice_tool_available
}

punchi_show_notice() {
    local title="${1:-$punchi_notice_title}"
    local text="${2:-}"
    [[ -n "$text" ]] || return 1
    punchi_notice_available || return 1
    if command -v kdialog >/dev/null 2>&1; then
        kdialog --title "$title" --error "$text" >/dev/null 2>&1 || true
    elif command -v zenity >/dev/null 2>&1; then
        zenity --error --no-markup --title="$title" --text="$text" \
            --width=460 >/dev/null 2>&1 || true
    else
        xmessage -center -title "$title" "$text" >/dev/null 2>&1 || true
    fi
    return 0
}

# The approved startup notice: title line plus one paragraph.
punchi_environment_notice_text() {
    printf '%s\n' 'KDE Plasma is required'
    punchi_environment_message
}
