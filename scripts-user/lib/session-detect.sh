#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Shared desktop-session detection for the user scripts.
#
# The dock only supports KDE Plasma on Wayland. These helpers exist so the
# installer, the launcher and the startup guard describe the current session
# with one vocabulary instead of each keeping its own copy.

punchi_unknown_desktop_label='an unknown desktop session'

# XDG_CURRENT_DESKTOP is a colon-separated list and is untrusted input.
punchi_current_desktop_tokens() {
    local -a fields=()
    local token=''
    local IFS=':'
    # `read -a` splits without pathname expansion, so a value such as `*`
    # cannot turn into a directory listing.
    read -r -a fields <<<"${XDG_CURRENT_DESKTOP:-}"
    for token in "${fields[@]}"; do
        if [[ -n "$token" ]]; then
            printf '%s\n' "$token"
        fi
    done
}

punchi_sanitize_label() {
    local value="${1:-}"
    value="${value//[[:cntrl:]]/}"
    value="${value//</}"
    value="${value//>/}"
    value="${value//\"/}"
    value="${value//\'/}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    if ((${#value} > 64)); then
        value="${value:0:64}"
    fi
    printf '%s\n' "$value"
}

punchi_desktop_label_for_token() {
    local token="${1,,}"
    case "$token" in
        kde) printf '%s\n' 'KDE Plasma' ;;
        gnome) printf '%s\n' 'GNOME' ;;
        ubuntu) printf '%s\n' 'Ubuntu' ;;
        pop) printf '%s\n' 'Pop!_OS' ;;
        x-cinnamon|cinnamon) printf '%s\n' 'Cinnamon' ;;
        xfce) printf '%s\n' 'Xfce' ;;
        mate) printf '%s\n' 'MATE' ;;
        lxqt) printf '%s\n' 'LXQt' ;;
        budgie) printf '%s\n' 'Budgie' ;;
        deepin|dde) printf '%s\n' 'Deepin' ;;
        pantheon) printf '%s\n' 'Pantheon' ;;
        cosmic) printf '%s\n' 'COSMIC' ;;
        unity) printf '%s\n' 'Unity' ;;
        regolith) printf '%s\n' 'Regolith' ;;
        ukui) printf '%s\n' 'UKUI' ;;
        phosh) printf '%s\n' 'Phosh' ;;
        lomiri) printf '%s\n' 'Lomiri' ;;
        enlightenment) printf '%s\n' 'Enlightenment' ;;
        sway) printf '%s\n' 'Sway' ;;
        hyprland) printf '%s\n' 'Hyprland' ;;
        niri) printf '%s\n' 'niri' ;;
        river) printf '%s\n' 'River' ;;
        wayfire) printf '%s\n' 'Wayfire' ;;
        labwc) printf '%s\n' 'labwc' ;;
        miracle) printf '%s\n' 'Miracle WM' ;;
    esac
}

punchi_desktop_label() {
    local token=''
    local label=''
    while IFS= read -r token; do
        label="$(punchi_desktop_label_for_token "$token")"
        if [[ -n "$label" ]]; then
            printf '%s\n' "$label"
            return 0
        fi
    done < <(punchi_current_desktop_tokens)
    token="$(punchi_current_desktop_tokens | head -n 1)"
    token="$(punchi_sanitize_label "$token")"
    if [[ -n "$token" ]]; then
        printf '%s\n' "$token"
        return 0
    fi
    printf '%s\n' "$punchi_unknown_desktop_label"
}

punchi_session_type() {
    case "${XDG_SESSION_TYPE:-}" in
        wayland|Wayland|WAYLAND) printf '%s\n' 'wayland'; return 0 ;;
        x11|X11) printf '%s\n' 'x11'; return 0 ;;
        mir|Mir|MIR) printf '%s\n' 'mir'; return 0 ;;
    esac
    # Some sessions export only the display server variable.
    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        printf '%s\n' 'wayland'
    elif [[ -n "${DISPLAY:-}" ]]; then
        printf '%s\n' 'x11'
    else
        printf '%s\n' 'unknown'
    fi
}

punchi_session_surface_label() {
    case "$(punchi_session_type)" in
        wayland) printf '%s\n' 'Wayland' ;;
        x11) printf '%s\n' 'X11' ;;
        mir) printf '%s\n' 'Mir' ;;
        *) printf '%s\n' 'an unknown display server' ;;
    esac
}

punchi_gui_session_available() {
    [[ -n "${WAYLAND_DISPLAY:-}" || -n "${DISPLAY:-}" ]]
}

punchi_kde_session_detected() {
    local tokens=''
    local token=''
    tokens="$(punchi_current_desktop_tokens)"
    if [[ -n "$tokens" ]]; then
        while IFS= read -r token; do
            case "${token,,}" in
                *kde*) return 0 ;;
            esac
        done <<< "$tokens"
        # An explicit non-KDE desktop wins over process sniffing: another
        # session may keep Plasma running on the same machine.
        return 1
    fi
    if [[ "${KDE_FULL_SESSION:-}" == 'true' ]]; then
        return 0
    fi
    command -v pgrep >/dev/null 2>&1 || return 1
    pgrep -x plasmashell >/dev/null 2>&1 && pgrep -x kwin_wayland >/dev/null 2>&1
}

# KDE Plasma is installed when a Plasma session file exists or its entry points
# are on PATH. Package queries are avoided: they need a package manager, may hit
# the network and answer a different question.
punchi_plasma_installed() {
    local wayland_dir="${PUNCHI_WAYLAND_SESSIONS_DIR:-/usr/share/wayland-sessions}"
    local xsessions_dir="${PUNCHI_XSESSIONS_DIR:-/usr/share/xsessions}"
    local file=''
    for file in "$wayland_dir"/*.desktop "$xsessions_dir"/plasma*.desktop; do
        [[ -r "$file" ]] || continue
        case "${file##*/}" in
            plasma*.desktop) return 0 ;;
        esac
        if grep -qis '^DesktopNames=.*KDE' "$file" 2>/dev/null; then
            return 0
        fi
    done
    if command -v startplasma-wayland >/dev/null 2>&1; then
        return 0
    fi
    command -v plasmashell >/dev/null 2>&1
}

# One of: supported, kde-not-wayland, plasma-available, plasma-missing,
# unknown-session.
punchi_environment_cause() {
    if punchi_kde_session_detected; then
        case "$(punchi_session_type)" in
            wayland) printf '%s\n' 'supported' ;;
            x11|mir) printf '%s\n' 'kde-not-wayland' ;;
            *) printf '%s\n' 'unknown-session' ;;
        esac
        return 0
    fi
    if ! punchi_gui_session_available; then
        printf '%s\n' 'unknown-session'
        return 0
    fi
    if punchi_plasma_installed; then
        printf '%s\n' 'plasma-available'
    else
        printf '%s\n' 'plasma-missing'
    fi
}

punchi_environment_supported() {
    punchi_kde_session_detected && [[ "$(punchi_session_type)" == 'wayland' ]]
}

# Cause and recovery for the current environment, as two separate lines.
punchi_environment_explanation() {
    case "$(punchi_environment_cause)" in
        kde-not-wayland)
            printf '%s\n' 'This version of the dock needs a Wayland session.'
            ;;
        plasma-available)
            printf '%s\n' 'KDE Plasma is installed on this system, but it is not your current session.'
            ;;
        plasma-missing)
            printf '%s\n' 'KDE Plasma is not installed on this system.'
            ;;
    esac
}

punchi_environment_next_step() {
    case "$(punchi_environment_cause)" in
        kde-not-wayland)
            printf '%s\n' 'Log out and choose a Plasma (Wayland) session.'
            ;;
        plasma-available)
            printf '%s\n' 'Log out, choose a Plasma (Wayland) session, then open the dock again.'
            ;;
        plasma-missing)
            printf '%s\n' 'Install KDE Plasma first, then open the dock again.'
            ;;
        *)
            printf '%s\n' 'Open the dock from a KDE Plasma (Wayland) session.'
            ;;
    esac
}

# "You are using GNOME on Wayland. <cause> <next step>", or a session-unknown
# sentence when no desktop could be identified.
punchi_environment_message() {
    local label=''
    local surface=''
    local explanation=''
    local next_step=''
    local message=''
    label="$(punchi_desktop_label)"
    surface="$(punchi_session_surface_label)"
    explanation="$(punchi_environment_explanation)"
    next_step="$(punchi_environment_next_step)"
    if [[ "$label" == "$punchi_unknown_desktop_label" ]]; then
        message='The current session could not be detected.'
    else
        message="You are using $label on $surface."
    fi
    if [[ -n "$explanation" ]]; then
        message="$message $explanation"
    fi
    printf '%s %s\n' "$message" "$next_step"
}
