#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Dependency reporting for the user setup assistant.

punchi_fedora_runtime_packages() {
    printf '%s\n' \
        quickshell \
        kf6-kirigami \
        kf6-kirigami-addons \
        kf6-qqc2-desktop-style \
        kf6-ksvg \
        plasma-workspace \
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

punchi_package_group() {
    local group="${1:?package group is required}"
    case "$group" in
        runtime) punchi_fedora_runtime_packages ;;
        build) punchi_fedora_build_packages ;;
        validation) punchi_fedora_validation_packages ;;
        *) return 1 ;;
    esac
}

punchi_package_installed() {
    local package="${1:?package is required}"
    local family="${2:-}"
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
    done < <(punchi_package_group "$group")
}

punchi_resolve_command() {
    local name="${1:?command name is required}"
    local candidate=""
    local -a candidates=()
    case "$name" in
        c++) candidates=(c++ g++ clang++) ;;
        qtpaths6) candidates=(qtpaths6 qtpaths) ;;
        qmllint)
            candidates=(qmllint qmllint6 /usr/lib64/qt6/bin/qmllint /usr/lib/qt6/bin/qmllint)
            ;;
        qmltestrunner)
            candidates=(qmltestrunner qmltestrunner6 /usr/lib64/qt6/bin/qmltestrunner /usr/lib/qt6/bin/qmltestrunner)
            ;;
        *) candidates=("$name") ;;
    esac
    for candidate in "${candidates[@]}"; do
        if [[ "$candidate" == /* ]]; then
            if [[ -x "$candidate" ]]; then
                printf '%s\n' "$candidate"
                return 0
            fi
        elif command -v "$candidate" >/dev/null 2>&1; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

punchi_command_group() {
    local group="${1:?command group is required}"
    case "$group" in
        runtime) printf '%s\n' qs ;;
        build) printf '%s\n' cmake ninja c++ pkg-config wayland-scanner qtpaths6 ;;
        validation) printf '%s\n' qmllint qmltestrunner python3 dbus-run-session ;;
        *) return 1 ;;
    esac
}

punchi_report_command_group() {
    local group="${1:?command group is required}"
    local label="${2:?label is required}"
    local required="${3:-0}"
    local command_name=""
    local resolved=""
    local missing=0

    punchi_muted "$label"
    while IFS= read -r command_name; do
        [[ -n "$command_name" ]] || continue
        if resolved="$(punchi_resolve_command "$command_name")"; then
            printf '  [ok]      %-16s %s\n' "$command_name" "$resolved"
        else
            printf '  [missing] %-16s\n' "$command_name"
            if (( required == 1 )); then
                missing=1
            fi
        fi
    done < <(punchi_command_group "$group")
    return "$missing"
}

punchi_report_python_modules() {
    command -v python3 >/dev/null 2>&1 || return 0
    local module=""
    local missing=0
    for module in dbus gi; do
        if python3 -c "import $module" >/dev/null 2>&1; then
            printf '  [ok]      python:%-9s\n' "$module"
        else
            printf '  [missing] python:%-9s\n' "$module"
            missing=1
        fi
    done
    return "$missing"
}

punchi_dependency_report() {
    local family="${1:?distribution family is required}"
    local status=0
    local validation_status=0

    punchi_heading "Runtime"
    punchi_report_command_group runtime "Required commands" 1 || status=1

    punchi_heading "Build"
    punchi_report_command_group build "Required commands" 1 || status=1

    punchi_heading "Validation tools"
    punchi_report_command_group validation "Project checks and tests" 0 \
        || validation_status=1
    punchi_report_python_modules || validation_status=1

    if [[ "$family" == "fedora" ]] && command -v rpm >/dev/null 2>&1; then
        local group=""
        local package=""
        local missing=0
        for group in runtime build validation; do
            punchi_muted "Fedora packages: $group"
            while IFS= read -r package; do
                [[ -n "$package" ]] || continue
                if punchi_package_installed "$package" fedora; then
                    printf '  [ok]      %s\n' "$package"
                else
                    printf '  [missing] %s\n' "$package"
                    missing=1
                    [[ "$group" == "validation" ]] || status=1
                fi
            done < <(punchi_package_group "$group")
        done
        if (( missing == 0 )); then
            punchi_success "All checked Fedora packages are installed."
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
    punchi_info "On other distributions, install the Quickshell, Qt 6, KF6 and"
    punchi_info "Wayland development equivalents, then run this check again."
}

punchi_dependency_check() {
    local offer_install="${1:-0}"
    local family=""
    family="$(punchi_distro_family "$(punchi_distro_id)" "$(punchi_distro_like)")"

    punchi_heading "Dependency check"
    printf 'Distribution: %s (%s)\n' "$(punchi_system_name)" "$family"
    punchi_rule

    local status=0
    punchi_dependency_report "$family" || status=1

    punchi_rule
    if (( status == 0 )); then
        punchi_success "Required runtime and build dependencies are present."
    else
        punchi_warning "Required dependencies are missing."
    fi

    if (( offer_install == 1 )) && [[ "$family" == "fedora" ]]; then
        punchi_offer_fedora_dependency_install "$status"
    fi
    return "$status"
}

punchi_offer_fedora_dependency_install() {
    local status="${1:-1}"
    local -a missing=()
    local package=""

    [[ "$status" != "0" ]] || return 0
    command -v dnf >/dev/null 2>&1 || return 0

    while IFS= read -r package; do
        if [[ -n "$package" ]]; then
            missing+=("$package")
        fi
    done < <(
        {
            punchi_missing_packages runtime fedora
            punchi_missing_packages build fedora
        } | sort -u
    )
    (( ${#missing[@]} > 0 )) || return 0

    printf 'Install the missing packages with:\n  sudo dnf install'
    printf ' %q' "${missing[@]}"
    printf '\n'
    if ! command -v sudo >/dev/null 2>&1; then
        punchi_info "sudo is not available; run the command above as an administrator."
        return 0
    fi
    if ! punchi_confirm "Install these packages now with sudo? [y/N]: " n; then
        punchi_info "No packages were installed."
        return 0
    fi
    sudo dnf install "${missing[@]}" || return 1
    punchi_success "Package installation finished. Re-run the dependency check."
}
