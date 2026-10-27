#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Build, user-local installation and uninstallation helpers.

punchi_install_dir="${BASH_SOURCE[0]%/*}"
if [[ "$punchi_install_dir" == "${BASH_SOURCE[0]}" ]]; then
    punchi_install_dir='.'
fi
if ! declare -F punchi_job_count >/dev/null 2>&1; then
    # shellcheck source=setup-resources.sh
    source "$punchi_install_dir/setup-resources.sh"
fi
if ! declare -F punchi_run_step >/dev/null 2>&1; then
    # shellcheck source=setup-progress.sh
    source "$punchi_install_dir/setup-progress.sh"
fi
unset punchi_install_dir

# Runs inside the progress runner, so it reports its own phase transitions and
# leaves the exit status of the failing command to the caller.
punchi_build_worker() {
    local build_dir="${1:?build directory is required}"
    local jobs="${2:?job count is required}"

    punchi_progress_update 8 configure
    if ! cmake -S "$punchi_project_root" -B "$build_dir" -G Ninja; then
        return 1
    fi
    punchi_progress_update 45 build
    cmake --build "$build_dir" --parallel "$jobs"
}

punchi_build_checkout() {
    punchi_source_checkout_available \
        || punchi_die "Build and install actions require the source checkout."

    local build_dir="$punchi_project_root/build"
    if [[ -L "$build_dir" ]]; then
        punchi_die "Refusing a symbolic link as the build directory: $build_dir"
    fi

    local jobs=""
    local transcript=""
    local step_status=0
    jobs="$(punchi_job_count)"
    transcript="$(mktemp "${TMPDIR:-/tmp}/punchi-build.XXXXXX")"
    punchi_register_cleanup "$transcript"

    punchi_run_step "$transcript" punchi_build_worker "$build_dir" "$jobs" \
        || step_status=$?
    if (( step_status != 0 )); then
        # An interrupted build is not a defect worth a permanent failure log.
        if (( step_status != 130 && step_status != 143 )); then
            punchi_write_failure_log "build" "$transcript" || true
            punchi_error "Build failed. Review the output above or the failure log."
        else
            punchi_warning "Build cancelled."
            return 1
        fi
        return 1
    fi

    if ! punchi_build_artifacts_ready; then
        punchi_write_failure_log "build" "$transcript" || true
        punchi_error "The build finished without the expected native artifacts."
        return 1
    fi
    rm -f -- "$transcript"
    punchi_success "Native components and QML plugin built in $build_dir."
}

punchi_copy_runtime_tree() {
    local staging="${1:?staging directory is required}"
    local directory=""
    local file=""
    local relative=""

    cp -a -- "$punchi_project_root/shell.qml" "$staging/"
    for directory in modules components services config assets; do
        cp -a -- "$punchi_project_root/$directory" "$staging/"
    done

    mkdir -p "$staging/adapters/kde"
    while IFS= read -r file; do
        relative="${file#"$punchi_project_root"/}"
        mkdir -p "$staging/$(dirname "$relative")"
        cp -a -- "$file" "$staging/$relative"
    done < <(find "$punchi_project_root/adapters/kde" -type f -name '*.qml' -print)

    mkdir -p "$staging/build/qml"
    cp -a -- "$punchi_project_root/build/qml/Punchi" "$staging/build/qml/"
    cp -a -- "$punchi_project_root/build/libpunchikde.so" "$staging/build/"
    cp -a -- "$punchi_project_root/build/punchi-window-state" "$staging/build/"
    cp -a -- "$punchi_project_root/scripts-user" "$staging/"
    for file in README.md LICENSE NOTICE.md CHANGELOG.md CONTRIBUTING.md SECURITY.md; do
        [[ -f "$punchi_project_root/$file" ]] \
            && cp -a -- "$punchi_project_root/$file" "$staging/"
    done
}

punchi_write_install_manifest() {
    local staging="${1:?staging directory is required}"
    local manifest=""
    local temporary=""

    manifest="$staging/$(punchi_install_manifest_name)"
    temporary="$(mktemp "${TMPDIR:-/tmp}/punchi-install-manifest.XXXXXX")"
    (
        cd "$staging"
        find . \( -type f -o -type l \) -print \
            | sed 's|^\./||' \
            | sort
    ) > "$temporary"
    mv -- "$temporary" "$manifest"
}

punchi_write_launcher() {
    local install_root="${1:?install root is required}"
    local launcher=""
    local applications_dir=""
    local exec_path="$install_root/scripts-user/launcher.sh"
    local stop_path="$install_root/scripts-user/restore-kde.sh"
    local settings_path="$install_root/scripts-user/settings.sh"
    local temporary=""

    launcher="$(punchi_launcher_path)"
    applications_dir="$(dirname "$launcher")"
    if ! mkdir -p "$applications_dir"; then
        return 1
    fi
    temporary="${launcher}.tmp.$$"
    if ! {
        printf '%s\n' '[Desktop Entry]'
        printf '%s\n' 'Type=Application'
        printf '%s\n' 'Version=1.0'
        printf '%s\n' 'Name=Punchi Dock Quickshell'
        printf '%s\n' 'Comment=Animated dock for KDE Plasma built with Quickshell'
        printf 'Exec=%s\n' "$(punchi_desktop_exec_quote "$exec_path")"
        printf 'TryExec=%s\n' "$exec_path"
        printf 'Icon=%s\n' "$install_root/assets/icons/punchi-dock-quickshell.svg"
        printf '%s\n' 'Terminal=false'
        printf '%s\n' 'Categories=Utility;'
        printf '%s\n' 'StartupNotify=false'
        printf '%s\n' 'Actions=Stop;Settings;'
        printf 'X-Punchi-Install-Root=%s\n' "$install_root"
        printf '\n%s\n' '[Desktop Action Stop]'
        printf '%s\n' 'Name=Stop Punchi Dock Quickshell'
        printf 'Exec=%s\n' "$(punchi_desktop_exec_quote "$stop_path")"
        printf '\n%s\n' '[Desktop Action Settings]'
        printf '%s\n' 'Name=Open Dock Settings'
        printf 'Exec=%s\n' "$(punchi_desktop_exec_quote "$settings_path")"
    } > "$temporary"; then
        rm -f -- "$temporary"
        return 1
    fi
    if ! chmod 0644 "$temporary"; then
        rm -f -- "$temporary"
        return 1
    fi
    if ! mv -- "$temporary" "$launcher"; then
        rm -f -- "$temporary"
        return 1
    fi

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$applications_dir" >/dev/null 2>&1 || true
    fi
    punchi_success "Application-menu launcher written to $launcher."
}

punchi_stage_worker() {
    local staging="${1:?staging directory is required}"

    punchi_progress_update 15 stage
    punchi_copy_runtime_tree "$staging"
}

punchi_install_local() {
    punchi_source_checkout_available \
        || punchi_die "User-local install requires the source checkout."
    punchi_build_artifacts_ready \
        || punchi_die "Build the project before installing it."

    local install_root=""
    local parent=""
    local staging=""
    local old_install=""
    local marker=""
    local version=""

    install_root="$(punchi_install_root)" || return 1
    parent="$(dirname "$install_root")"
    marker="$(punchi_install_marker_name)"
    version="$(punchi_project_version)"

    mkdir -p "$parent"
    if [[ -L "$install_root" ]]; then
        punchi_die "Refusing to replace a symbolic link: $install_root"
    fi
    if [[ -e "$install_root" && ! -f "$install_root/$marker" ]]; then
        punchi_die "Refusing to replace an unmarked directory: $install_root"
    fi

    staging="$(mktemp -d "$parent/.punchi-dock-quickshell.staging.XXXXXX")"
    punchi_register_cleanup "$staging"

    local staging_log=""
    local stage_status=0
    staging_log="$(mktemp "${TMPDIR:-/tmp}/punchi-stage.XXXXXX")"
    punchi_register_cleanup "$staging_log"
    punchi_run_step "$staging_log" punchi_stage_worker "$staging" \
        || stage_status=$?
    if (( stage_status != 0 )); then
        rm -rf -- "$staging"
        if (( stage_status != 130 && stage_status != 143 )); then
            punchi_write_failure_log "install" "$staging_log" || true
            punchi_error "Staging the user-local installation failed."
        else
            punchi_warning "Staging cancelled."
        fi
        return 1
    fi
    rm -f -- "$staging_log"
    if [[ ! -f "$staging/build/libpunchikde.so" ]]; then
        rm -rf -- "$staging"
        punchi_die "The staged installation is missing the native QML library."
    fi
    {
        printf '%s\n' 'format=1'
        printf '%s\n' 'name=punchi-dock-quickshell'
        printf 'version=%s\n' "$version"
    } > "$staging/$marker"
    printf '%s\n' "$version" > "$staging/$(punchi_install_version_name)"
    punchi_write_install_manifest "$staging"

    if [[ -e "$install_root" ]]; then
        old_install="$parent/.punchi-dock-quickshell.old.$$"
        mv -- "$install_root" "$old_install"
    fi
    if ! mv -- "$staging" "$install_root"; then
        if [[ -n "$old_install" ]]; then
            mv -- "$old_install" "$install_root"
        fi
        punchi_die "Could not move the staged installation into place."
    fi

    if ! punchi_write_launcher "$install_root"; then
        punchi_error "Could not write the application-menu launcher."
        punchi_write_failure_log "install" "" || true
        rm -rf -- "$install_root"
        if [[ -n "$old_install" ]]; then
            if mv -- "$old_install" "$install_root"; then
                punchi_warning "The previous installation was restored."
            else
                punchi_error "The previous installation could not be restored: $old_install"
            fi
        fi
        return 1
    fi
    if [[ -n "$old_install" ]]; then
        rm -rf -- "$old_install"
    fi

    punchi_success "Installed Punchi Dock Quickshell $version for this user."
    printf '  Install root: %s\n' "$install_root"
    printf '  Start with:   %s/scripts-user/start.sh\n' "$install_root"
    printf '  Stop with:    %s/scripts-user/restore-kde.sh\n' "$install_root"
}

punchi_restore_path() {
    local path="${1:?configuration path is required}"
    local restore="$path/scripts-user/restore-kde.sh"

    if [[ -f "$restore" ]]; then
        punchi_info "Stopping the configuration at $path and restoring owned KDE settings..."
        if [[ -x "$restore" ]]; then
            "$restore" || return 1
        else
            bash "$restore" || return 1
        fi
    elif punchi_running_path "$path"; then
        punchi_error "No restore script was found for the running configuration: $path"
        return 1
    fi
}

punchi_stop_owned_configurations() {
    local install_root="${1:?install root is required}"
    local restore_status=0

    punchi_restore_path "$install_root" || restore_status=1
    if [[ "$punchi_project_root" != "$install_root" ]]; then
        punchi_restore_path "$punchi_project_root" || restore_status=1
    fi

    if (( restore_status != 0 )); then
        punchi_error "KDE settings could not be restored. Uninstallation was stopped."
        punchi_error "Fix the reported restore error and run the uninstall action again."
        return 1
    fi
}

punchi_remove_launcher() {
    local install_root="${1:?install root is required}"
    local launcher=""
    local recorded=""

    launcher="$(punchi_launcher_path)"
    [[ -e "$launcher" || -L "$launcher" ]] || return 0
    recorded="$(sed -n 's/^X-Punchi-Install-Root=//p' "$launcher" 2>/dev/null | head -n 1)"
    if [[ "$recorded" != "$install_root" ]]; then
        punchi_warning "The launcher does not belong to this install root and was kept: $launcher"
        return 0
    fi
    rm -f -- "$launcher"
    punchi_success "Removed the application-menu launcher."
}

punchi_remove_autostart() {
    local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
    local entry="$config_home/autostart/punchi-dock-quickshell.desktop"

    [[ -e "$entry" || -L "$entry" ]] || return 0
    if ! grep -qx 'X-Punchi-Dock-Quickshell-Owned=true' "$entry" 2>/dev/null; then
        punchi_warning "The autostart entry does not belong to Punchi Dock Quickshell and was kept: $entry"
        return 0
    fi
    rm -f -- "$entry"
    punchi_success "Removed the Punchi-owned autostart entry."
}

punchi_window_state_backend() {
    local install_root=""
    local root=""
    local candidate=""

    install_root="$(punchi_install_root 2>/dev/null || true)"
    for root in "$punchi_project_root" "$install_root"; do
        [[ -n "$root" ]] || continue
        for candidate in \
            "$root/build/punchi-window-state" \
            "$root/../../libexec/punchi-dock-quickshell/punchi-window-state" \
            "$root/../../lib/punchi-dock-quickshell/punchi-window-state"; do
            if [[ -x "$candidate" ]]; then
                printf '%s\n' "$candidate"
                return 0
            fi
        done
    done
    return 1
}

# The backend unregisters its own entry, but it may already be gone when build
# output or the install root is removed first. A registration this project
# wrote is still safe to delete on its own.
punchi_remove_window_state_registration() {
    local registration="${XDG_DATA_HOME:-$HOME/.local/share}/applications/org.punchi.Shell.WindowState.desktop"
    local backend=""

    [[ -e "$registration" || -L "$registration" ]] || return 0
    if backend="$(punchi_window_state_backend)"; then
        "$backend" --unregister >/dev/null 2>&1 || true
    fi
    if [[ ! -e "$registration" && ! -L "$registration" ]]; then
        punchi_success "Removed the window-state registration."
        return 0
    fi
    if [[ -L "$registration" ]] \
        || ! grep -qE '^Name=(Punchi Dock Quickshell|Punchi Shell) Window State$' "$registration" 2>/dev/null \
        || ! grep -qx 'X-KDE-Wayland-Interfaces=org_kde_plasma_window_management' "$registration" 2>/dev/null; then
        punchi_warning "The window-state registration does not belong to Punchi Dock Quickshell and was kept: $registration"
        return 0
    fi
    rm -f -- "$registration"
    if command -v kbuildsycoca6 >/dev/null 2>&1; then
        kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
    fi
    punchi_success "Removed the window-state registration."
}

# The instance record is owned by start.sh. It is only removed when it names a
# configuration this action owns, so a running copy in another checkout keeps
# its lock.
punchi_remove_runtime_instance() {
    local directory=""
    local recorded=""
    local root=""
    local matched=0

    directory="$(punchi_runtime_lock_dir)"
    [[ -d "$directory" && ! -L "$directory" ]] || return 0
    if [[ -r "$directory/instance.path" ]]; then
        IFS= read -r recorded < "$directory/instance.path" || true
    fi
    for root in "$@"; do
        [[ -n "$root" ]] || continue
        if [[ "$recorded" == "$root" ]]; then
            matched=1
            break
        fi
    done
    if (( matched == 0 )); then
        return 0
    fi
    rm -f -- "$directory/instance.lock" "$directory/instance.path"
    rmdir -- "$directory" 2>/dev/null || true
    punchi_success "Removed the runtime lock."
}

punchi_remove_installed_files() {
    local install_root="${1:?install root is required}"
    local marker=""
    local manifest=""
    local line=""
    local target=""
    local resolved=""
    local leftover=0

    if [[ -L "$install_root" ]]; then
        punchi_die "Refusing to uninstall a symbolic link: $install_root"
    fi
    if [[ ! -e "$install_root" ]]; then
        punchi_info "No user-local installation was found at $install_root."
        return 0
    fi

    marker="$install_root/$(punchi_install_marker_name)"
    manifest="$install_root/$(punchi_install_manifest_name)"
    if [[ ! -f "$marker" ]]; then
        punchi_die "Refusing to remove an unmarked directory: $install_root"
    fi

    if [[ -f "$manifest" ]]; then
        while IFS= read -r line; do
            [[ -n "$line" && "$line" != /* ]] || continue
            case "$line" in
                ..|../*|*/../*|*/..) continue ;;
            esac
            target="$install_root/$line"
            resolved="$(realpath -m -- "$target" 2>/dev/null || true)"
            case "$resolved" in
                "$install_root"/*) rm -f -- "$target" ;;
                *) punchi_warning "Skipped an unexpected manifest path: $line" ;;
            esac
        done < "$manifest"
    else
        punchi_warning "The install manifest is missing; only the launcher will be removed."
        leftover=1
    fi

    rm -f -- "$manifest" "$marker"
    find "$install_root" -depth -type d -empty -delete 2>/dev/null || true

    if [[ -e "$install_root" ]]; then
        punchi_warning "Some files were not listed in the manifest and were kept:"
        find "$install_root" -maxdepth 3 -type f -print 2>/dev/null | head -n 20
        leftover=1
    else
        punchi_success "Removed the user-local installation."
    fi
    return "$leftover"
}

punchi_remove_build_output() {
    local build_dir="$punchi_project_root/build"
    local cached_source=""

    if [[ ! -e "$build_dir" && ! -L "$build_dir" ]]; then
        punchi_info "No build output was found in $build_dir."
        return 0
    fi
    if [[ -L "$build_dir" ]]; then
        punchi_die "Refusing to remove a symbolic link: $build_dir"
    fi
    if [[ -f "$build_dir/CMakeCache.txt" ]]; then
        cached_source="$(sed -n 's/^CMAKE_HOME_DIRECTORY:INTERNAL=//p' \
            "$build_dir/CMakeCache.txt" | head -n 1)"
        if [[ -n "$cached_source" && "$cached_source" != "$punchi_project_root" ]]; then
            punchi_die "Refusing to remove build output from another source tree: $build_dir"
        fi
    fi
    rm -rf -- "$build_dir"
    punchi_success "Removed build output: $build_dir"
    punchi_info "Run the Build action or ./scripts-user/setup.sh --build to recreate it."
}

punchi_remove_preferences() {
    local requested="${1:-0}"
    local prompt="${2:-1}"
    local remove_legacy="${3:-0}"
    local config=""
    local legacy=""

    config="$(punchi_config_path)"
    legacy="$(punchi_legacy_config_path)"

    if (( requested == 0 )); then
        punchi_info "Preferences kept: $config"
        if [[ -e "$legacy" || -L "$legacy" ]]; then
            punchi_info "Legacy backup kept: $legacy"
        fi
        return 0
    fi

    if [[ ! -e "$config" && ! -L "$config" ]]; then
        punchi_info "No current preferences file was found at $config."
    elif [[ "${PUNCHI_ASSUME_YES:-0}" != "1" ]] && (( prompt == 1 )); then
        if ! punchi_confirm "Delete $config? This cannot be undone. [y/N]: " n; then
            punchi_info "Preferences kept: $config"
            return 0
        fi
    fi
    if [[ -e "$config" || -L "$config" ]]; then
        rm -f -- "$config"
        punchi_success "Removed preferences: $config"
    fi
    if [[ ! -e "$legacy" && ! -L "$legacy" ]]; then
        return 0
    fi
    if (( remove_legacy == 0 )); then
        punchi_info "Legacy backup kept: $legacy"
        return 0
    fi
    rm -f -- "$legacy"
    punchi_success "Removed the legacy preferences: $legacy"
}

punchi_trial_cleanup() {
    local profile="${1:?trial profile is required}"
    local status=0

    if punchi_running_path "$punchi_project_root"; then
        punchi_warning "Punchi Dock Quickshell is already running from:"
        printf '  %s\n' "$punchi_project_root"
        punchi_info "Stop it first:"
        printf '  %s/scripts-user/restore-kde.sh\n' "$punchi_project_root"
        punchi_info "Trial files kept: $profile"
        return 1
    fi
    if ! punchi_confirm 'Remove what the trial created? It deletes build output (rebuild with Build or Try),
trial preferences, the window-state registration and the runtime lock.
Your installed dock and its settings stay untouched. [Y/n]: ' y; then
        punchi_info "Trial files kept: $profile"
        return 0
    fi
    punchi_remove_window_state_registration || status=1
    punchi_remove_build_output || status=1
    case "$profile" in
        */punchi-dock-quickshell-*/trial-profile) ;;
        *)
            punchi_warning "Refusing to remove an unexpected trial path: $profile"
            return 1
            ;;
    esac
    if [[ -L "$profile" ]]; then
        punchi_warning "Refusing to remove a symbolic link: $profile"
        return 1
    fi
    rm -rf -- "$profile"
    punchi_success "Removed the trial profile."
    punchi_remove_runtime_instance "$punchi_project_root" || status=1
    return "$status"
}

punchi_uninstall_local() {
    local remove_build="${1:-0}"
    local remove_settings="${2:-0}"
    local remove_all="${3:-0}"
    local install_root=""
    local state_record=""

    install_root="$(punchi_install_root)" || return 1
    punchi_heading "Uninstall"
    printf 'Install root: %s\n' "$install_root"
    printf 'Source root:  %s\n' "$punchi_project_root"

    punchi_stop_owned_configurations "$install_root" || return 1
    punchi_remove_window_state_registration
    punchi_remove_runtime_instance "$punchi_project_root" "$install_root"
    punchi_remove_launcher "$install_root"
    punchi_remove_autostart

    local files_status=0
    punchi_remove_installed_files "$install_root" || files_status=1

    if punchi_source_checkout_available; then
        if (( remove_build == 1 )); then
            punchi_remove_build_output || files_status=1
        else
            punchi_info "Build output kept: $punchi_project_root/build"
        fi
    else
        punchi_info "The installed runtime includes its build artifacts."
    fi

    punchi_remove_preferences "$remove_settings" 1 "$remove_all"

    state_record="${XDG_STATE_HOME:-$HOME/.local/state}/punchi-dock-quickshell/owned-settings.json"
    if [[ -e "$state_record" || -L "$state_record" ]]; then
        punchi_warning "KWin recovery record kept for a later restore: $state_record"
    fi

    punchi_info "The source checkout itself was not removed."
    return "$files_status"
}
