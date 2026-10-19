#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Entry point for a CMake-installed tree (bin/punchi-dock-quickshell).
set -euo pipefail
prefix="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$prefix/share/punchi-dock-quickshell/scripts-user/launcher.sh" "$@"
