#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
cd "$(dirname "$0")/.."
output="$PWD/.build/simulator"
product="ForeverSimulator"
identifier="app.wowforever.ios.simulator"
app="$output/$product.app"
phase="${1:-all}"
case "$phase" in
    all|build|run) ;;
    *) printf 'Usage: %s [build|run]\n' "$0" >&2; exit 2 ;;
esac
mkdir -p "$app"

if [[ "$phase" != run ]]; then
    printf 'Building host layout tests\n'
    xcrun swiftc -swift-version 5 Sources/ForeverCore.swift Tests/ForeverCoreTests.swift -o "$output/core-tests"
    "$output/core-tests"
    xcrun swiftc -frontend -parse Sources/ForeverPlayport.swift

    printf 'Building the iOS Simulator app\n'
    sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
    xcrun --sdk iphonesimulator swiftc -swift-version 5 -target "$(uname -m)-apple-ios18.0-simulator" \
        -sdk "$sdk" -module-name "$product" Sources/ForeverCore.swift Sources/ForeverLauncher.swift \
        Sources/ForeverOverlay.swift Simulator/ForeverSimulator.swift -o "$app/$product"

    python3 - "$app/Info.plist" "$product" "$identifier" <<'PYTHON'
import plistlib
import sys

path, product, identifier = sys.argv[1:]
with open(path, "wb") as output:
    plistlib.dump({
        "CFBundleDevelopmentRegion": "en",
        "CFBundleDisplayName": "WoW Forever iOS",
        "CFBundleExecutable": product,
        "CFBundleIdentifier": identifier,
        "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": "0.1",
        "CFBundleVersion": "1",
        "CFBundleSupportedPlatforms": ["iPhoneSimulator"],
        "LSRequiresIPhoneOS": True,
        "MinimumOSVersion": "18.0",
        "UIDeviceFamily": [1, 2],
        "UILaunchScreen": {},
        "UISupportedInterfaceOrientations": [
            "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"
        ],
    }, output)
PYTHON
    codesign --force --sign - "$app"
fi
[[ "$phase" != build ]] || exit 0
test -x "$app/$product"

sdk_version=$(xcrun --sdk iphonesimulator --show-sdk-version)
printf 'Looking for an iPhone Simulator for SDK %s\n' "$sdk_version"
device_info=$(xcrun simctl list devices available -j | python3 -c '
import json
import re
import sys

devices = json.load(sys.stdin)["devices"]
sdk = tuple(map(int, sys.argv[1].split(".")[:2]))
versions = []
for runtime, phones in devices.items():
    match = re.search(r"\.SimRuntime\.iOS-(\d+)-(\d+)(?:-(\d+))?", runtime)
    if match:
        version = tuple(int(value or 0) for value in match.groups())
        versions.append((version, not runtime[match.end():], phones))
for version, _, phones in sorted(versions, key=lambda item: (item[0][:2] == sdk, item[0], item[1]), reverse=True):
    if version[0] < 18:
        continue
    for phone in phones:
        if phone["name"].startswith("iPhone") and phone["isAvailable"]:
            print(phone["udid"])
            raise SystemExit(0)
raise SystemExit("No iOS 18+ iPhone Simulator available")
' "$sdk_version")
device="$device_info"
printf 'Booting iPhone Simulator %s\n' "$device"
xcrun simctl bootstatus "$device" -b
printf 'Launching the SwiftUI preview\n'
xcrun simctl install "$device" "$app"
xcrun simctl launch --terminate-running-process "$device" "$identifier"
sleep 2
xcrun simctl io "$device" screenshot "$output/launcher.png"
xcrun simctl launch --terminate-running-process "$device" "$identifier" --hud
sleep 2
xcrun simctl io "$device" screenshot "$output/hud.png"
test -s "$output/launcher.png"
test -s "$output/hud.png"
