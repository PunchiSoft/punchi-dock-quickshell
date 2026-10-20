#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Shared terminal and path helpers for the user setup assistant.

punchi_setup_cleanup_paths=()

punchi_register_cleanup() {
    local path="${1:-}"
    if [[ -n "$path" ]]; then
        punchi_setup_cleanup_paths+=("$path")
    fi
}

punchi_setup_cleanup() {
    local path=""
    for path in "${punchi_setup_cleanup_paths[@]}"; do
        if [[ -n "$path" ]]; then
            rm -rf -- "$path"
        fi
    done
}

punchi_colors_enabled() {
    [[ -z "${NO_COLOR+x}" && "${TERM:-}" != "dumb" ]]
}

punchi_style() {
    local style="${1:?style is required}"
    if ! punchi_colors_enabled; then
        return 0
    fi
    case "$style" in
        heading) printf '\033[1;36m' ;;
        info) printf '\033[36m' ;;
        success) printf '\033[32m' ;;
        warning) printf '\033[1;33m' ;;
        error) printf '\033[1;31m' ;;
        muted) printf '\033[1m' ;;
        *) return 0 ;;
    esac
}

punchi_print() {
    local style="${1:?style is required}"
    shift
    local reset=""
    if punchi_colors_enabled; then
        reset=$'\033[0m'
    fi
    printf '%s%s%s\n' "$(punchi_style "$style")" "$*" "$reset"
}

punchi_heading() { punchi_print heading "$*"; }
punchi_info() { punchi_print info "$*"; }
punchi_success() { punchi_print success "$*"; }
punchi_warning() { punchi_print warning "$*"; }
punchi_error() { punchi_print error "$*" >&2; }
punchi_muted() { punchi_print muted "$*"; }

punchi_rule() {
    if punchi_colors_enabled; then
        printf '%s\n' '────────────────────────────────────────────────────────────'
    else
        printf '%s\n' '------------------------------------------------------------'
    fi
}

punchi_die() {
    punchi_error "Error: $*"
    exit 1
}

punchi_sanitize_text() {
    local value="${1:-}"
    value="${value//$'\n'/ }"
    value="${value//$'\r'/ }"
    value="${value//$'\t'/ }"
    printf '%s' "$value" | LC_ALL=C tr -d '\000-\010\013\014\016-\037\177'
}

punchi_git_install_hint() {
    local family=""
    family="$(punchi_distro_family "$(punchi_distro_id)" "$(punchi_distro_like)")"
    case "$family" in
        fedora) printf '%s\n' 'sudo dnf install git' ;;
        debian) printf '%s\n' 'sudo apt-get install git' ;;
        arch) printf '%s\n' 'sudo pacman -S git' ;;
        *) printf '%s\n' 'install the git package with your distribution package manager' ;;
    esac
}

punchi_project_version() {
    local version=""
    if [[ -r "$punchi_project_root/CMakeLists.txt" ]]; then
        version="$(awk '
            /^project\(/ {
                for (i = 1; i <= NF; i++) {
                    if ($i == "VERSION") {
                        print $(i + 1)
                        exit
                    }
                }
            }
        ' "$punchi_project_root/CMakeLists.txt")"
    elif [[ -r "$punchi_project_root/$(punchi_install_version_name)" ]]; then
        version="$(head -n 1 "$punchi_project_root/$(punchi_install_version_name)")"
    fi
    printf '%s\n' "${version:-unknown}"
}

punchi_os_release_value() {
    local key="${1:?key is required}"
    local file="${PUNCHI_OS_RELEASE_FILE:-/etc/os-release}"
    local name=""
    local value=""
    [[ -r "$file" ]] || return 1
    while IFS='=' read -r name value; do
        [[ "$name" == "$key" ]] || continue
        value="${value%$'\r'}"
        value="${value#\"}"
        value="${value%\"}"
        value="${value#\'}"
        value="${value%\'}"
        printf '%s\n' "$value"
        return 0
    done < "$file"
    return 1
}

punchi_distro_id() {
    local value=""
    value="$(punchi_os_release_value ID || true)"
    printf '%s\n' "${value:-unknown}" | tr '[:upper:]' '[:lower:]'
}

punchi_distro_like() {
    local value=""
    value="$(punchi_os_release_value ID_LIKE || true)"
    printf '%s\n' "$value" | tr '[:upper:]' '[:lower:]'
}

punchi_distro_family() {
    local id="${1:-}"
    local like="${2:-}"
    case "$id" in
        *neon*|*debian*|*ubuntu*|*kubuntu*|*pop*|*mint*) printf '%s\n' debian ;;
        *arch*|*manjaro*|*endeavouros*|*garuda*|*artix*) printf '%s\n' arch ;;
        *fedora*|*rhel*|*nobara*|*centos*) printf '%s\n' fedora ;;
        *)
            case " $like " in
                *arch*) printf '%s\n' arch ;;
                *debian*|*ubuntu*) printf '%s\n' debian ;;
                *fedora*|*rhel*) printf '%s\n' fedora ;;
                *) printf '%s\n' unsupported ;;
            esac
            ;;
    esac
}

punchi_system_name() {
    local value=""
    value="$(punchi_os_release_value PRETTY_NAME || true)"
    if [[ -z "$value" ]]; then
        value="$(uname -s)"
    fi
    punchi_sanitize_text "$value"
}

punchi_documents_dir() {
    local documents=""
    local config_file=""
    local key=""
    local value=""

    if command -v xdg-user-dir >/dev/null 2>&1; then
        documents="$(xdg-user-dir DOCUMENTS 2>/dev/null || true)"
    fi
    if [[ -z "$documents" || "$documents" != /* || "$documents" == "$HOME" ]]; then
        config_file="${XDG_CONFIG_HOME:-$HOME/.config}/user-dirs.dirs"
        if [[ -r "$config_file" ]]; then
            while IFS='=' read -r key value; do
                [[ "$key" == "XDG_DOCUMENTS_DIR" ]] || continue
                value="${value%\"}"
                value="${value#\"}"
                value="${value//\$HOME/$HOME}"
                documents="$value"
                break
            done < "$config_file"
        fi
    fi
    if [[ -z "$documents" || "$documents" != /* || "$documents" == "$HOME" ]]; then
        documents="$HOME/Documents"
    fi
    printf '%s\n' "$documents"
}

punchi_write_failure_log() {
    local action="${1:?action is required}"
    local transcript="${2:-}"
    local documents=""
    local file=""
    local install_root=""
    local kde_status="no"

    documents="$(punchi_documents_dir)"
    if ! mkdir -p "$documents"; then
        punchi_warning "Could not create the Documents directory: $documents"
        return 1
    fi
    if ! file="$(mktemp "$documents/punchi-dock-quickshell-setup-$(date +%Y%m%d-%H%M%S)-XXXXXX.log")"; then
        punchi_warning "Could not create a failure log in $documents."
        return 1
    fi
    install_root="$(punchi_install_root 2>/dev/null || printf '%s' 'invalid')"
    if punchi_kde_session_detected; then
        kde_status="yes"
    fi
    if ! {
        printf 'Punchi Dock Quickshell setup failure\n'
        printf 'Date: %s\n' "$(date --iso-8601=seconds 2>/dev/null || date)"
        printf 'Action: %s\n' "$action"
        printf 'Version: %s\n' "$(punchi_project_version)"
        printf 'Distribution: %s\n' "$(punchi_system_name)"
        printf 'Distribution family: %s\n' \
            "$(punchi_distro_family "$(punchi_distro_id)" "$(punchi_distro_like)")"
        printf 'KDE session detected: %s\n' "$kde_status"
        printf 'Source root: %s\n' "$punchi_project_root"
        printf 'Install root: %s\n' "$install_root"
        printf '\n--- output ---\n'
        if [[ -n "$transcript" && -r "$transcript" ]]; then
            tail -n 4000 "$transcript"
        else
            printf 'No captured output was available.\n'
        fi
    } > "$file"; then
        punchi_warning "Could not write the failure log: $file"
        return 1
    fi
    chmod 600 "$file" 2>/dev/null || true
    printf 'Failure log: %s\n' "$file" >&2
    return 0
}

punchi_job_count() {
    local jobs="${PUNCHI_JOBS:-}"
    if [[ -z "$jobs" ]]; then
        if command -v nproc >/dev/null 2>&1; then
            jobs="$(nproc)"
        elif command -v getconf >/dev/null 2>&1; then
            jobs="$(getconf _NPROCESSORS_ONLN 2>/dev/null || true)"
        fi
    fi
    [[ "$jobs" =~ ^[1-9][0-9]*$ ]] || jobs=1
    printf '%s\n' "$jobs"
}

punchi_confirm() {
    local prompt="${1:?prompt is required}"
    local default="${2:-n}"
    local answer=""
    if [[ "${PUNCHI_ASSUME_YES:-0}" == "1" ]]; then
        return 0
    fi
    if [[ ! -t 0 ]]; then
        [[ "$default" == "y" ]]
        return
    fi
    printf '%s' "$prompt"
    read -r answer || answer=""
    case "${answer:-$default}" in
        y|Y|yes|YES|s|S|si|sí|SÍ|j|J|ja|JA) return 0 ;;
        *) return 1 ;;
    esac
}

punchi_pause() {
    [[ -t 0 ]] || return 0
    printf '%s' 'Press Enter to continue...'
    read -r _ || true
}

punchi_install_root() {
    local requested="${PUNCHI_INSTALL_PREFIX:-${XDG_DATA_HOME:-$HOME/.local/share}/punchi-dock-quickshell}"
    if [[ "$requested" != /* ]]; then
        punchi_error "Error: The install prefix must be an absolute path."
        return 1
    fi
    local resolved=""
    resolved="$(realpath -m -- "$requested" 2>/dev/null || true)"
    if [[ -z "$resolved" ]]; then
        punchi_error "Error: Could not resolve the install prefix."
        return 1
    fi
    case "$resolved" in
        /|/home|/usr|/usr/local|/opt|"$HOME")
            punchi_error "Error: Refusing unsafe install prefix: $resolved"
            return 1
            ;;
    esac
    if punchi_source_checkout_available \
        && [[ "$resolved" == "$punchi_project_root" \
            || "$resolved" == "$punchi_project_root"/* \
            || "$punchi_project_root" == "$resolved"/* ]]; then
        punchi_error "Error: The install prefix must not overlap the source checkout."
        return 1
    fi
    printf '%s\n' "$resolved"
}

punchi_launcher_path() {
    printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/applications/punchi-dock-quickshell.desktop"
}

punchi_config_path() {
    printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/punchi-dock-quickshell.json"
}

punchi_legacy_config_path() {
    printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/punchi-shell.json"
}

punchi_install_marker_name() {
    printf '%s\n' '.punchi-dock-quickshell-install'
}

punchi_install_manifest_name() {
    printf '%s\n' '.punchi-dock-quickshell-files'
}

punchi_install_version_name() {
    printf '%s\n' '.punchi-dock-quickshell-version'
}

punchi_desktop_exec_quote() {
    local value="${1:?path is required}"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '"%s"' "$value"
}

punchi_running_path() {
    local path="${1:-}"
    [[ -n "$path" ]] || return 1
    command -v qs >/dev/null 2>&1 || return 1
    local output=""
    if ! output="$(qs list --path "$path" --json 2>/dev/null)"; then
        return 1
    fi
    [[ -n "$output" ]] || return 1
    if [[ "$output" == '[]' || "$output" == 'No running instances for '* ]]; then
        return 1
    fi
    return 0
}

punchi_source_checkout_available() {
    [[ -f "$punchi_project_root/CMakeLists.txt" \
        && -d "$punchi_project_root/adapters/kde/native" \
        && -d "$punchi_project_root/modules" ]]
}

punchi_build_artifacts_ready() {
    [[ -f "$punchi_project_root/build/qml/Punchi/Kde/libpunchikdeplugin.so" \
        && -f "$punchi_project_root/build/libpunchikde.so" \
        && -x "$punchi_project_root/build/punchi-window-state" ]]
}
