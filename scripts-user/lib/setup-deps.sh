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
        pkg-config \
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

# Prints "  Label      item · item" and wraps on separators at the terminal
# width, so a long package list stays a few readable lines.
punchi_report_list_line() {
    local label="${1:?label is required}"
    shift
    (($#)) || return 0
    local separator=', '
    if punchi_ui_terminal_supports_unicode 1; then
        separator=' · '
    fi
    local width=""
    width="$(punchi_report_width)"
    local column="${#label}"
    (( column < 9 )) && column=9
    column=$(( column + 2 ))
    local continuation=""
    printf -v continuation '%*s' $(( 2 + column )) ''
    local line=""
    printf -v line '  %-*s' "$column" "$label"
    local started=0
    local item=""
    for item in "$@"; do
        if (( started == 0 )); then
            line="$line$item"
            started=1
            continue
        fi
        if (( ${#line} + ${#separator} + ${#item} > width )); then
            printf '%s\n' "$line"
            line="$continuation$item"
            continue
        fi
        line="$line$separator$item"
    done
    printf '%s\n' "$line"
}

punchi_missing_commands() {
    local group="${1:?command group is required}"
    local command_name=""
    while IFS= read -r command_name; do
        [[ -n "$command_name" ]] || continue
        if ! punchi_resolve_command "$command_name" >/dev/null 2>&1; then
            printf '%s\n' "$command_name"
        fi
    done < <(punchi_command_group "$group")
}

punchi_command_ready_summary() {
    local group="${1:?command group is required}"
    local ready=0
    local total=0
    local command_name=""
    while IFS= read -r command_name; do
        [[ -n "$command_name" ]] || continue
        total=$(( total + 1 ))
        if punchi_resolve_command "$command_name" >/dev/null 2>&1; then
            ready=$(( ready + 1 ))
        fi
    done < <(punchi_command_group "$group")
    printf '%s %d/%d\n' "$group" "$ready" "$total"
}

punchi_python_ready_summary() {
    command -v python3 >/dev/null 2>&1 || return 0
    local module=""
    local ready=0
    local total=0
    for module in dbus gi; do
        total=$(( total + 1 ))
        if python3 -c "import $module" >/dev/null 2>&1; then
            ready=$(( ready + 1 ))
        fi
    done
    printf 'python %d/%d\n' "$ready" "$total"
}

# The install offer restates only the decision: what is missing, and one
# readiness summary line for everything the detailed report already listed.
# $1 names the required array and $2 the optional one; the optional packages are
# the validation group, which the dock builds and runs without, yet the offer
# installs them too so no check stays red after an install finishes.
punchi_report_missing_dependencies() {
    local -n report_required=${1:?required package array is required}
    local -a report_optional=()
    if [[ -n "${2:-}" ]]; then
        local -n optional_source=$2
        report_optional=("${optional_source[@]}")
    fi
    local -a commands=()
    local -a present=()
    local group=""
    local command_name=""

    for group in runtime build validation; do
        while IFS= read -r command_name; do
            [[ -n "$command_name" ]] || continue
            commands+=("$command_name")
        done < <(punchi_missing_commands "$group")
        present+=("$(punchi_command_ready_summary "$group")")
    done
    command_name="$(punchi_python_ready_summary || true)"
    [[ -n "$command_name" ]] && present+=("$command_name")
    if punchi_kde_session_detected; then
        present+=("Plasma session")
    fi
    if punchi_resolve_command git >/dev/null 2>&1; then
        present+=("git")
    fi

    punchi_rule
    printf 'Missing dependencies (%d)\n' "$(( ${#report_required[@]} + ${#report_optional[@]} ))"
    if ((${#commands[@]})); then
        punchi_report_list_line "Commands" "${commands[@]}"
    fi
    punchi_report_list_line "Packages" "${report_required[@]}"
    if ((${#report_optional[@]})); then
        punchi_report_list_line "Optional" "${report_optional[@]}"
    fi
    if ((${#present[@]})); then
        punchi_report_list_line "Present" "${present[@]}"
    fi
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
    # Fedora is exercised by CI on every change. Debian and Arch matched one
    # real installation each, which is a dated observation rather than a
    # standing guarantee, so the report names the date it was checked.
    local validated_on=""
    case "$family" in
        fedora) manager=rpm; label=Fedora ;;
        debian) manager=dpkg-query; label=Debian/Ubuntu; validated_on=2026-10-30 ;;
        arch) manager=pacman; label=Arch; validated_on=2026-10-31 ;;
    esac
    if [[ -n "$manager" ]] && command -v "$manager" >/dev/null 2>&1; then
        if [[ -n "$validated_on" ]]; then
            punchi_warning "Package names for $label were validated on one installation on $validated_on; other configurations may differ."
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
    punchi_info "Package-name checks are validated on Fedora 44."
    punchi_info "The Debian/Ubuntu and Arch mappings matched one installation"
    punchi_info "each (2026-10-30 and 2026-10-31); verify names when your"
    punchi_info "release differs from those."
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

# Runs a command, streams its output and keeps a copy to explain a failure.
punchi_run_install_step() {
    local log=""
    log="$(mktemp "${TMPDIR:-/tmp}/punchi-install.XXXXXX")"
    punchi_register_cleanup "$log"
    local status=0
    local errexit=0
    case $- in *e*) errexit=1 ;; esac
    set +e
    "$@" 2>&1 | tee "$log"
    # PIPESTATUS[0] is the command's own result whether or not pipefail is set.
    status="${PIPESTATUS[0]}"
    if (( errexit == 1 )); then
        set -e
    fi
    if (( status != 0 )); then
        punchi_explain_install_failure "$log"
    fi
    rm -f -- "$log"
    return "$status"
}

# apt refuses a signature whose validity starts in the future, which is what a
# clock behind real time produces. Naming the cause is the difference between a
# retry loop and a fix. The steps print once per run: a second failing step only
# repeats the shortfall.
punchi_install_clock_hint_shown="${punchi_install_clock_hint_shown:-0}"

punchi_explain_install_failure() {
    local log="${1:-}"
    [[ -s "$log" ]] || return 0
    local valid_from=""
    valid_from="$(grep -oE 'Not live until [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]+Z' "$log" \
        | head -n 1 | awk '{print $4}')" || valid_from=""
    if [[ -z "$valid_from" ]]; then
        grep -qiE 'signature verification failed|is not signed|no está firmado' "$log" \
            || return 0
    fi
    local now=""
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    if [[ -n "$valid_from" ]] && [[ ! "$now" < "$valid_from" ]]; then
        # The signature is already valid, so the clock is not the cause.
        return 0
    fi
    if (( punchi_install_clock_hint_shown == 1 )); then
        punchi_info "The clock is still behind; correct it as shown above."
        return 0
    fi
    punchi_install_clock_hint_shown=1
    punchi_warning "apt rejected a repository signature; the system clock is behind."
    if [[ -n "$valid_from" ]]; then
        printf '  Clock (UTC)          %s\n' "$now"
        printf '  Signature valid from %s\n' "$valid_from"
    fi
    punchi_info "Every signature check fails until the clock is corrected:"
    punchi_info "  sudo timedatectl set-local-rtc 1 --adjust-system-clock"
    punchi_info "  sudo apt-get install -y systemd-timesyncd"
    punchi_info "  sudo systemctl enable --now systemd-timesyncd"
}

# Quotes one command array as a copyable shell fragment, without a trailing
# space. Bash resolves the nameref in the caller's scope.
punchi_quote_words() {
    local -n quote_words=$1
    ((${#quote_words[@]})) || return 0
    local quoted=""
    printf -v quoted '%q ' "${quote_words[@]}"
    printf '%s\n' "${quoted% }"
}

punchi_offer_dependency_install() {
    local family="${1:?distribution family is required}"
    local status="${2:-1}"
    local -a required=()
    local -a optional=()
    local -a missing=()
    local -a installable=()
    local -a install_command=()
    local -a update_command=()
    local -a quickshell_command=()
    local package=""
    local label=""
    local suite=""
    local quickshell_suite=""
    local quickshell_excluded=0
    local install_total=0
    local plan_failed=0

    [[ "$status" != "0" ]] || return 0

    while IFS= read -r package; do
        if [[ -n "$package" ]]; then
            required+=("$package")
        fi
    done < <(
        {
            punchi_missing_packages runtime "$family"
            punchi_missing_packages build "$family"
        } | sort -u
    )

    # The validation group is optional for running the dock but still part of
    # what this offer installs: leaving it out left a fresh Arch system with a
    # red dependency check that the assistant itself refused to fix.
    while IFS= read -r package; do
        if [[ -n "$package" ]]; then
            optional+=("$package")
        fi
    done < <(punchi_missing_packages validation "$family")

    missing=("${required[@]}" "${optional[@]}")
    (( ${#missing[@]} > 0 )) || return 0

    punchi_report_missing_dependencies required optional

    # Quickshell has no candidate in the configured suites on some Debian
    # releases, and asking for it in the batched call would abort every package.
    # The repository question stays separate from the install question so each
    # answer only decides one thing.
    if [[ "$family" == "debian" ]] \
        && printf '%s\n' "${missing[@]}" | grep -qx 'quickshell' \
        && ! punchi_debian_package_available quickshell; then
        if suite="$(punchi_debian_backports_suite)"; then
            # Without a candidate in the configured suites, quickshell in the
            # batched call would abort every other package.
            quickshell_excluded=1
            punchi_heading "Required repository"
            local others=$(( ${#missing[@]} - 1 ))
            local others_noun="packages"
            local others_verb="come"
            if (( others == 1 )); then
                others_noun="package"
                others_verb="comes"
            fi
            if (( others > 0 )); then
                printf '  %s publishes quickshell; the other %d %s %s from the configured suites.\n' \
                    "$suite" "$others" "$others_noun" "$others_verb"
            else
                printf '  %s publishes quickshell.\n' "$suite"
            fi
            if command -v sudo >/dev/null 2>&1 \
                && punchi_confirm "Add $suite? [y/N]: " n; then
                if punchi_run_install_step punchi_debian_enable_backports "$suite"; then
                    punchi_success "Repository added: $suite"
                    quickshell_suite="$suite"
                else
                    punchi_info "Quickshell remains missing. Enable $suite and run: sudo apt-get install -y -t $suite quickshell"
                fi
            else
                punchi_info "Quickshell remains missing. Enable $suite and run: sudo apt-get install -y -t $suite quickshell"
            fi
        fi
    fi

    for package in "${missing[@]}"; do
        if [[ "$package" == "quickshell" ]] && (( quickshell_excluded == 1 )); then
            if [[ -n "$quickshell_suite" ]]; then
                quickshell_command=(sudo apt-get install -y -t "$quickshell_suite" quickshell)
                install_total=$(( install_total + 1 ))
            fi
            continue
        fi
        installable+=("$package")
        install_total=$(( install_total + 1 ))
    done

    if (( ${#installable[@]} == 0 )) && (( ${#quickshell_command[@]} == 0 )); then
        return 0
    fi

    case "$family" in
        fedora)
            label="Fedora"
            install_command=(sudo dnf install "${installable[@]}")
            ;;
        debian)
            label="Debian/Ubuntu"
            if (( ${#installable[@]} > 0 )); then
                update_command=(sudo apt-get update)
                install_command=(sudo apt-get install -y "${installable[@]}")
            fi
            ;;
        arch)
            label="Arch"
            install_command=(sudo pacman -S --needed "${installable[@]}")
            ;;
        *)
            return 0
            ;;
    esac

    if (( ${#quickshell_command[@]} > 0 )); then
        punchi_info "Quickshell is installed on its own so a missing candidate cannot abort the batch."
    fi
    local -a plan_parts=()
    local part=""
    if (( ${#update_command[@]} > 0 )); then
        plan_parts+=("$(punchi_quote_words update_command)")
    fi
    if (( ${#quickshell_command[@]} > 0 )); then
        plan_parts+=("$(punchi_quote_words quickshell_command)")
    fi
    if (( ${#install_command[@]} > 0 )); then
        plan_parts+=("$(punchi_quote_words install_command)")
    fi
    local command_text=""
    for part in "${plan_parts[@]}"; do
        if [[ -z "$command_text" ]]; then
            command_text="$part"
        else
            command_text="$command_text && $part"
        fi
    done
    printf 'Command: %s\n' "$command_text"

    if ! command -v sudo >/dev/null 2>&1; then
        punchi_info "sudo is not available; run the command above as an administrator."
        return 0
    fi
    local package_word="packages"
    (( install_total == 1 )) && package_word="package"
    if ! punchi_confirm "Install the $install_total missing $package_word now? [y/N]: " n; then
        punchi_info "No packages were installed."
        return 0
    fi
    if (( ${#update_command[@]} > 0 )); then
        punchi_run_install_step "${update_command[@]}" || return 1
    fi
    if (( ${#quickshell_command[@]} > 0 )); then
        if punchi_run_install_step "${quickshell_command[@]}"; then
            punchi_success "Quickshell was installed from $quickshell_suite."
        else
            # The batched packages can still install; only report the shortfall.
            punchi_info "Quickshell remains missing. Enable $quickshell_suite and run: sudo apt-get install -y -t $quickshell_suite quickshell"
            plan_failed=1
        fi
    fi
    if (( ${#install_command[@]} > 0 )); then
        punchi_run_install_step "${install_command[@]}" || return 1
    fi
    if (( plan_failed == 1 )); then
        return 1
    fi
    punchi_success "Package installation finished. Re-run the dependency check."
}
