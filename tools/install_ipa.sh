#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
    printf 'Usage: %s /path/to/WoW-Forever-iOS.ipa\n' "$0"
    exit 0
fi
if (( $# != 1 )); then
    printf 'Usage: %s /path/to/WoW-Forever-iOS.ipa\n' "$0" >&2
    exit 2
fi

ipa=$(python3 - "$1" <<'PY'
from pathlib import Path
import plistlib
import sys
import zipfile

path = Path(sys.argv[1]).expanduser().resolve()
try:
    with zipfile.ZipFile(path) as archive:
        info = plistlib.loads(archive.read("Payload/Playport.app/Info.plist"))
        if not isinstance(info, dict) or info.get("CFBundleDisplayName") != "WoW Forever iOS":
            sys.exit("Select the WoW Forever iOS device IPA.")
except (OSError, KeyError, ValueError, zipfile.BadZipFile, plistlib.InvalidFileException):
    sys.exit(f"Could not open a WoW Forever iOS device IPA at {path}.")
print(path)
PY
)

cd "$(dirname "$0")/.."
bash tools/prepare_device.sh
cd .build/playport
. build/env.sh
if [[ ! -x "$XTOOL" || -z ${PLAYPORT_USBMUX_SOCKET:-} ]]; then
    printf '%s\n' 'Complete the pinned Playport signing and pairing setup in docs/INSTALL.md.' >&2
    exit 1
fi

mkdir -p "$PLAYPORT_BUILD"
signing_temp=$(mktemp -d "$PLAYPORT_BUILD/resign.XXXXXX")
trap 'rm -rf -- "$signing_temp"' EXIT
./pp phone lock -- env USBMUXD_SOCKET_ADDRESS="UNIX:$PLAYPORT_USBMUX_SOCKET" \
    XTL_TMPDIR="$signing_temp" TMPDIR="$signing_temp" "$XTOOL" install --network "$ipa"
