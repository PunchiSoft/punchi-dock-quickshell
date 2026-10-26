#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Animated one-line progress for the long setup steps.
#
# Presentation only: callers keep their command order and error policy. Every
# line the step writes is still recorded in the log file the caller passes, so a
# failure can be reported and attached to the failure log. The progress loop and
# bar rendering follow the approach used by the Punchi Dock Remastered setup
# assistant.
#
# A step that finishes instantly would flash past, so a terminal run keeps the
# animation visible for at least PUNCHI_PROGRESS_MIN_SECONDS and holds the
# completion frame for PUNCHI_PROGRESS_SETTLE_SECONDS. Redirected output, logs
# and tests stay instantaneous.

PUNCHI_PROGRESS_MIN_SECONDS="${PUNCHI_PROGRESS_MIN_SECONDS:-0.9}"
PUNCHI_PROGRESS_SETTLE_SECONDS="${PUNCHI_PROGRESS_SETTLE_SECONDS:-0.4}"

punchi_progress_seconds_to_ms() {
    local value="${1:-0}"
    local whole=0
    local fraction=0

    if [[ "$value" =~ ^([0-9]{1,4})(\.([0-9]{1,3}))?$ ]]; then
        whole=$(( 10#${BASH_REMATCH[1]} ))
        fraction="${BASH_REMATCH[3]:-0}"
        while (( ${#fraction} < 3 )); do
            fraction+='0'
        done
        printf '%s\n' "$(( whole * 1000 + 10#$fraction ))"
        return 0
    fi
    printf '0\n'
}

punchi_progress_now_ms() {
    local stamp="${EPOCHREALTIME:-}"

    if [[ -n "$stamp" ]]; then
        stamp="${stamp/[.,]/}"
        printf '%s\n' "$(( 10#$stamp / 1000 ))"
        return 0
    fi
    printf '%s\n' "$(( SECONDS * 1000 ))"
}

punchi_progress_sleep_ms() {
    local milliseconds="${1:-0}"
    local delay=""

    (( milliseconds > 0 )) || return 0
    printf -v delay '%d.%03d' $(( milliseconds / 1000 )) \
        $(( milliseconds % 1000 ))
    sleep "$delay" || true
}

punchi_progress_update() {
    local percent="${1:?percentage is required}"
    local label="${2:?label is required}"

    if [[ ! "$percent" =~ ^[0-9]+$ ]] || (( percent > 100 )); then
        return 2
    fi
    [[ -n "${PUNCHI_PROGRESS_DIR:-}" ]] || return 0
    printf '%s\t%s\n' "$percent" "$label" >"$PUNCHI_PROGRESS_DIR/next-$BASHPID"
    mv -- "$PUNCHI_PROGRESS_DIR/next-$BASHPID" "$PUNCHI_PROGRESS_DIR/state"
}

punchi_progress_label() {
    case "$1" in
        prepare) printf '%s' 'Preparing environment...' ;;
        dependencies) printf '%s' 'Checking dependencies...' ;;
        configure) printf '%s' 'Configuring CMake...' ;;
        build) printf '%s' 'Building native integration...' ;;
        stage) printf '%s' 'Assembling the user-local installation...' ;;
        complete) printf '%s' 'Operation completed successfully' ;;
        failed) printf '%s' 'Operation failed' ;;
        cancelled) printf '%s' 'Operation cancelled.' ;;
        *) printf '%s' "$1" ;;
    esac
}

punchi_progress_bar() {
    local percent="${1:?percentage is required}"
    local width="${2:?bar width is required}"
    local fill="${3:-#}"
    local filled_width=0
    local empty_width=0
    local filled=""
    local empty=""

    if [[ ! "$percent" =~ ^[0-9]+$ ]] || (( percent > 100 )); then
        return 2
    fi
    if [[ ! "$width" =~ ^[0-9]+$ ]] || (( width <= 0 )); then
        return 2
    fi
    filled_width=$(( percent * width / 100 ))
    empty_width=$(( width - filled_width ))
    printf -v filled '%*s' "$filled_width" ''
    printf -v empty '%*s' "$empty_width" ''
    printf '[%s%s]' "${filled// /$fill}" "$empty"
}

# Only descend from the command PID owned by this invocation. Stop descendants
# first so their waiting parents can reap them; never signal the desktop group.
punchi_progress_stop_tree() {
    local parent="${1:?owned PID is required}"
    local child=""

    while IFS=' ' read -r child; do
        [[ "$child" =~ ^[0-9]+$ ]] || continue
        punchi_progress_stop_tree "$child"
    done < <(ps -o pid= --ppid "$parent" 2>/dev/null || true)
    kill -TERM "$parent" 2>/dev/null || true
}

punchi_progress_bar_width() {
    local columns="${1:?terminal width is required}"
    local width=0

    width=$(( columns - 29 ))
    (( width <= 34 )) || width=34
    (( width >= 4 )) || width=4
    printf '%s\n' "$width"
}

# Run one command behind the progress presentation. The caller keeps the log
# path because it decides whether a failure is worth recording permanently.
# A subshell isolates the EXIT trap and the final exit status of the runner from
# the setup process that keeps running afterwards.
punchi_run_step() {
    local log_file="${1:?log file is required}"
    shift

    if [[ "${PUNCHI_NO_PROGRESS:-0}" == "1" ]]; then
        "$@" 2>&1 | tee "$log_file"
        return "${PIPESTATUS[0]}"
    fi
    (punchi_progress_run "$log_file" "$@")
}

# A report step produces the output the user came for. The animation owns the
# terminal while the report is collected, then the capture is replayed so the
# result stays visible in the transcript.
punchi_run_report_step() {
    local log_file="${1:?log file is required}"
    shift

    if [[ "${PUNCHI_NO_PROGRESS:-0}" == "1" ]]; then
        "$@" 2>&1 | tee "$log_file"
        return "${PIPESTATUS[0]}"
    fi
    PUNCHI_PROGRESS_REPLAY=1 punchi_run_step "$log_file" "$@"
}

punchi_progress_run() {
    local log_file="${1:?log file is required}"
    shift
    local worker=""
    local status=0
    local percent=0
    local label=prepare
    local last_state=""
    local frame=0
    local part=""
    local pending=""
    local line=""
    local read_status=0
    local tty=0
    local columns=80
    local last_render=""
    local pipe_fd=""
    local command_status=0
    local frames=('/' '-' '\' '|')
    local bar_fill='#'
    local replay="${PUNCHI_PROGRESS_REPLAY:-0}"
    local started_ms=0
    local min_ms=0
    local settle_ms=0
    local locale_name="${LC_ALL:-${LC_CTYPE:-${LANG:-}}}"

    if [[ "${locale_name^^}" == *UTF-8* || "${locale_name^^}" == *UTF8* ]]; then
        bar_fill='█'
    fi
    [[ ! -t 1 || "${TERM:-}" == "dumb" ]] || tty=1
    # The captured output is rendered later, when its file descriptor is no
    # longer the terminal. Tell the presentation helpers which characters the
    # real terminal supports so replayed rules match the surrounding output.
    if (( tty )) && [[ "${locale_name^^}" == *UTF-8* || "${locale_name^^}" == *UTF8* ]]; then
        export PUNCHI_UI_UNICODE=1
    else
        export PUNCHI_UI_UNICODE=0
    fi

    started_ms="$(punchi_progress_now_ms)"
    min_ms="$(punchi_progress_seconds_to_ms "$PUNCHI_PROGRESS_MIN_SECONDS")"
    settle_ms="$(punchi_progress_seconds_to_ms "$PUNCHI_PROGRESS_SETTLE_SECONDS")"
    export PUNCHI_PROGRESS_DIR
    PUNCHI_PROGRESS_DIR="$(mktemp -d "${TMPDIR:-/tmp}/punchi-progress.XXXXXX")" || exit 1
    # The log belongs to this run: a caller that repeats a step must not replay
    # the previous capture as well.
    : >"$log_file" || exit 1

    cleanup_progress() {
        local saved=$?
        if [[ -n "$worker" ]]; then
            punchi_progress_stop_tree "$worker"
            wait "$worker" 2>/dev/null || true
        fi
        rm -rf -- "$PUNCHI_PROGRESS_DIR"
        exit "$saved"
    }
    trap cleanup_progress EXIT
    # Never clean up from the signal trap: the main loop owns the worker.
    trap 'status=130' INT
    trap 'status=143' TERM

    mkfifo "$PUNCHI_PROGRESS_DIR/output"
    exec {pipe_fd}<>"$PUNCHI_PROGRESS_DIR/output"
    punchi_progress_update 0 prepare
    "$@" >"$PUNCHI_PROGRESS_DIR/output" 2>&1 &
    worker=$!

    render_progress() {
        local symbol="$1"
        local text=""
        local bar=""
        local bar_width=0
        local text_width=0

        text="$(punchi_progress_label "$label")"
        if (( tty )); then
            columns="$(tput cols 2>/dev/null || printf 80)"
            [[ "$columns" =~ ^[0-9]+$ ]] || columns=80
            bar_width="$(punchi_progress_bar_width "$columns")"
            # "[" + "] " + bar brackets + " ###%" and the separating spaces take
            # 14 columns, so the rendered line never wraps. A wrapped line can
            # only be cleared on its last row, which left earlier frames behind.
            text_width=$(( columns - bar_width - 14 ))
            (( text_width >= 0 )) || text_width=0
            text="${text:0:text_width}"
            bar="$(punchi_progress_bar "$percent" "$bar_width" "$bar_fill")"
            printf '\r\033[2K[ %s ] %s %3d%% %s' "$symbol" "$bar" "$percent" "$text"
        elif [[ "$last_render" != "$percent:$text:$symbol" ]]; then
            printf '[%3d%%] %s\n' "$percent" "$text"
        fi
        last_render="$percent:$text:$symbol"
    }

    while :; do
        part=""
        if IFS= read -r -t 0.1 -u "$pipe_fd" part; then
            read_status=0
        else
            read_status=$?
        fi
        pending+="$part"
        if (( read_status == 0 )); then
            line="$pending"
            pending=""
            printf '%s\n' "$line" >>"$log_file" || { status=1; break; }
        fi
        if [[ -f "$PUNCHI_PROGRESS_DIR/state" ]]; then
            IFS=$'\t' read -r percent label <"$PUNCHI_PROGRESS_DIR/state" || true
        fi
        # Render on idle ticks or state changes, not on every build line.
        if (( read_status != 0 )) || [[ "$last_state" != "$percent:$label" ]]; then
            if (( tty )); then
                render_progress "${frames[frame % 4]}"
            else
                render_progress ''
            fi
            frame=$((frame + 1))
            last_state="$percent:$label"
        fi
        (( status == 0 )) || break
        if (( read_status != 0 )) && ! kill -0 "$worker" 2>/dev/null; then
            break
        fi
    done
    [[ -z "$pending" ]] || printf '%s' "$pending" >>"$log_file"

    if (( status != 0 )); then
        punchi_progress_stop_tree "$worker"
    fi
    wait "$worker" || command_status=$?
    worker=""
    (( status != 0 )) || status="$command_status"

    # A successful step that finished sooner than the minimum keeps spinning,
    # so the work is perceivable instead of flashing past. Failures are reported
    # immediately.
    if (( tty )) && (( status == 0 )); then
        local remaining_ms=$(( min_ms - ( $(punchi_progress_now_ms) - started_ms ) ))
        while (( remaining_ms > 0 )); do
            render_progress "${frames[frame % 4]}"
            frame=$(( frame + 1 ))
            punchi_progress_sleep_ms 100
            remaining_ms=$(( remaining_ms - 100 ))
        done
    fi

    local success_symbol="✓"
    local failure_symbol="✗"
    if (( tty == 0 )) \
        || [[ "${locale_name^^}" != *UTF-8* && "${locale_name^^}" != *UTF8* ]]; then
        success_symbol="OK"
        failure_symbol="XX"
    fi

    if [[ "$replay" == "1" ]]; then
        # The report is the result: show it instead of a frame that would repeat
        # the caller's own success or warning line.
        (( tty == 0 )) || printf '\r\033[2K'
        if [[ -r "$log_file" ]]; then
            cat -- "$log_file"
        fi
    elif (( status == 0 )); then
        percent=100
        label=complete
        render_progress "$success_symbol"
        (( tty == 0 )) || printf '\n'
        (( tty == 0 )) || punchi_progress_sleep_ms "$settle_ms"
    else
        local failed_label="$label"
        label=failed
        (( status != 130 && status != 143 )) || label=cancelled
        render_progress "$failure_symbol"
        printf '\n%s\n' "$(punchi_progress_label "$failed_label")"
        # Render log contents as plain text: diagnostics must not inject ANSI.
        if [[ -r "$log_file" ]]; then
            tail -n 16 "$log_file" | LC_ALL=C tr -d '\000-\010\013-\037\177'
        fi
        (( tty == 0 )) || printf '\n'
    fi
    exit "$status"
}
