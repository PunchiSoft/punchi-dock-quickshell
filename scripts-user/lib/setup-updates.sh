#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Read-only update checks for the source checkout.

punchi_git_checkout_root() {
    local root="${1:-${punchi_project_root:-}}"
    [[ -n "$root" ]] || return 1
    command -v git >/dev/null 2>&1 || return 1
    git -C "$root" rev-parse --git-dir >/dev/null 2>&1 || return 1
    printf '%s\n' "$root"
}

punchi_cmake_version_from_stdin() {
    awk '
        /^[[:space:]]*project\(/ {
            for (i = 1; i <= NF; i++) {
                if ($i == "VERSION") {
                    print $(i + 1)
                    exit
                }
            }
        }
    '
}

punchi_run_with_timeout() {
    local seconds="${1:?seconds are required}"
    shift
    if command -v timeout >/dev/null 2>&1; then
        timeout "$seconds" "$@"
    else
        "$@"
    fi
}

punchi_check_updates() {
    local mode="${1:-check}"
    case "$mode" in
        check|prompt|pull) ;;
        *) punchi_die "Unknown update mode: $mode" ;;
    esac

    if ! command -v git >/dev/null 2>&1; then
        punchi_error "Update checks require git, which is not installed."
        punchi_info "Install it yourself with: $(punchi_git_install_hint)"
        punchi_info "This script never installs git automatically."
        return 1
    fi

    local root=""
    if ! root="$(punchi_git_checkout_root)"; then
        punchi_error "Update checks require the Git source checkout."
        punchi_info "Run this menu from the cloned repository."
        punchi_info "Downloading setup.sh alone is not enough: the build needs the"
        punchi_info "repository files (CMakeLists.txt, modules/, adapters/, services/)."
        return 1
    fi

    local branch=""
    local upstream=""
    local remote=""
    branch="$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    upstream="$(git -C "$root" rev-parse --abbrev-ref \
        --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
    if [[ -z "$upstream" ]]; then
        punchi_warning "The checkout has no upstream branch to compare with."
        punchi_info "Create one with: git branch --set-upstream-to=origin/main ${branch:-main}"
        return 1
    fi
    remote="${upstream%%/*}"

    punchi_heading "Update check"
    printf 'Checkout: %s\n' "$root"
    printf 'Branch:   %s -> %s\n' "$branch" "$upstream"

    punchi_info "Contacting $remote..."
    local fetch_status=0
    local fetch_output=""
    fetch_output="$(GIT_TERMINAL_PROMPT=0 punchi_run_with_timeout 20 \
        git -C "$root" fetch --quiet --prune "$remote" 2>&1)" \
        || fetch_status=$?
    if (( fetch_status == 124 )); then
        punchi_error "Contacting $remote timed out; check the network and try again."
        return 1
    fi
    if (( fetch_status != 0 )); then
        punchi_error "Could not fetch from $remote."
        if [[ -n "$fetch_output" ]]; then
            punchi_muted "${fetch_output%%$'\n'*}"
        fi
        return 1
    fi

    local ahead="0"
    local behind="0"
    local counts=""
    counts="$(git -C "$root" rev-list --left-right --count \
        "HEAD...$upstream" 2>/dev/null || true)"
    if [[ -n "$counts" ]]; then
        ahead="$(awk '{print $1}' <<<"$counts")"
        behind="$(awk '{print $2}' <<<"$counts")"
    fi

    local local_version=""
    local remote_version=""
    local local_commit=""
    local remote_commit=""
    local_version="$(punchi_project_version)"
    remote_version="$(git -C "$root" show "$upstream:CMakeLists.txt" \
        2>/dev/null | punchi_cmake_version_from_stdin)"
    local_commit="$(git -C "$root" log -1 --format='%h %s' HEAD \
        2>/dev/null || true)"
    remote_commit="$(git -C "$root" log -1 --format='%h %s' "$upstream" \
        2>/dev/null || true)"

    printf 'Local:    %s at %s\n' "$local_version" "${local_commit:-unknown}"
    printf 'Remote:   %s at %s\n' \
        "${remote_version:-unknown}" "${remote_commit:-unknown}"

    local modified=""
    modified="$(git -C "$root" status --porcelain --untracked-files=no \
        2>/dev/null | wc -l)"
    if (( modified > 0 )); then
        punchi_warning "The checkout has $modified modified file(s); pulling may conflict."
    fi

    local install_root=""
    local version_file=""
    install_root="$(punchi_install_root 2>/dev/null || true)"
    if [[ -n "$install_root" ]]; then
        version_file="$install_root/$(punchi_install_version_name)"
        if [[ -r "$version_file" ]]; then
            printf 'Installed copy: %s\n' "$(head -n 1 "$version_file")"
        fi
    fi

    if (( behind > 0 )); then
        punchi_warning "The checkout is $behind commit(s) behind $upstream."
        if (( modified > 0 )); then
            punchi_warning "Refusing to pull while tracked files are modified."
            punchi_info "Commit or stash your work, then check again."
            if [[ "$mode" == "pull" ]]; then
                return 1
            fi
            return 0
        fi
        if [[ "$mode" == "check" ]]; then
            punchi_info "Review and update with: git pull --ff-only"
            punchi_info "Then run Install or update to rebuild and refresh the installed copy."
        else
            if [[ "$mode" == "prompt" ]] \
                && ! punchi_confirm "Update the checkout now with git pull --ff-only? [y/N]: " n; then
                punchi_info "The checkout was not changed."
                return 0
            fi
            punchi_info "Updating with git pull --ff-only..."
            if ! GIT_TERMINAL_PROMPT=0 punchi_run_with_timeout 60 \
                git -C "$root" pull --ff-only --quiet; then
                punchi_error "The update did not complete; inspect the output above."
                return 1
            fi
            local updated_commit=""
            updated_commit="$(git -C "$root" log -1 --format='%h %s' HEAD \
                2>/dev/null || true)"
            punchi_success "Checkout updated to ${updated_commit:-the latest commit}."
            local install_status=0
            if [[ "$mode" == "prompt" ]] \
                && declare -F punchi_action_install >/dev/null 2>&1; then
                if punchi_confirm "Rebuild and install now? [y/N]: " n; then
                    punchi_action_install || install_status=$?
                    return "$install_status"
                fi
            fi
            punchi_info "Run Install or update to rebuild and refresh the installed copy."
        fi
    elif (( ahead > 0 )); then
        punchi_info "The checkout is $ahead commit(s) ahead of $upstream; no newer remote commit exists."
    else
        punchi_success "The checkout matches $upstream."
    fi
    if [[ -n "$remote_version" && "$remote_version" != "$local_version" ]]; then
        punchi_info "Remote declares version $remote_version; the checkout declares $local_version."
    fi
    return 0
}
