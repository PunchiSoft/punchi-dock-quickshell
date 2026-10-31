#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Interactive setup assistant for Punchi Dock Quickshell.
set -euo pipefail

punchi_setup_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
punchi_project_root="$(cd -- "$punchi_setup_script_dir/.." && pwd)"

# shellcheck source=lib/setup-common.sh
source "$punchi_setup_script_dir/lib/setup-common.sh"
# shellcheck source=lib/setup-progress.sh
source "$punchi_setup_script_dir/lib/setup-progress.sh"
# shellcheck source=lib/setup-deps.sh
source "$punchi_setup_script_dir/lib/setup-deps.sh"
# shellcheck source=lib/setup-environment.sh
source "$punchi_setup_script_dir/lib/setup-environment.sh"
# shellcheck source=lib/setup-install.sh
source "$punchi_setup_script_dir/lib/setup-install.sh"
# shellcheck source=lib/setup-updates.sh
source "$punchi_setup_script_dir/lib/setup-updates.sh"

trap punchi_setup_cleanup EXIT

PUNCHI_ACTION=""
PUNCHI_START_AFTER=0
PUNCHI_REMOVE_SETTINGS=0
PUNCHI_REMOVE_BUILD=0
PUNCHI_CLEAN_ALL=0
PUNCHI_INSTALL_MISSING=0
PUNCHI_PULL=0
PUNCHI_ASSUME_YES="${PUNCHI_ASSUME_YES:-0}"

show_help() {
    cat <<EOF
Usage: scripts-user/setup.sh [options]

Punchi Dock Quickshell setup assistant. With no options it opens the
interactive menu. This project requires KDE Plasma/KWin on Wayland; it will
not run on other desktops.

Actions (choose one):
  --install           Check/offer dependencies, build the checkout and install
                      it for the current user.
  --update            Alias for --install.
  --build             Check/offer dependencies and build without installing.
  --try, --test       Check/offer dependencies, build the checkout and run it
                      from the checkout. Nothing is installed and the installed
                      copy is never used.
  --check-deps        Report runtime, build and validation dependencies. With
                      --install-missing, offer to install missing packages.
  --check-updates     Fetch the configured Git remote and report whether this
                      checkout is behind. It only reads unless --pull is used.
                      The interactive menu can pull and then offer a rebuild and
                      install.
  --uninstall         Stop this project, restore owned KDE settings and remove
                      the user-local installation. Build output is kept by
                      default.
  --start             Start the dock from an existing build or user-local
                      installation. It builds nothing; use --try or --build
                      first. With --install or --build, start after the action
                      finishes.
  --instructions      Show quick start instructions and README locations.
  -h, --help          Show this help.

Options:
  --prefix PATH       Install root. Default:
                      \${XDG_DATA_HOME:-\$HOME/.local/share}/punchi-dock-quickshell
  --remove-settings   With --uninstall, also delete the current preferences
                      file. The interactive menu asks separately.
  --remove-build      With --uninstall, also remove the checkout's build/
                      directory.
  --keep-build        Kept for compatibility; build output is kept by default.
  --install-missing   With --check-deps, offer to install missing packages for
                      the detected distribution. It never runs without
                      confirmation; Debian/Ubuntu and Arch maps were matched to
                      one installation each, so verify names if your release
                      differs.
  --pull              With --check-updates, run git pull --ff-only when the
                      checkout is behind. It refuses when tracked files have
                      modifications and never rebases, resets or stashes. The
                      interactive menu asks before pulling and then offers to
                      rebuild and install; this option never installs.
  -y, --yes           Assume yes for confirmations. The interactive menu still
                      asks separately before deleting preferences.
  -j, --jobs N        Parallel build jobs. Overrides the automatic count, which
                      is the detected CPU count capped by installed RAM.
  --no-color          Disable ANSI colors. The animated progress line also stops
                      when stdout is redirected or TERM=dumb.
EOF
}

show_header() {
    local version=""
    local family=""
    local source_line=""
    local install_root=""
    local installed_version=""
    local version_file=""
    local environment_line=""
    local resources_line=""

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
    version_file="$install_root/$(punchi_install_version_name)"
    if [[ "$install_root" != "invalid or unsafe" && -r "$version_file" ]]; then
        installed_version="$(head -n 1 "$version_file")"
    fi

    printf -v environment_line 'Version %s | %s | %s' \
        "$version" "$(punchi_system_name)" "$(uname -m)"
    printf -v resources_line 'RAM %s | CPU cores %s | Build jobs %s' \
        "$(punchi_format_ram_display)" \
        "$(punchi_cpu_core_count)" \
        "$(punchi_job_count)"

    punchi_ui_render_header "Punchi Dock Quickshell · Setup" \
        "$environment_line" "$resources_line"
    printf 'Distribution family: %s | %s\n' "$family" "$source_line"
    if punchi_kde_session_detected; then
        printf '%s\n' 'Session: KDE Plasma/KWin'
    else
        punchi_warning 'Session: KDE Plasma/KWin not detected (required)'
    fi
    printf 'Install root: %s\n' "$install_root"
    if punchi_source_checkout_available; then
        printf 'Build output: %s\n' "$(punchi_build_dir)"
    fi
    if [[ -n "$installed_version" ]]; then
        if punchi_source_checkout_available && [[ "$installed_version" != "$version" ]]; then
            punchi_warning "Installed copy: $installed_version (outdated; source is $version)"
        else
            printf 'Installed copy: %s\n' "$installed_version"
        fi
    fi
    punchi_rule
}

show_quick_instructions() {
    local readme="$punchi_project_root/README.md"

    punchi_heading "Instructions"
    cat <<EOF
Cloning on a fresh system
  git is required to clone and this assistant never installs it:
    Fedora          sudo dnf install git
    Debian/Ubuntu   sudo apt-get install git
    Arch            sudo pacman -S git

Guided setup
  Punchi Dock Quickshell requires KDE Plasma/KWin on Wayland and will not run
  on another desktop. Run this menu, choose "Check runtime and build
  dependencies", then choose "Install or update". The installer builds the
  native KDE components and copies the runtime into the user install root.

Trying it without installing
  Choose "Try it without installing" to build this checkout and run it from
  here. Nothing is written to the install root, the application menu or your
  preferences. Closing the dock returns to this menu.

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

Build failures
  A timestamped log is written under the user's Documents directory.

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

# The dock runs as a child instead of replacing this process. `exec` would drop
# the menu when the dock closes and would skip the EXIT cleanup that removes the
# step transcripts, so every start path goes through this seam.
punchi_run_dock() {
    local start_script="${1:?start script is required}"
    shift

    "$start_script" "$@"
}

punchi_report_dock_exit() {
    local status="${1:-0}"

    if (( status == 0 )); then
        punchi_info "The dock closed."
    elif punchi_status_is_stopped "$status"; then
        punchi_info "The dock stopped."
    else
        punchi_error "The dock exited with status $status."
    fi
}

punchi_start_installed_or_checkout() {
    local install_root=""
    local source_start="$punchi_project_root/scripts-user/start.sh"
    local installed_start=""
    local status=0

    install_root="$(punchi_install_root)" || return 1
    installed_start="$(punchi_start_script_for "$install_root")"

    if [[ -x "$installed_start" \
        && -f "$install_root/build/qml/Punchi/Kde/libpunchikdeplugin.so" \
        && -x "$install_root/build/punchi-window-state" ]]; then
        local installed_version=""
        local source_version=""
        local version_file="$install_root/$(punchi_install_version_name)"
        if [[ -r "$version_file" ]]; then
            installed_version="$(head -n 1 "$version_file")"
            source_version="$(punchi_project_version)"
            if [[ -n "$installed_version" && "$installed_version" != "$source_version" ]]; then
                punchi_warning "The installed copy is $installed_version; the source checkout is $source_version."
                punchi_info "Run Install/update to refresh it if you want the newer build."
            fi
        fi
        punchi_info "Starting the installed copy from $install_root"
        punchi_run_dock "$installed_start" "$@" || status=$?
        punchi_report_dock_exit "$status"
        return "$status"
    fi
    if [[ -x "$source_start" ]] && punchi_build_artifacts_ready; then
        punchi_info "Starting the source checkout from $punchi_project_root"
        punchi_run_dock "$source_start" "$@" || status=$?
        punchi_report_dock_exit "$status"
        return "$status"
    fi
    punchi_error "No built checkout or user-local installation was found."
    if punchi_source_checkout_available; then
        punchi_info "Build it with [2] Build or rebuild, or use [3] Try it without installing."
        punchi_info "To keep a copy in your application menu, use [1] Install or update."
    else
        punchi_info "Install it first with [1] Install or update."
    fi
    return 1
}

punchi_phase_dependencies() {
    local index="${1:?phase index is required}"
    local total="${2:?phase total is required}"

    punchi_ui_render_phase_started "$index" "$total" 'Dependencies'
    if ! punchi_dependency_check 1 0; then
        punchi_ui_render_phase "$index" "$total" warning 'Dependencies' \
            'Needs attention'
        punchi_warning "Resolve the required dependencies before building."
        punchi_info "Choose \"Check runtime and build dependencies\" for details."
        return 1
    fi
    punchi_ui_render_phase "$index" "$total" success 'Dependencies' 'Present'
}

punchi_phase_build() {
    local index="${1:?phase index is required}"
    local total="${2:?phase total is required}"

    punchi_ui_render_phase_started "$index" "$total" 'Build'
    if ! punchi_build_checkout; then
        punchi_ui_render_phase "$index" "$total" error 'Build' 'Failed'
        return 1
    fi
    punchi_ui_render_phase "$index" "$total" success 'Build' 'Completed'
}

punchi_action_try() {
    local total=3
    local start_script="$punchi_project_root/scripts-user/start.sh"
    local trial_profile=""
    local status=0

    if ! punchi_source_checkout_available; then
        punchi_error "Running without installing requires the source checkout."
        punchi_info "Run this menu from the cloned repository."
        return 1
    fi
    # A running copy already owns this checkout's build output and its
    # registration, so a trial cannot promise to leave nothing behind.
    if punchi_running_path "$punchi_project_root"; then
        punchi_error "Punchi Dock Quickshell is already running from:"
        printf '  %s\n' "$punchi_project_root"
        punchi_info "Stop it first:"
        printf '  %s/scripts-user/restore-kde.sh\n' "$punchi_project_root"
        return 1
    fi
    punchi_require_kde_environment 'try' || return 1

    punchi_phase_dependencies 1 "$total" || return 1
    punchi_phase_build 2 "$total" || return 1

    punchi_ui_render_phase_started 3 "$total" 'Run'
    if [[ ! -x "$start_script" ]]; then
        punchi_ui_render_phase 3 "$total" error 'Run' 'Start script missing'
        punchi_error "The start script is missing or not executable: $start_script"
        return 1
    fi
    trial_profile="$(punchi_trial_profile_dir)"
    if ! mkdir -p -m 700 -- "$trial_profile"; then
        punchi_ui_render_phase 3 "$total" error 'Run' 'Trial profile unavailable'
        punchi_error "Could not create the trial profile at $trial_profile."
        return 1
    fi
    export PUNCHI_PROFILE_DIR="$trial_profile"
    # Ctrl+C reaches this shell and the dock together. Handling it here keeps
    # the script alive long enough to ask for the cleanup below.
    trap ':' INT
    punchi_run_dock "$start_script" || status=$?
    trap - INT
    unset PUNCHI_PROFILE_DIR
    if (( status == 0 )); then
        punchi_ui_render_phase 3 "$total" success 'Run' 'Completed'
    elif punchi_status_is_stopped "$status"; then
        punchi_ui_render_phase 3 "$total" warning 'Run' 'Stopped'
        punchi_info "The trial stopped."
    else
        punchi_ui_render_phase 3 "$total" error 'Run' "Exit status $status"
    fi
    punchi_trial_cleanup "$trial_profile" || true
    return "$status"
}

punchi_action_install() {
    local total=3

    if ! punchi_source_checkout_available; then
        punchi_error "Install/update actions require the source checkout."
        punchi_info "Run this menu from the cloned repository."
        return 1
    fi
    punchi_require_kde_environment 'install' || return 1

    punchi_phase_dependencies 1 "$total" || return 1
    punchi_phase_build 2 "$total" || return 1

    punchi_ui_render_phase_started 3 "$total" 'Install'
    if ! punchi_install_local; then
        punchi_ui_render_phase 3 "$total" error 'Install' 'Failed'
        punchi_error "Installation failed. Review the output above or the failure log."
        return 1
    fi
    punchi_ui_render_phase 3 "$total" success 'Install' 'Completed'

    if (( PUNCHI_START_AFTER == 1 )); then
        punchi_start_installed_or_checkout
    else
        punchi_info "Installation finished. Use \"Start the dock\" when you want to open it."
    fi
    return 0
}

punchi_action_build() {
    local total=2

    if ! punchi_source_checkout_available; then
        punchi_error "Build actions require the source checkout."
        return 1
    fi

    punchi_phase_dependencies 1 "$total" || return 1
    punchi_phase_build 2 "$total" || return 1

    if (( PUNCHI_START_AFTER == 1 )); then
        local status=0
        punchi_info "Starting the source checkout from $punchi_project_root"
        punchi_run_dock "$punchi_project_root/scripts-user/start.sh" || status=$?
        punchi_report_dock_exit "$status"
        return "$status"
    fi
    punchi_info "Build finished. Use \"Start the dock\" when you want to open it."
    return 0
}

punchi_action_dependencies() {
    local offer="${1:-1}"
    punchi_dependency_check "$offer" 1
}

punchi_choose_cleanup_mode() {
    local choice=""

    [[ -t 0 ]] || return 0
    [[ "${PUNCHI_ASSUME_YES:-0}" != "1" ]] || return 0
    printf '\n%s\n' 'What else should uninstall remove?'
    printf '%s\n' '  [1] Keep my data: preferences, build output and the source checkout'
    printf '%s\n' '  [2] Remove everything: preferences (including the legacy punchi-shell.json),'
    printf '%s\n' '      build output, runtime lock and window-state registration'
    while true; do
        printf '%s' 'Select an option [1-2]: '
        read -r choice || return 0
        case "${choice:-1}" in
            1) return 0 ;;
            2) PUNCHI_CLEAN_ALL=1; return 0 ;;
            *) punchi_error "Invalid option: $choice" ;;
        esac
    done
}

punchi_action_uninstall() {
    local install_root=""
    install_root="$(punchi_install_root)" || return 1

    punchi_warning "Uninstall will stop this project's checkout and installed copies,"
    punchi_warning "restore owned KWin settings, and remove:"
    printf '  - %s\n' "$install_root"
    local build_dir=""
    build_dir="$(punchi_build_dir_existing)" || build_dir="$(punchi_build_dir)"
    if (( PUNCHI_REMOVE_BUILD == 1 )) && punchi_source_checkout_available; then
        printf '  - %s\n' "$build_dir"
    fi

    punchi_choose_cleanup_mode
    if (( PUNCHI_CLEAN_ALL == 1 )); then
        if ! punchi_confirm 'Remove everything this project created? This cannot be undone. [y/N]: ' n; then
            punchi_info "Uninstall cancelled."
            return 0
        fi
        PUNCHI_REMOVE_BUILD=1
        PUNCHI_REMOVE_SETTINGS=1
    else
        if punchi_source_checkout_available; then
            punchi_info "The source checkout and build output are kept by default."
        else
            punchi_info "Personal preferences are kept by default."
        fi
        if ! punchi_confirm "Continue with uninstall? [y/N]: " n; then
            punchi_info "Uninstall cancelled."
            return 0
        fi

        if (( PUNCHI_REMOVE_BUILD == 0 )) && punchi_source_checkout_available \
            && [[ -d "$build_dir" ]] \
            && [[ -t 0 ]] && [[ "${PUNCHI_ASSUME_YES:-0}" != "1" ]]; then
            if punchi_confirm "Also remove the source checkout's build output ($build_dir)? [y/N]: " n; then
                PUNCHI_REMOVE_BUILD=1
            fi
        fi
    fi

    local status=0
    punchi_uninstall_local "$PUNCHI_REMOVE_BUILD" "$PUNCHI_REMOVE_SETTINGS" "$PUNCHI_CLEAN_ALL" || status=1

    if (( PUNCHI_CLEAN_ALL == 0 )) && (( PUNCHI_REMOVE_SETTINGS == 0 )) && [[ -t 0 ]] \
        && [[ "${PUNCHI_ASSUME_YES:-0}" != "1" ]]; then
        if punchi_confirm "Also delete the current preferences file? [y/N]: " n; then
            punchi_remove_preferences 1 0 || status=1
        fi
    fi
    return "$status"
}

interactive_menu() {
    local choice=""
    while true; do
        show_header
        printf '\n'
        punchi_muted "What would you like to do?"
        printf '\n'
        punchi_muted "Primary actions"
        printf '%s\n' '  [1] Install or update (build and install for this user)'
        printf '%s\n' '  [2] Build or rebuild the source checkout only'
        printf '%s\n' '  [3] Try it without installing (build, then run from this checkout)'
        printf '%s\n' '  [4] Start the dock (needs [1], [2] or [3] first)'
        printf '\n'
        punchi_muted "Maintenance"
        printf '%s\n' '  [5] Check runtime and build dependencies'
        printf '%s\n' '  [6] Check for updates'
        printf '%s\n' '  [7] Uninstall'
        printf '\n'
        punchi_muted "Help"
        printf '%s\n' '  [8] Instructions and README'
        printf '%s\n' '  [9] Command-line options'
        printf '%s\n' '  [10] Exit'
        printf '\n'
        printf '%s' 'Select an option [1-10]: '
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
                punchi_action_try || true
                punchi_pause
                ;;
            4)
                punchi_start_installed_or_checkout || true
                punchi_pause
                ;;
            5)
                punchi_action_dependencies 1 || true
                punchi_pause
                ;;
            6)
                punchi_check_updates prompt || true
                punchi_pause
                ;;
            7)
                punchi_action_uninstall || true
                punchi_pause
                ;;
            8)
                show_quick_instructions
                punchi_pause
                ;;
            9)
                show_help
                punchi_pause
                ;;
            10|q|Q)
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

# A pull replaces the libraries this process sourced at startup, so the next
# action runs in a fresh process instead of the code loaded before the update.
punchi_reload_after_update() {
    local next_action="${1:-menu}"
    local script="$punchi_setup_script_dir/setup.sh"
    if [[ ! -f "$script" ]]; then
        punchi_warning "Restart the assistant before building the updated checkout."
        return 1
    fi
    local -a args=()
    (( PUNCHI_ASSUME_YES == 1 )) && args+=(-y)
    (( ${NO_COLOR:-0} == 1 )) && args+=(--no-color)
    [[ -n "${PUNCHI_INSTALL_PREFIX:-}" ]] && args+=(--prefix "$PUNCHI_INSTALL_PREFIX")
    [[ "$next_action" != "menu" ]] && args+=("--$next_action")
    punchi_info "Restarting the assistant so the updated checkout is the code that runs."
    punchi_setup_cleanup
    exec "$script" "${args[@]}"
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
            --try|--test) set_action try; shift ;;
            --check-deps) set_action check_deps; shift ;;
            --check-updates|--updates) set_action check_updates; shift ;;
            --uninstall) set_action uninstall; shift ;;
            --instructions) set_action instructions; shift ;;
            --start) PUNCHI_START_AFTER=1; shift ;;
            --remove-settings) PUNCHI_REMOVE_SETTINGS=1; shift ;;
            --remove-build) PUNCHI_REMOVE_BUILD=1; shift ;;
            --keep-build) PUNCHI_REMOVE_BUILD=0; shift ;;
            --install-missing) PUNCHI_INSTALL_MISSING=1; shift ;;
            --pull) PUNCHI_PULL=1; shift ;;
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
    if (( PUNCHI_PULL == 1 )) && [[ "$PUNCHI_ACTION" != "check_updates" ]]; then
        punchi_die "--pull requires --check-updates."
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
        try) punchi_action_try ;;
        check_deps) punchi_action_dependencies "$PUNCHI_INSTALL_MISSING" ;;
        check_updates)
            if (( PUNCHI_PULL == 1 )); then
                punchi_check_updates pull
            else
                punchi_check_updates check
            fi
            ;;
        uninstall) punchi_action_uninstall ;;
        instructions) show_quick_instructions ;;
        start) punchi_start_installed_or_checkout ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
