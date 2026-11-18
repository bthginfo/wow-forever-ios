#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
cd "$(dirname "$0")/.."

pin=06e83ca597b6383e5c5fc60f627892edb560251c
checkout="$PWD/.build/playport"
if [[ ! -d "$checkout/.git" ]]; then
    mkdir -p "$checkout"
    git -C "$checkout" init --quiet
    git -C "$checkout" remote add origin https://github.com/playportdev/playport.git
fi
if ! git -C "$checkout" rev-parse --verify HEAD >/dev/null 2>&1; then
    git -C "$checkout" fetch --depth 1 origin "$pin"
    git -C "$checkout" checkout --quiet --detach FETCH_HEAD
fi
python3 tools/prepare_runtime.py "$checkout"
