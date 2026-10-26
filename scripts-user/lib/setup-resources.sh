#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Detected machine resources and the RAM-safe build concurrency they allow.

punchi_total_ram_mb() {
    local mem_kb=""
    local free_mb=""

    if [[ -r /proc/meminfo ]]; then
        mem_kb="$(awk '/^MemTotal:/ { print $2; exit }' /proc/meminfo 2>/dev/null || true)"
        if [[ "$mem_kb" =~ ^[0-9]+$ ]] && (( mem_kb > 0 )); then
            printf '%s\n' "$(( mem_kb / 1024 ))"
            return 0
        fi
    fi
    if command -v free >/dev/null 2>&1; then
        free_mb="$(free -m 2>/dev/null | awk '/^Mem:/ { print $2; exit }' || true)"
        if [[ "$free_mb" =~ ^[0-9]+$ ]] && (( free_mb > 0 )); then
            printf '%s\n' "$free_mb"
            return 0
        fi
    fi
    printf '%s\n' 4096
}

punchi_format_ram_display() {
    local ram_mb="${1:-}"

    [[ "$ram_mb" =~ ^[0-9]+$ ]] || ram_mb="$(punchi_total_ram_mb)"
    if (( ram_mb >= 1024 )); then
        printf '%d.%d GiB\n' "$(( ram_mb / 1024 ))" \
            "$(( (ram_mb % 1024) * 10 / 1024 ))"
    else
        printf '%d MiB\n' "$ram_mb"
    fi
}

punchi_cpu_core_count() {
    local cores=""

    if command -v nproc >/dev/null 2>&1; then
        cores="$(nproc 2>/dev/null || true)"
    fi
    if [[ -z "$cores" ]] && command -v getconf >/dev/null 2>&1; then
        cores="$(getconf _NPROCESSORS_ONLN 2>/dev/null || true)"
    fi
    [[ "$cores" =~ ^[1-9][0-9]*$ ]] || cores=1
    printf '%s\n' "$cores"
}

# Each parallel C++ translation unit of this Qt/KF6 project needs roughly
# 1.0-1.5 GiB. Cap the automatic job count by installed memory so a small
# machine swaps instead of reporting a much slower "successful" build.
punchi_auto_job_count() {
    local ram_mb=""
    local cores=""
    local limit=0
    local jobs=0

    ram_mb="$(punchi_total_ram_mb)"
    cores="$(punchi_cpu_core_count)"

    if (( ram_mb < 4600 )); then
        limit=1
    elif (( ram_mb < 8600 )); then
        limit=2
    elif (( ram_mb < 16500 )); then
        limit=4
    else
        limit="$cores"
    fi

    jobs="$cores"
    if (( jobs > limit )); then
        jobs="$limit"
    fi
    if (( jobs < 1 )); then
        jobs=1
    fi
    printf '%s\n' "$jobs"
}
