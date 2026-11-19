#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
cd "$(dirname "$0")/.."

if (( $# > 1 )); then
    printf 'Usage: %s [--preflight | --plan]\n' "$0" >&2
    exit 2
fi

case "${1:-}" in
    --help|-h)
        printf 'Usage: %s [--preflight | --plan]\n' "$0"
        printf '%s\n' 'Build an unsigned WoW Forever iOS IPA on x86-64 Linux.' \
            'Use --preflight to check the pinned build inputs or --plan to list the build stages.'
        exit
        ;;
    --preflight) options=(--from inputs --to inputs) ;;
    --plan) options=(--plan) ;;
    "") options=() ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
esac

bash tools/prepare_device.sh
runtime="$PWD/.build/playport"
build=(./pp build --variant release --unsigned)

if (( ${#options[@]} )); then
    (cd "$runtime" && "${build[@]}" "${options[@]}")
    exit
fi

output=$(mktemp -d "$PWD/.build/device-ipa.XXXXXX")
(cd "$runtime" && PLAYPORT_OUT="$output" "${build[@]}")
shopt -s nullglob
packages=("$output"/*/Playport-*-release-unsigned-*.ipa)
if (( ${#packages[@]} != 1 )); then
    printf 'Expected one verified device IPA under %s\n' "$output" >&2
    exit 1
fi
ipa="${packages[0]}"

python3 - "$ipa" "$PWD/ForeverTouch" <<'PY'
from pathlib import Path
import plistlib
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as archive:
    app = "Payload/Playport.app"
    info = plistlib.loads(archive.read(f"{app}/Info.plist"))
    if info.get("CFBundleDisplayName") != "WoW Forever iOS":
        sys.exit("The IPA is missing the WoW Forever launcher.")
    for source in Path(sys.argv[2]).iterdir():
        if source.is_file() and archive.read(f"{app}/ForeverTouch/{source.name}") != source.read_bytes():
            sys.exit(f"The IPA does not contain the prepared add-on file {source.name}.")
PY

directory="${ipa%/*}"
mv -- "$ipa" "$directory/WoW-Forever-iOS.ipa"
(cd "$directory" && sha256sum WoW-Forever-iOS.ipa artifacts.tsv > SHA256SUMS)
printf 'Device IPA: %s\nChecksums: %s\n' "$directory/WoW-Forever-iOS.ipa" "$directory/SHA256SUMS"
