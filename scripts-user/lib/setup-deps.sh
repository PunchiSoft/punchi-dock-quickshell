#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Dependency reporting for the user setup assistant.

punchi_deps_dir="${BASH_SOURCE[0]%/*}"
if [[ "$punchi_deps_dir" == "${BASH_SOURCE[0]}" ]]; then
    punchi_deps_dir='.'
fi
if ! declare -F punchi_run_report_step >/dev/null 2>&1; then
    # shellcheck source=setup-progress.sh
    source "$punchi_deps_dir/setup-progress.sh"
fi
unset punchi_deps_dir

punchi_fedora_runtime_packages() {
    printf '%s\n' \
        quickshell \
        kf6-kirigami \
        kf6-kirigami-addons \
        kf6-qqc2-desktop-style \
        kf6-ksvg \
        kf6-kservice \
        plasma-workspace \
        plasma-activities \
        plasma-activities-stats
}

punchi_fedora_build_packages() {
    printf '%s\n' \
        cmake \
        ninja-build \
        gcc-c++ \
        extra-cmake-modules \
        qt6-qtbase-devel \
        qt6-qtdeclarative-devel \
        qt6-qttools-devel \
        kf6-kio-devel \
        kf6-kservice-devel \
        kf6-kcoreaddons-devel \
        kf6-kconfig-devel \
        kf6-kwindowsystem-devel \
        plasma-activities-devel \
        plasma-activities-stats-devel \
        wayland-devel
}

punchi_fedora_validation_packages() {
    printf '%s\n' \
        python3 \
        python3-dbus \
        python3-gobject \
        dbus-daemon \
        desktop-file-utils
}

punchi_debian_runtime_packages() {
    printf '%s\n' \
        quickshell \
        qml6-module-org-kde-kirigami \
        qml6-module-org-kde-desktop \
        qml6-module-org-kde-ksvg \
        qml6-module-org-kde-kirigamiaddons-components \
        libkf6service-bin \
        plasma-workspace \
        libplasmaactivities6 \
        libplasmaactivitiesstats1
}

punchi_debian_build_packages() {
    printf '%s\n' \
        cmake \
        ninja-build \
        g++ \
        extra-cmake-modules \
        qt6-base-dev \
        qt6-declarative-dev \
        qt6-tools-dev \
        qt6-tools-dev-tools \
        libkf6kio-dev \
        libkf6service-dev \
        libkf6coreaddons-dev \
        libkf6config-dev \
        libkf6windowsystem-dev \
        libplasmaactivities-dev \
        libplasmaactivitiesstats-dev \
        libwayland-dev \
        libwayland-bin \
        wayland-protocols
}

punchi_debian_validation_packages() {
    printf '%s\n' \
        python3 \
        python3-dbus \
        python3-gi \
        dbus \
        desktop-file-utils
}

punchi_arch_runtime_packages() {
    printf '%s\n' \
        quickshell \
        kirigami \
        kirigami-addons \
        qqc2-desktop-style \
        ksvg \
        kservice \
        plasma-workspace \
        plasma-activities \
        plasma-activities-stats
}

punchi_arch_build_packages() {
    printf '%s\n' \
        base-devel \
        cmake \
        ninja \
        extra-cmake-modules \
        qt6-base \
        qt6-declarative \
        qt6-tools \
        kio \
        kservice \
        kcoreaddons \
        kconfig \
        kwindowsystem \
        plasma-activities \
        plasma-activities-stats \
        wayland \
        wayland-protocols
}

punchi_arch_validation_packages() {
    printf '%s\n' \
        python \
        python-dbus \
        python-gobject \
        dbus \
        desktop-file-utils
}

punchi_package_group() {
    local family="${1:?distribution family is required}"
    local group="${2:?package group is required}"
    case "$family:$group" in
        fedora:runtime) punchi_fedora_runtime_packages ;;
        fedora:build) punchi_fedora_build_packages ;;
        fedora:validation) punchi_fedora_validation_packages ;;
        debian:runtime) punchi_debian_runtime_packages ;;
        debian:build) punchi_debian_build_packages ;;
        debian:validation) punchi_debian_validation_packages ;;
        arch:runtime) punchi_arch_runtime_packages ;;
        arch:build) punchi_arch_build_packages ;;
        arch:validation) punchi_arch_validation_packages ;;
        *) return 1 ;;
    esac
}

punchi_package_installed() {
    local package="${1:?package is required}"
    local family="${2:-}"
    if [[ "$package" == "quickshell" ]] && command -v qs >/dev/null 2>&1; then
        return 0
    fi
    case "$family" in
        fedora)
            command -v rpm >/dev/null 2>&1 || return 2
            rpm -q --quiet "$package" >/dev/null 2>&1
            ;;
        debian)
            command -v dpkg-query >/dev/null 2>&1 || return 2
            dpkg-query -W -f='${Status}' "$package" 2>/dev/null \
                | grep -qx 'install ok installed'
            ;;
        arch)
            command -v pacman >/dev/null 2>&1 || return 2
            pacman -Qq "$package" >/dev/null 2>&1 \
                || pacman -Qg "$package" >/dev/null 2>&1
            ;;
        *) return 2 ;;
    esac
}

punchi_missing_packages() {
    local group="${1:?package group is required}"
    local family="${2:?distribution family is required}"
    local package=""
    while IFS= read -r package; do
        [[ -n "$package" ]] || continue
        if ! punchi_package_installed "$package" "$family"; then
            printf '%s\n' "$package"
        fi
    done < <(punchi_package_group "$family" "$group")
}

# Debian stable does not carry every runtime dependency, so the setup can add
# the matching backports suite after an explicit confirmation.
punchi_debian_backports_suite() {
    local codename=""
    [[ "$(punchi_distro_id)" == "debian" ]] || return 1
    codename="$(punchi_os_release_value VERSION_CODENAME || true)"
    [[ "$codename" =~ ^[a-z0-9-]+$ ]] || return 1
    printf '%s-backports\n' "$codename"
}

punchi_debian_package_available() {
    local package="${1:?package is required}"
    local candidate=""
    command -v apt-cache >/dev/null 2>&1 || return 2
    # The field labels follow the locale, so keep apt-cache in C.
    candidate="$(LC_ALL=C apt-cache policy "$package" 2>/dev/null \
        | sed -n 's/^  Candidate: //p' | head -n 1)" || candidate=""
    [[ -n "$candidate" && "$candidate" != "(none)" ]]
}

# Kept as a function so the setup tests can point it at a temporary directory.
punchi_apt_config_dir() {
    printf '%s\n' /etc/apt
}

punchi_debian_backports_configured() {
    local suite="${1:?suite is required}"
    local config_dir=""
    local file=""
    config_dir="$(punchi_apt_config_dir)"
    for file in "$config_dir/sources.list" "$config_dir"/sources.list.d/*; do
        [[ -f "$file" ]] || continue
        if grep -qE "(^|[[:space:]])${suite}([[:space:]]|$)" "$file" 2>/dev/null; then
            return 0
        fi
    done
    return 1
}

punchi_debian_enable_backports() {
    local suite="${1:?suite is required}"
    local config_dir=""
    local file=""
    local line=""
    config_dir="$(punchi_apt_config_dir)"
    file="$config_dir/sources.list.d/debian-backports.list"
    if ! punchi_debian_backports_configured "$suite"; then
        line="deb http://deb.debian.org/debian $suite main"
        if [[ -f "$file" ]]; then
            # Keep an existing file that belongs to the user instead of
            # replacing it.
            printf '\n%s\n' "$line" | sudo tee -a "$file" >/dev/null || return 1
        else
            printf '%s\n' "$line" | sudo tee "$file" >/dev/null || return 1
        fi
    fi
    # Refresh even when the suite was already configured: the candidate may be
    # missing only because the package lists predate it.
    sudo apt-get update || return 1
}

punchi_qt_bin_directories() {
    local -a directories=()
    local directory=""
    local probe=""
    if [[ -n "${PUNCHI_QT_BIN_DIRS:-}" ]]; then
        IFS=':' read -r -a directories <<<"${PUNCHI_QT_BIN_DIRS}"
    fi
    directories+=(
        /usr/lib/qt6/bin
        /usr/lib64/qt6/bin
        /usr/lib/x86_64-linux-gnu/qt6/bin
        /usr/lib/aarch64-linux-gnu/qt6/bin
    )
    for probe in qtpaths6 qtpaths qmake6 qmake; do
        command -v "$probe" >/dev/null 2>&1 || continue
        directory="$("$probe" --query QT_INSTALL_BINS 2>/dev/null || true)"
        if [[ -z "$directory" ]]; then
            directory="$("$probe" -query QT_INSTALL_BINS 2>/dev/null || true)"
        fi
        if [[ -n "$directory" && -d "$directory" ]]; then
            directories+=("$directory")
        fi
        break
    done
    printf '%s\n' "${directories[@]}"
}

punchi_resolve_command() {
    local name="${1:?command name is required}"
    local candidate=""
    local directory=""
    local -a candidates=()
    case "$name" in
        c++) candidates=(c++ g++ clang++) ;;
        qtpaths6) candidates=(qtpaths6 qtpaths6-qt6 qtpaths) ;;
        qmllint) candidates=(qmllint qmllint6) ;;
        qmltestrunner) candidates=(qmltestrunner qmltestrunner6) ;;
        *) candidates=("$name") ;;
    esac
    for candidate in "${candidates[@]}"; do
        if command -v "$candidate" >/dev/null 2>&1; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    case "$name" in
        qtpaths6|qmllint|qmltestrunner)
            while IFS= read -r directory; do
                [[ -n "$directory" ]] || continue
                if [[ -x "$directory/$name" ]]; then
                    printf '%s\n' "$directory/$name"
                    return 0
                fi
            done < <(punchi_qt_bin_directories)
            ;;
    esac
    return 1
}

punchi_command_group() {
    local group="${1:?command group is required}"
    case "$group" in
        runtime) printf '%s\n' qs kbuildsycoca6 plasmashell kwin_wayland ;;
        build) printf '%s\n' cmake ninja c++ pkg-config wayland-scanner qtpaths6 ;;
        validation) printf '%s\n' qmllint qmltestrunner python3 dbus-run-session update-desktop-database ;;
        *) return 1 ;;
    esac
}

punchi_command_group_titles() {
    case "${1:?command group is required}" in
        runtime) printf '%s\n' 'Runtime' 'Runtime commands' 'Required commands' ;;
        build) printf '%s\n' 'Build' 'Build commands' 'Required commands' ;;
        validation) printf '%s\n' 'Validation tools' 'Validation tools' 'Project checks and tests' ;;
        *) return 1 ;;
    esac
}

punchi_report_value() {
    printf '  %-24s %s\n' "${1:?report label is required}" "${2:-}"
}

punchi_report_width() {
    # The report is captured in a worker without the terminal, so the progress
    # runner publishes the width it measured while the terminal was attached.
    local width="${PUNCHI_UI_COLUMNS:-${COLUMNS:-}}"
    if [[ ! "$width" =~ ^[0-9]+$ ]] || (( width < 40 )); then
        width="$(tput cols 2>/dev/null || true)"
    fi
    if [[ ! "$width" =~ ^[0-9]+$ ]] || (( width < 40 )); then
        width=80
    fi
    printf '%s\n' "$width"
}

# Fills the terminal width with whole items per row, so the detailed inventory
# stays short without inventing a fixed column width.
punchi_report_cells() {
    (($#)) || return 0
    local -a cells=("$@")
    local cell=""
    local widest=0
    local width=""
    local columns=1
    local index=0
    local line=""
    local total=$#
    for cell in "${cells[@]}"; do
        if (( ${#cell} > widest )); then
            widest=${#cell}
        fi
    done
    if (( widest < 18 )); then
        widest=18
    fi
    width="$(punchi_report_width)"
    columns=$(( (width - 2) / (widest + 2) ))
    if (( columns < 1 )); then
        columns=1
    elif (( columns > 4 )); then
        columns=4
    fi
    for cell in "${cells[@]}"; do
        index=$(( index + 1 ))
        if (( index % columns == 0 )) || (( index == total )); then
            printf '  %s\n' "$line$cell"
            line=""
        else
            printf -v line '%s%-*s  ' "$line" "$widest" "$cell"
        fi
    done
}

punchi_report_command_group() {
    local group="${1:?command group is required}"
    local detail="${2:-1}"
    local required="${3:-0}"
    local -a titles=()
    local -a ready=()
    local -a missing=()
    local -a relocated=()
    local command_name=""
    local resolved=""
    local total=0

    mapfile -t titles < <(punchi_command_group_titles "$group")
    while IFS= read -r command_name; do
        [[ -n "$command_name" ]] || continue
        if ! resolved="$(punchi_resolve_command "$command_name")"; then
            missing+=("$command_name")
            continue
        fi
        ready+=("[ok] $command_name")
        if ! command -v "$command_name" >/dev/null 2>&1; then
            relocated+=("$command_name=$resolved")
        fi
    done < <(punchi_command_group "$group")
    total=$(( ${#ready[@]} + ${#missing[@]} ))

    if (( detail == 0 )); then
        punchi_report_value "${titles[1]}" "${#ready[@]}/$total ready"
        for command_name in "${missing[@]}"; do
            printf '  [missing] %s\n' "$command_name"
        done
    else
        punchi_heading "${titles[0]}"
        punchi_muted "${titles[2]}"
        punchi_report_cells "${ready[@]}"
        for command_name in "${missing[@]}"; do
            printf '  [missing] %s\n' "$command_name"
        done
        if ((${#relocated[@]})); then
            printf '  Found outside PATH: %s\n' "${relocated[*]}"
        fi
    fi

    if (( ${#missing[@]} > 0 && required == 1 )); then
        return 1
    fi
    return 0
}

punchi_report_python_modules() {
    local detail="${1:-1}"
    command -v python3 >/dev/null 2>&1 || return 0
    local module=""
    local -a ready=()
    local -a missing=()
    for module in dbus gi; do
        if python3 -c "import $module" >/dev/null 2>&1; then
            ready+=("[ok] python:$module")
        else
            missing+=("[missing] python:$module")
        fi
    done
    if (( detail == 0 )); then
        punchi_report_value "Python modules" \
            "${#ready[@]}/$(( ${#ready[@]} + ${#missing[@]} )) ready"
        if ((${#missing[@]})); then
            printf '  %s\n' "${missing[@]}"
        fi
    else
        punchi_muted "Python modules"
        punchi_report_cells "${ready[@]}"
        if ((${#missing[@]})); then
            printf '  %s\n' "${missing[@]}"
        fi
    fi
    if ((${#missing[@]})); then
        return 1
    fi
    return 0
}

punchi_dependency_report() {
    local family="${1:?distribution family is required}"
    # detail=1 prints the full inventory; detail=0 prints one summary row per
    # section and only expands what is missing.
    local detail="${2:-1}"
    local status=0
    local validation_status=0
    local separator=', '

    if punchi_ui_terminal_supports_unicode 1; then
        separator=' · '
    fi

    punchi_progress_update 25 dependencies
    punchi_report_command_group runtime "$detail" 1 || status=1

    punchi_progress_update 40 dependencies
    punchi_report_command_group build "$detail" 1 || status=1

    punchi_progress_update 55 dependencies
    punchi_report_command_group validation "$detail" 0 || validation_status=1
    punchi_report_python_modules "$detail" || validation_status=1

    punchi_progress_update 70 dependencies
    if (( detail == 1 )); then
        punchi_heading "KDE Plasma/KWin"
    fi
    if punchi_kde_session_detected; then
        if (( detail == 1 )); then
            punchi_report_cells "[ok] active KDE Plasma/KWin session"
        else
            punchi_report_value "KDE Plasma/KWin" "session detected"
        fi
    else
        if (( detail == 1 )); then
            punchi_report_cells "[warning] no active KDE Plasma/KWin session detected"
        else
            punchi_report_value "KDE Plasma/KWin" "no session detected"
        fi
        punchi_warning "Punchi Dock Quickshell requires KDE Plasma/KWin on Wayland and will not run on other desktops."
    fi

    punchi_progress_update 80 dependencies
    local git_path=""
    if (( detail == 1 )); then
        punchi_heading "Update check"
    fi
    if git_path="$(punchi_resolve_command git)"; then
        if (( detail == 1 )); then
            punchi_report_cells "[ok] git"
            if ! command -v git >/dev/null 2>&1; then
                printf '  Found outside PATH: git=%s\n' "$git_path"
            fi
        else
            punchi_report_value "Update check" "git found"
        fi
    else
        if (( detail == 1 )); then
            printf '  [missing] %-16s\n' git
        else
            punchi_report_value "Update check" "git missing"
        fi
        punchi_info "Optional: needed only by Check for updates."
        punchi_info "Install it yourself with: $(punchi_git_install_hint)"
        punchi_info "The setup script never installs git automatically."
    fi

    local manager=""
    local label=""
    local validated=0
    case "$family" in
        fedora) manager=rpm; label=Fedora; validated=1 ;;
        debian) manager=dpkg-query; label=Debian/Ubuntu; validated=0 ;;
        arch) manager=pacman; label=Arch; validated=0 ;;
    esac
    if [[ -n "$manager" ]] && command -v "$manager" >/dev/null 2>&1; then
        if (( validated == 0 )); then
            punchi_warning "Package names for $label are best-effort and have not been validated by this project."
        fi
        local group=""
        local package=""
        local present=0
        local checked=0
        local missing=0
        local joined=""
        local element=""
        local -a summary=()
        local -a missing_names=()
        for group in runtime build validation; do
            local -a present_names=()
            present=0
            checked=0
            while IFS= read -r package; do
                [[ -n "$package" ]] || continue
                checked=$(( checked + 1 ))
                if punchi_package_installed "$package" "$family"; then
                    present=$(( present + 1 ))
                    present_names+=("[ok] $package")
                else
                    missing_names+=("[missing] $package")
                    missing=1
                    [[ "$group" == "validation" ]] || status=1
                fi
            done < <(punchi_package_group "$family" "$group")
            summary+=("$group $present/$checked")
            if (( detail == 1 )); then
                punchi_muted "$label packages: $group"
                punchi_report_cells "${present_names[@]}"
            fi
        done
        if (( detail == 1 )); then
            if ((${#missing_names[@]})); then
                printf '  %s\n' "${missing_names[@]}"
            fi
            if (( missing == 0 )); then
                punchi_success "All checked $label packages are installed."
            fi
        else
            for element in "${summary[@]}"; do
                if [[ -z "$joined" ]]; then
                    joined="$element"
                else
                    joined="$joined$separator$element"
                fi
            done
            punchi_report_value "$label packages" "$joined"
            if ((${#missing_names[@]})); then
                printf '  %s\n' "${missing_names[@]}"
            fi
        fi
    else
        punchi_information_about_packages
    fi

    if (( validation_status != 0 )); then
        punchi_warning "Some validation tools are missing; the dock can still build and run."
    fi
    return "$status"
}

punchi_information_about_packages() {
    punchi_info "Package-name checks are validated only on Fedora 44."
    punchi_info "Debian/Ubuntu and Arch mappings are best-effort; verify names"
    punchi_info "with your distribution before installing them."
    punchi_info "On other distributions, install the Quickshell, Qt 6, KF6 and"
    punchi_info "Wayland development equivalents, then run this check again."
}

# Runs inside the progress runner: the report stays batched in the log while the
# animation owns the terminal, and the caller replays it afterwards.
punchi_dependency_worker() {
    local family="${1:?distribution family is required}"
    local detail="${2:-1}"

    punchi_progress_update 20 dependencies
    punchi_dependency_report "$family" "$detail"
}

punchi_dependency_check() {
    local offer_install="${1:-0}"
    local detail="${2:-0}"
    local family=""
    family="$(punchi_distro_family "$(punchi_distro_id)" "$(punchi_distro_like)")"

    # The compact report is a phase summary: the phase line already names the
    # step and the setup header already prints the distribution family.
    if (( detail == 1 )); then
        punchi_heading "Dependency check"
        printf 'Distribution: %s (%s)\n' "$(punchi_system_name)" "$family"
        punchi_rule
    fi

    local status=0
    local report_log=""
    report_log="$(mktemp "${TMPDIR:-/tmp}/punchi-dependencies.XXXXXX")"
    punchi_register_cleanup "$report_log"
    punchi_run_report_step "$report_log" punchi_dependency_worker "$family" \
        "$detail" || status=1

    if (( detail == 1 )); then
        punchi_rule
        if (( status == 0 )); then
            punchi_success "Required runtime and build dependencies are present."
        else
            punchi_warning "Required dependencies are missing."
        fi
    elif (( status != 0 )); then
        punchi_warning "Required dependencies are missing."
    fi

    if (( offer_install == 1 )) && [[ "$family" != "unsupported" ]] \
        && (( status != 0 )); then
        punchi_offer_dependency_install "$family" "$status"
        if (( status != 0 )); then
            if (( detail == 1 )); then
                punchi_rule
            fi
            punchi_info "Re-checking dependencies..."
            status=0
            punchi_run_report_step "$report_log" punchi_dependency_worker \
                "$family" "$detail" || status=1
            if (( detail == 1 )); then
                punchi_rule
                if (( status == 0 )); then
                    punchi_success "Required runtime and build dependencies are present."
                else
                    punchi_warning "Required dependencies are still missing."
                fi
            elif (( status != 0 )); then
                punchi_warning "Required dependencies are still missing."
            fi
        fi
    fi
    return "$status"
}

punchi_offer_dependency_install() {
    local family="${1:?distribution family is required}"
    local status="${2:-1}"
    local -a missing=()
    local -a installable=()
    local -a install_command=()
    local -a update_command=()
    local package=""
    local label=""
    local suite=""
    local quickshell_handled=0

    [[ "$status" != "0" ]] || return 0

    while IFS= read -r package; do
        if [[ -n "$package" ]]; then
            missing+=("$package")
        fi
    done < <(
        {
            punchi_missing_packages runtime "$family"
            punchi_missing_packages build "$family"
        } | sort -u
    )
    (( ${#missing[@]} > 0 )) || return 0

    # Quickshell has no candidate in the configured suites on some Debian
    # releases. Installing it in the same apt call would abort every package, so
    # it is resolved first and kept out of the batched command.
    if [[ "$family" == "debian" ]] \
        && printf '%s\n' "${missing[@]}" | grep -qx 'quickshell' \
        && ! punchi_debian_package_available quickshell; then
        if suite="$(punchi_debian_backports_suite)"; then
            quickshell_handled=1
            punchi_warning "Quickshell is not available in the configured Debian suites."
            punchi_info "Debian publishes it in the $suite suite."
            if command -v sudo >/dev/null 2>&1 \
                && punchi_confirm "Enable $suite and install Quickshell from it? [y/N]: " n; then
                if punchi_debian_enable_backports "$suite" \
                    && sudo apt-get install -y -t "$suite" quickshell; then
                    punchi_success "Quickshell was installed from $suite."
                else
                    punchi_info "Quickshell remains missing. Enable $suite and run: sudo apt-get install -y -t $suite quickshell"
                fi
            else
                punchi_info "Quickshell remains missing. Enable $suite and run: sudo apt-get install -y -t $suite quickshell"
            fi
        fi
    fi

    for package in "${missing[@]}"; do
        if [[ "$package" == "quickshell" ]] && (( quickshell_handled == 1 )); then
            continue
        fi
        installable+=("$package")
    done
    (( ${#installable[@]} > 0 )) || return 0

    case "$family" in
        fedora)
            label="Fedora"
            install_command=(sudo dnf install "${installable[@]}")
            ;;
        debian)
            label="Debian/Ubuntu"
            update_command=(sudo apt-get update)
            install_command=(sudo apt-get install -y "${installable[@]}")
            ;;
        arch)
            label="Arch"
            install_command=(sudo pacman -S --needed "${installable[@]}")
            ;;
        *)
            return 0
            ;;
    esac

    if [[ "$family" != "fedora" ]]; then
        punchi_warning "The $label package mapping is best-effort and unvalidated."
    fi
    printf 'Install the missing packages with:\n  '
    if (( ${#update_command[@]} > 0 )); then
        printf '%q ' "${update_command[@]}"
        printf '&& '
    fi
    printf '%q ' "${install_command[@]}"
    printf '\n'

    if ! command -v sudo >/dev/null 2>&1; then
        punchi_info "sudo is not available; run the command above as an administrator."
        return 0
    fi
    if ! punchi_confirm "Install these packages now with sudo? [y/N]: " n; then
        punchi_info "No packages were installed."
        return 0
    fi
    if (( ${#update_command[@]} > 0 )); then
        "${update_command[@]}" || return 1
    fi
    "${install_command[@]}" || return 1
    punchi_success "Package installation finished. Re-run the dependency check."
}
