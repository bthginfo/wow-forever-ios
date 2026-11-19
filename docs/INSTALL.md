# Build and run WoW Forever iOS

## iPhone Simulator

Use a Mac with Xcode, the iOS 18 or newer simulator runtime and Python 3.

```sh
bash tools/simulator_smoke.sh
```

The script checks the layouts and key bindings, builds the SwiftUI app, boots an available iPhone and captures the launcher and HUD under `.build/simulator/`. The **iOS Simulator** workflow runs the same script on GitHub. In the preview, tap through a simulated download, pause and resume it, complete the simulated runtime setup, and choose **Continue with test account** to open the HUD. The preview needs no Blizzard credentials or game files. A physical device is needed to exercise Wine, JIT, Battle.net login and the in-game skill add-on.

## Build an unsigned device IPA

On x86-64 Linux, clone this repository and configure the host tools, LLVM-MinGW with the ARM64EC CRT, and Darwin SDK from Xcode 26.6 for the pinned Playport build. The build uses your local SDK and compiles the runtime from its pinned sources. [Playport host setup](https://github.com/playportdev/playport/blob/06e83ca597b6383e5c5fc60f627892edb560251c/docs/BUILDING.md) · [Apple Developer Downloads](https://developer.apple.com/download/all/)

```sh
bash tools/build_ipa.sh --preflight
bash tools/build_ipa.sh
```

The preflight checks the actual build inputs. The build command prepares the launcher and add-on, builds the Playport release, verifies the IPA and prints the paths to **WoW-Forever-iOS.ipa** and **SHA256SUMS**. Re-sign the IPA before installing it on a device. For a public release, prepare the corresponding source and notices and follow the pinned Playport distribution procedure. [Re-sign and install](#re-sign-and-install-an-existing-ipa) · [Playport distribution guide](https://github.com/playportdev/playport/blob/06e83ca597b6383e5c5fc60f627892edb560251c/docs/DISTRIBUTION.md)

## Physical iPhone or iPad

Use at your own risk. This experimental port uses Playport's development toolchain. Its device build targets iOS 26.0 or later. Prepare an iPhone or iPad with Developer Mode, a compatible provisioning profile, JIT and enough storage for WoW and the runtime. Check which device and iOS combinations Playport has tested. [Playport device setup](https://github.com/playportdev/playport/blob/06e83ca597b6383e5c5fc60f627892edb560251c/docs/DEVICE.md)

1. Clone this repo and create its separate runtime checkout.

   ```sh
   git clone https://github.com/bthginfo/wow-forever-ios.git
   cd wow-forever-ios
   bash tools/prepare_device.sh
   cd .build/playport
   ```

2. Configure the pinned project's build inputs on Linux. The toolchain needs a Darwin SDK from Xcode, LLVM-MinGW and the dependencies in its build guide. Pair and register your device with your Apple team before signing. For first-time registration, the pinned device guide uses an unsigned release build from `./pp build --variant release --unsigned`. [Playport build inputs](https://github.com/playportdev/playport/blob/06e83ca597b6383e5c5fc60f627892edb560251c/docs/BUILDING.md) · [Device registration](https://github.com/playportdev/playport/blob/06e83ca597b6383e5c5fc60f627892edb560251c/docs/DEVICE.md#free-team-limits)

   Download the Xcode 26.6 archive required by the pinned runtime with your own Apple Account. Import its SDK with `xtool sdk install /path/to/Xcode_26.6.xip --slim`. [Apple Developer Downloads](https://developer.apple.com/download/all/)

3. Configure and compile the development build.

   ```sh
   xtool auth login
   ./pp setup
   ./pp check
   ./pp build
   ```

   Run `./pp install --no-build` to install the build from this checkout onto the paired device. Keep signing credentials and pairing files local. [Playport device pairing and installation](https://github.com/playportdev/playport/blob/06e83ca597b6383e5c5fc60f627892edb560251c/docs/DEVICE.md#setup-once)

   This build uses Playport's development app identifier. Installing it under the same Apple team upgrades that team's existing Playport app in place.

4. Open **WoW Forever iOS** and complete the pairing, JIT and memory checks. Select your region and use **Download and install** when Blizzard offers the product. Leave the app open for the download. [JIT setup and alternatives](../README.md#2-set-up-jit-before-pressing-play)
5. Tap **Play World of Warcraft** and follow the Windows client's Battle.net sign-in. Use the in-game toolbar menu to move controls or edit skills.

## Re-sign and install an existing IPA

This route applies to an **ad hoc or unsigned device IPA** from this project. It requires the prepared Playport checkout, the patched `xtool`, an Apple Account and a paired, unlocked device. Complete the pinned Playport host and pairing setup first. [Patched signer and IPA installation](https://github.com/playportdev/playport/blob/06e83ca597b6383e5c5fc60f627892edb560251c/docs/DISTRIBUTION.md#5-installation-for-the-recipient)

On the Linux host, close the running app on the phone and run these commands from the prepared `.build/playport` checkout. Replace the IPA path with your file.

```bash
ipa=/absolute/path/to/WoW-Forever-iOS.ipa
. build/env.sh
signing_temp="$PLAYPORT_BUILD/resign-tmp"
mkdir -p "$signing_temp"
./pp phone lock -- env USBMUXD_SOCKET_ADDRESS="UNIX:$PLAYPORT_USBMUX_SOCKET" \
  XTL_TMPDIR="$signing_temp" TMPDIR="$signing_temp" \
  "$XTOOL" install --network "$ipa"
```

The patched signer keeps the **Increased Memory Limit** capability and signs the JIT helper. For an IPA you already signed for this device through Playport, use the paired-device install procedure in the upstream guide. If the Apple team reports that it has no registered iOS device, follow Playport's first-registration steps. [Playport device registration and free-team limits](https://github.com/playportdev/playport/blob/06e83ca597b6383e5c5fc60f627892edb560251c/docs/DEVICE.md#free-team-limits)

After installation, check **Runtime setup → Memory** and finish pairing and JIT setup. Use the same team and app ID for profile refreshes. [JIT setup and alternatives](../README.md#2-set-up-jit-before-pressing-play)

## What to check on the device

- Complete startup through character selection and enter the world.
- Move and turn the camera together, then cast a skill while moving.
- Edit and save the skill arcs. Restart the game and verify that the character's layout is restored.
- Open a game panel from the toolbar, paste in chat, minimize the toolbar and switch fullscreen.
- Repeat on a tablet and in a smaller window to check both touch layouts.
