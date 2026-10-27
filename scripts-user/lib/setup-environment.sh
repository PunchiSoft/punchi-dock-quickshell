#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Installation-time environment guard for the user setup assistant.
#
# The dock only supports KDE Plasma on Wayland. Refusing before the build and
# the copy is the root-cause guard: nothing is written when the session cannot
# run the result.

punchi_setup_environment_dir="${BASH_SOURCE[0]%/*}"
if [[ "$punchi_setup_environment_dir" == "${BASH_SOURCE[0]}" ]]; then
    punchi_setup_environment_dir='.'
fi
if ! declare -F punchi_desktop_label >/dev/null 2>&1; then
    # shellcheck source=session-detect.sh
    source "$punchi_setup_environment_dir/session-detect.sh"
fi
unset punchi_setup_environment_dir

punchi_can_confirm_environment() {
    [[ -t 0 ]] && [[ "${PUNCHI_ASSUME_YES:-0}" != '1' ]]
}

# Warns, identifies the session and asks once. Returns 0 to continue, 1 to stop.
# PUNCHI_ALLOW_NON_KDE=1 skips the guard, matching scripts-user/start.sh.
punchi_require_kde_environment() {
    local action="${1:-install}"
    local answer=''

    if [[ "${PUNCHI_ALLOW_NON_KDE:-0}" == '1' ]]; then
        return 0
    fi
    if punchi_environment_supported; then
        return 0
    fi
    if ! punchi_gui_session_available; then
        punchi_info 'No graphical session was detected. The files will be installed for later use in a KDE Plasma (Wayland) session.'
        return 0
    fi

    punchi_warning 'Punchi Dock Quickshell requires KDE Plasma on Wayland.'
    punchi_environment_message
    if ! punchi_can_confirm_environment; then
        punchi_error 'Nothing was installed. Re-run this setup in a Plasma session, or set PUNCHI_ALLOW_NON_KDE=1 to install anyway.'
        return 1
    fi
    printf '%s' 'Continue anyway? [y/N] '
    read -r answer || answer=''
    case "${answer,,}" in
        y|yes|s|si|sí) return 0 ;;
    esac
    punchi_error 'Nothing was installed. Re-run this setup in a Plasma session, or set PUNCHI_ALLOW_NON_KDE=1 to install anyway.'
    return 1
}
