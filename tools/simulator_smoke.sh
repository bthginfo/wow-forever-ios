#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
cd "$(dirname "$0")/.."
output="$PWD/.build/simulator"
product="ForeverSimulator"
identifier="app.wowforever.ios.simulator"
app="$output/$product.app"
mkdir -p "$app"

xcrun swiftc -swift-version 5 Sources/ForeverCore.swift Tests/ForeverCoreTests.swift -o "$output/core-tests"
"$output/core-tests"

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

device=$(xcrun simctl list devices available -j | python3 -c '
import json
import sys

devices = json.load(sys.stdin)["devices"]
for runtime in sorted(devices, reverse=True):
    if "SimRuntime.iOS-" in runtime and int(runtime.split("iOS-")[1].split("-")[0]) >= 18:
        for phone in devices[runtime]:
            if phone["name"].startswith("iPhone") and phone["isAvailable"]:
                print(phone["udid"])
                raise SystemExit(0)
raise SystemExit("No iOS 18+ iPhone Simulator available")
')
xcrun simctl bootstatus "$device" -b
xcrun simctl install "$device" "$app"
xcrun simctl launch --terminate-running-process "$device" "$identifier"
sleep 2
xcrun simctl io "$device" screenshot "$output/launcher.png"
xcrun simctl launch --terminate-running-process "$device" "$identifier" --hud
sleep 2
xcrun simctl io "$device" screenshot "$output/hud.png"
test -s "$output/launcher.png"
test -s "$output/hud.png"
