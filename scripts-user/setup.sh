#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Interactive setup assistant for Punchi Dock Quickshell.
set -euo pipefail

punchi_setup_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
punchi_project_root="$(cd -- "$punchi_setup_script_dir/.." && pwd)"

# shellcheck source=lib/setup-common.sh
source "$punchi_setup_script_dir/lib/setup-common.sh"
# shellcheck source=lib/setup-deps.sh
source "$punchi_setup_script_dir/lib/setup-deps.sh"
# shellcheck source=lib/setup-install.sh
source "$punchi_setup_script_dir/lib/setup-install.sh"

trap punchi_setup_cleanup EXIT

PUNCHI_ACTION=""
PUNCHI_INTERACTIVE=0
PUNCHI_START_AFTER=0
PUNCHI_REMOVE_SETTINGS=0
PUNCHI_REMOVE_BUILD=1
PUNCHI_INSTALL_MISSING=0
PUNCHI_ASSUME_YES="${PUNCHI_ASSUME_YES:-0}"

show_help() {
    cat <<EOF
Usage: scripts-user/setup.sh [options]

Punchi Dock Quickshell setup assistant. With no options it opens the
interactive menu.

Actions (choose one):
  --install           Build the checkout and install it for the current user.
  --update            Alias for --install.
  --build             Configure and build the checkout without installing.
  --check-deps        Report runtime, build and validation dependencies.
  --uninstall         Stop this project, restore owned KDE settings, remove
                      build output and the user-local installation.
  --start             Start the dock.
  --instructions      Show quick start instructions and README locations.
  -h, --help          Show this help.

Options:
  --prefix PATH       Install root. Default:
                      \${XDG_DATA_HOME:-\$HOME/.local/share}/punchi-dock-quickshell
  --remove-settings   With --uninstall, also delete the current preferences
                      file. The interactive menu asks separately.
  --keep-build        With --uninstall, keep the checkout's build/ directory.
  --install-missing   With --check-deps, offer to install missing Fedora
                      packages. It never runs without confirmation.
  -y, --yes           Assume yes for confirmations. The interactive menu still
                      asks separately before deleting preferences.
  -j, --jobs N        Parallel build jobs. Default: detected CPU count.
  --no-color          Disable ANSI colors.
EOF
}

show_header() {
    local version=""
    local family=""
    local source_line=""
    local install_root=""

    version="$(punchi_project_version)"
    family="$(punchi_distro_family "$(punchi_distro_id)" "$(punchi_distro_like)")"
    if ! install_root="$(punchi_install_root 2>/dev/null)"; then
        install_root="invalid or unsafe"
    fi
    if punchi_source_checkout_available; then
        source_line="Source checkout"
    else
        source_line="Installed copy"
    fi

    punchi_rule
    punchi_heading "Punchi Dock Quickshell · Setup"
    printf 'Version %s | %s | %s\n' "$version" "$(punchi_system_name)" "$(uname -m)"
    printf 'Distribution family: %s | %s\n' "$family" "$source_line"
    printf 'Install root: %s\n' "$install_root"
    punchi_rule
}

show_quick_instructions() {
    local readme="$punchi_project_root/README.md"

    punchi_heading "Instructions"
    cat <<EOF
Guided setup
  Run this menu, choose "Check runtime and build dependencies", then choose
  "Install or update". The installer builds the native KDE components and
  copies the runtime into the user install root.

Start and return to KDE
  Start:           $punchi_project_root/scripts-user/start.sh
  Stop:            $punchi_project_root/scripts-user/restore-kde.sh
  Settings window: $punchi_project_root/scripts-user/settings.sh

Panel modes
  $punchi_project_root/scripts-user/start.sh reserve
  $punchi_project_root/scripts-user/start.sh dodge-windows
  $punchi_project_root/scripts-user/start.sh overlay
  $punchi_project_root/scripts-user/start.sh autohide

Preferences
  ${XDG_CONFIG_HOME:-\$HOME/.config}/punchi-dock-quickshell.json
  Uninstall keeps this file unless you confirm its removal separately.

Documentation
  README: $readme
EOF
    if [[ -d "$punchi_project_root/docs" ]]; then
        printf '  Local development notes: %s\n' "$punchi_project_root/docs"
    fi
    cat <<EOF

Plasma stays running throughout setup, uninstallation and restoration.
EOF

    if [[ -t 0 ]] && command -v xdg-open >/dev/null 2>&1; then
        if punchi_confirm "Open README.md in the default application? [y/N]: " n; then
            xdg-open "$readme" >/dev/null 2>&1 &
        fi
    fi
}

punchi_start_script_for() {
    local root="${1:?root is required}"
    printf '%s/scripts-user/start.sh\n' "$root"
}

punchi_start_installed_or_checkout() {
    local install_root=""
    local source_start="$punchi_project_root/scripts-user/start.sh"
    local installed_start=""

    install_root="$(punchi_install_root)" || return 1
    installed_start="$(punchi_start_script_for "$install_root")"

    if [[ -x "$installed_start" \
        && -f "$install_root/build/qml/Punchi/Kde/libpunchikdeplugin.so" \
        && -x "$install_root/build/punchi-window-state" ]]; then
        punchi_info "Starting the installed copy from $install_root"
        exec "$installed_start" "$@"
    fi
    if [[ -x "$source_start" ]] && punchi_build_artifacts_ready; then
        punchi_info "Starting the source checkout from $punchi_project_root"
        exec "$source_start" "$@"
    fi
    punchi_error "No built installation was found."
    punchi_info "Choose \"Install or update\" first."
    return 1
}

punchi_action_install() {
    if ! punchi_source_checkout_available; then
        punchi_error "Install/update actions require the source checkout."
        punchi_info "Run this menu from the cloned repository."
        return 1
    fi
    if ! punchi_dependency_check 0; then
        punchi_warning "Resolve the required dependencies before building."
        punchi_info "Choose \"Check runtime and build dependencies\" for details."
        return 1
    fi
    punchi_build_checkout || return 1
    punchi_install_local || return 1

    if (( PUNCHI_START_AFTER == 1 )); then
        punchi_start_installed_or_checkout
    elif (( PUNCHI_INTERACTIVE == 1 )) && [[ -t 0 ]]; then
        if punchi_confirm "Start the installed dock now? [Y/n]: " y; then
            punchi_start_installed_or_checkout
        fi
    fi
    return 0
}

punchi_action_build() {
    if ! punchi_source_checkout_available; then
        punchi_error "Build actions require the source checkout."
        return 1
    fi
    if ! punchi_dependency_check 0; then
        punchi_warning "Resolve the required dependencies before building."
        punchi_info "Choose \"Check runtime and build dependencies\" for details."
        return 1
    fi
    punchi_build_checkout || return 1
    if (( PUNCHI_START_AFTER == 1 )); then
        punchi_info "Starting the source checkout from $punchi_project_root"
        exec "$punchi_project_root/scripts-user/start.sh"
    elif (( PUNCHI_INTERACTIVE == 1 )) && [[ -t 0 ]]; then
        if punchi_confirm "Start the source-checkout dock now? [Y/n]: " y; then
            punchi_info "Starting the source checkout from $punchi_project_root"
            exec "$punchi_project_root/scripts-user/start.sh"
        fi
    fi
    return 0
}

punchi_action_dependencies() {
    local offer="${1:-1}"
    punchi_dependency_check "$offer"
}

punchi_action_uninstall() {
    local install_root=""
    install_root="$(punchi_install_root)" || return 1

    punchi_warning "Uninstall will stop this project's checkout and installed copies,"
    punchi_warning "restore owned KWin settings, and remove:"
    printf '  - %s\n' "$install_root"
    if (( PUNCHI_REMOVE_BUILD == 1 )) && punchi_source_checkout_available; then
        printf '  - %s\n' "$punchi_project_root/build"
    fi
    if punchi_source_checkout_available; then
        punchi_info "The source checkout and personal preferences are kept by default."
    else
        punchi_info "Personal preferences are kept by default."
    fi
    if ! punchi_confirm "Continue with uninstall? [y/N]: " n; then
        punchi_info "Uninstall cancelled."
        return 0
    fi

    local status=0
    punchi_uninstall_local "$PUNCHI_REMOVE_BUILD" "$PUNCHI_REMOVE_SETTINGS" || status=1

    if (( PUNCHI_REMOVE_SETTINGS == 0 )) && [[ -t 0 ]] \
        && [[ "${PUNCHI_ASSUME_YES:-0}" != "1" ]]; then
        if punchi_confirm "Also delete the current preferences file? [y/N]: " n; then
            punchi_remove_preferences 1 0 || status=1
        fi
    fi
    return "$status"
}

interactive_menu() {
    local choice=""
    PUNCHI_INTERACTIVE=1
    while true; do
        show_header
        printf '\n'
        punchi_muted "What would you like to do?"
        printf '\n'
        punchi_muted "Primary actions"
        printf '%s\n' '  [1] Install or update (build and install for this user)'
        printf '%s\n' '  [2] Build or rebuild the source checkout only'
        printf '%s\n' '  [3] Start the dock'
        printf '\n'
        punchi_muted "Maintenance"
        printf '%s\n' '  [4] Check runtime and build dependencies'
        printf '%s\n' '  [5] Uninstall'
        printf '\n'
        punchi_muted "Help"
        printf '%s\n' '  [6] Instructions and README'
        printf '%s\n' '  [7] Command-line options'
        printf '%s\n' '  [8] Exit'
        printf '\n'
        printf '%s' 'Select an option [1-8]: '
        read -r choice || break

        case "$choice" in
            1)
                punchi_action_install || true
                punchi_pause
                ;;
            2)
                punchi_action_build || true
                punchi_pause
                ;;
            3)
                punchi_start_installed_or_checkout || true
                punchi_pause
                ;;
            4)
                punchi_action_dependencies 1 || true
                punchi_pause
                ;;
            5)
                punchi_action_uninstall || true
                punchi_pause
                ;;
            6)
                show_quick_instructions
                punchi_pause
                ;;
            7)
                show_help
                punchi_pause
                ;;
            8|q|Q)
                punchi_info "Setup closed."
                return 0
                ;;
            *)
                punchi_error "Invalid option: $choice"
                punchi_pause
                ;;
        esac
    done
}

set_action() {
    local action="${1:?action is required}"
    if [[ -n "$PUNCHI_ACTION" && "$PUNCHI_ACTION" != "$action" ]]; then
        punchi_die "Only one primary action can be selected."
    fi
    PUNCHI_ACTION="$action"
}

parse_args() {
    while (( $# > 0 )); do
        case "$1" in
            --install|--update) set_action install; shift ;;
            --build) set_action build; shift ;;
            --check-deps) set_action check_deps; shift ;;
            --uninstall) set_action uninstall; shift ;;
            --instructions) set_action instructions; shift ;;
            --start) PUNCHI_START_AFTER=1; shift ;;
            --remove-settings) PUNCHI_REMOVE_SETTINGS=1; shift ;;
            --keep-build) PUNCHI_REMOVE_BUILD=0; shift ;;
            --install-missing) PUNCHI_INSTALL_MISSING=1; shift ;;
            -y|--yes) PUNCHI_ASSUME_YES=1; shift ;;
            --no-color) NO_COLOR=1; shift ;;
            --prefix)
                (( $# >= 2 )) || punchi_die "$1 requires a path."
                PUNCHI_INSTALL_PREFIX="$2"
                shift 2
                ;;
            --prefix=*)
                PUNCHI_INSTALL_PREFIX="${1#*=}"
                shift
                ;;
            -j|--jobs)
                (( $# >= 2 )) || punchi_die "$1 requires a positive integer."
                PUNCHI_JOBS="$2"
                shift 2
                ;;
            --jobs=*|-j=*)
                PUNCHI_JOBS="${1#*=}"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                punchi_error "Unknown option: $1"
                show_help >&2
                exit 2
                ;;
        esac
    done

    if [[ -n "${PUNCHI_JOBS:-}" && ! "$PUNCHI_JOBS" =~ ^[1-9][0-9]*$ ]]; then
        punchi_die "The number of jobs must be a positive integer."
    fi
    if (( PUNCHI_REMOVE_SETTINGS == 1 )) && [[ "$PUNCHI_ACTION" != "uninstall" ]]; then
        punchi_die "--remove-settings requires --uninstall."
    fi
    if (( PUNCHI_INSTALL_MISSING == 1 )) && [[ "$PUNCHI_ACTION" != "check_deps" ]]; then
        punchi_die "--install-missing requires --check-deps."
    fi
}

punchi_detect_installed_prefix() {
    if [[ -z "${PUNCHI_INSTALL_PREFIX:-}" ]] && ! punchi_source_checkout_available; then
        PUNCHI_INSTALL_PREFIX="$punchi_project_root"
    fi
}

main() {
    if (( EUID == 0 )); then
        punchi_die "Run this script as the desktop user, not with sudo."
    fi

    parse_args "$@"
    punchi_detect_installed_prefix

    if [[ -z "$PUNCHI_ACTION" ]]; then
        if (( PUNCHI_START_AFTER == 1 )); then
            PUNCHI_ACTION=start
        else
            interactive_menu
            return 0
        fi
    fi

    show_header
    printf '\n'
    case "$PUNCHI_ACTION" in
        install) punchi_action_install ;;
        build) punchi_action_build ;;
        check_deps) punchi_action_dependencies "$PUNCHI_INSTALL_MISSING" ;;
        uninstall) punchi_action_uninstall ;;
        instructions) show_quick_instructions ;;
        start) punchi_start_installed_or_checkout ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
