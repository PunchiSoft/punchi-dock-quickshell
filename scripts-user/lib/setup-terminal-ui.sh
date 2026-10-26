#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Terminal presentation primitives: styles, boxed header and phase lines.
# Every helper receives the destination descriptor so a redirected stream never
# receives ANSI escapes or box-drawing characters it cannot render.

PUNCHI_UI_ANSI_RESET=$'\033[0m'
PUNCHI_UI_ANSI_BOLD=$'\033[1m'
PUNCHI_UI_ANSI_CYAN=$'\033[36m'
PUNCHI_UI_ANSI_GREEN=$'\033[32m'
PUNCHI_UI_ANSI_YELLOW=$'\033[33m'
PUNCHI_UI_ANSI_RED=$'\033[31m'

punchi_ui_terminal_allows_color() {
    [[ -z "${NO_COLOR+x}" && "${TERM:-}" != "dumb" ]]
}

punchi_ui_terminal_supports_color() {
    local descriptor="${1:?file descriptor is required}"
    [[ "$descriptor" =~ ^[0-9]+$ ]] || return 2
    punchi_ui_terminal_allows_color && [[ -t "$descriptor" ]]
}

punchi_ui_terminal_supports_unicode() {
    local descriptor="${1:?file descriptor is required}"
    local locale_name="${LC_ALL:-${LC_CTYPE:-${LANG:-}}}"

    [[ "$descriptor" =~ ^[0-9]+$ ]] || return 2
    [[ -t "$descriptor" && "${TERM:-}" != "dumb" ]] || return 1
    [[ "${locale_name^^}" == *UTF-8* || "${locale_name^^}" == *UTF8* ]]
}

punchi_ui_style_code() {
    case "${1:?terminal style is required}" in
        heading) printf '%s%s' "$PUNCHI_UI_ANSI_BOLD" "$PUNCHI_UI_ANSI_CYAN" ;;
        info) printf '%s' "$PUNCHI_UI_ANSI_CYAN" ;;
        success) printf '%s' "$PUNCHI_UI_ANSI_GREEN" ;;
        warning) printf '%s%s' "$PUNCHI_UI_ANSI_BOLD" "$PUNCHI_UI_ANSI_YELLOW" ;;
        error) printf '%s%s' "$PUNCHI_UI_ANSI_BOLD" "$PUNCHI_UI_ANSI_RED" ;;
        muted) printf '%s' "$PUNCHI_UI_ANSI_BOLD" ;;
        plain) printf '' ;;
        *) return 2 ;;
    esac
}

punchi_ui_sanitize_text() {
    local value="${1:-}"
    value="${value//$'\n'/ }"
    value="${value//$'\r'/ }"
    value="${value//$'\t'/ }"
    printf '%s' "$value" | LC_ALL=C tr -d '\000-\010\013\014\016-\037\177'
}

punchi_ui_write_styled_line() {
    local style="${1:?terminal style is required}"
    local descriptor="${2:?file descriptor is required}"
    local text="${3:-}"
    local style_code=""

    if punchi_ui_terminal_supports_color "$descriptor"; then
        style_code="$(punchi_ui_style_code "$style")" || style_code=""
        if [[ -n "$style_code" ]]; then
            printf '%s%s%s\n' "$style_code" "$text" "$PUNCHI_UI_ANSI_RESET" \
                >&"$descriptor"
            return 0
        fi
    fi
    printf '%s\n' "$text" >&"$descriptor"
}

punchi_ui_repeat() {
    local value="${1:?repeat value is required}"
    local count="${2:?repeat count is required}"
    local output=""
    local index=0

    for (( index = 0; index < count; index++ )); do
        output+="$value"
    done
    printf '%s' "$output"
}

punchi_ui_fit_text() {
    local text="${1:-}"
    local width="${2:?text width is required}"
    local ellipsis="${3:-...}"
    local ellipsis_length="${#ellipsis}"

    if (( ${#text} <= width )); then
        printf '%s' "$text"
    elif (( width > ellipsis_length )); then
        printf '%s%s' "${text:0:$(( width - ellipsis_length ))}" "$ellipsis"
    else
        printf '%s' "${text:0:$width}"
    fi
}

punchi_ui_box_line() {
    local descriptor="${1:?file descriptor is required}"
    local style="${2:?terminal style is required}"
    local width="${3:?box width is required}"
    local left="${4:?left border is required}"
    local right="${5:?right border is required}"
    local source_text="${6:-}"
    local text=""
    local padding=0

    text="$(punchi_ui_fit_text "$source_text" "$width" '…')"
    padding=$(( width - ${#text} ))
    punchi_ui_write_styled_line "$style" "$descriptor" \
        "$left $text$(punchi_ui_repeat ' ' "$padding") $right"
}

punchi_ui_header_width() {
    local descriptor="${1:?file descriptor is required}"
    local width=66
    local columns=80

    if [[ -t "$descriptor" ]]; then
        columns="$(tput cols 2>/dev/null || printf 80)"
        [[ "$columns" =~ ^[0-9]+$ ]] || columns=80
        width=$(( columns - 4 ))
        (( width <= 66 )) || width=66
        (( width >= 40 )) || width=40
    fi
    printf '%s\n' "$width"
}

# Phase and header lines always go to stdout, which is where the assistant
# writes every other message. The fd-aware primitives above stay available for
# callers that need another stream.
punchi_ui_render_header() {
    local title=""
    local environment_line=""
    local resources_line=""
    local width=66
    local horizontal=""

    title="$(punchi_ui_sanitize_text "${1:-}")"
    environment_line="$(punchi_ui_sanitize_text "${2:-}")"
    resources_line="$(punchi_ui_sanitize_text "${3:-}")"

    if ! punchi_ui_terminal_supports_unicode 1; then
        punchi_ui_write_styled_line heading 1 "$title"
        printf '%s\n' "$environment_line"
        printf '%s\n' "$resources_line"
        return 0
    fi

    width="$(punchi_ui_header_width 1)"
    horizontal="$(punchi_ui_repeat '─' "$(( width + 2 ))")"
    punchi_ui_write_styled_line info 1 "╭${horizontal}╮"
    punchi_ui_box_line 1 heading "$width" '│' '│' "$title"
    punchi_ui_write_styled_line info 1 "├${horizontal}┤"
    punchi_ui_box_line 1 plain "$width" '│' '│' "$environment_line"
    punchi_ui_box_line 1 plain "$width" '│' '│' "$resources_line"
    punchi_ui_write_styled_line info 1 "╰${horizontal}╯"
}

punchi_ui_render_phase() {
    local index="${1:?phase index is required}"
    local total="${2:?phase total is required}"
    local state="${3:?phase state is required}"
    local label="${4:?phase label is required}"
    local status_text="${5:?phase status text is required}"
    local detail="${6:-}"
    local symbol=""
    local separator=" - "
    local style="plain"
    local rendered=""

    case "$state" in
        active)  symbol='>>'; style=info ;;
        success) symbol='OK'; style=success ;;
        warning) symbol='!!'; style=warning ;;
        error)   symbol='XX'; style=error ;;
        waiting) symbol='--'; style=plain ;;
        *) return 2 ;;
    esac

    if punchi_ui_terminal_supports_unicode 1; then
        separator=' — '
        case "$state" in
            active)  symbol='●' ;;
            success) symbol='✓' ;;
            warning) symbol='!' ;;
            error)   symbol='✗' ;;
            waiting) symbol='○' ;;
        esac
    fi

    rendered="[$index/$total] $symbol $label: $status_text"
    if [[ -n "$detail" ]]; then
        rendered+="$separator$detail"
    fi
    punchi_ui_write_styled_line "$style" 1 "$rendered"
}

# An in-progress line only helps while it can be replaced by its result. Keep
# redirected transcripts free of pairs of lines that were never simultaneous.
punchi_ui_render_phase_started() {
    local index="${1:?phase index is required}"
    local total="${2:?phase total is required}"
    local label="${3:?phase label is required}"

    punchi_ui_terminal_supports_unicode 1 || return 0
    punchi_ui_render_phase "$index" "$total" active "$label" 'In progress'
}
