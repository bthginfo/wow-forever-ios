# WoW Forever iOS

**Experimental source port for iPhone and iPad.** [Android release](https://github.com/bthginfo/wow-forever-mobile/releases/tag/v2.4.4-mobile.15)

The project brings the Android launcher's gold-and-navy interface, German and English controls, and Forever Touch add-on to SwiftUI. The device build integrates with a pinned Playport runtime for Wine, FEX and Metal-based graphics. It targets Blizzard's `wowf` product and delegates account sign-in to the game client.

## Features in the port

| Area | Implementation |
| --- | --- |
| Launcher | One main button for download, setup and play, with region selection and 720p/900p/1080p render presets. English or German is suggested from the device language. |
| Touch controls | Movement stick, right-drag camera, Jump, Target and Interact, with a compact phone layout and tablet layout |
| In-game toolbar | Chat, Bags, Map, Character, Talents, Quests, Spellbook, collapsible toolbar, text input and fullscreen controls |
| Editing | Move and save touch-control positions. The shared Forever Touch Lua add-on provides the two skill arcs and per-character spell and item editing. |
| Runtime | Playport supplies the download, update check, Windows guest and input. The Android browser-first Battle.net handoff is pending. |

The app selects the tablet HUD when both window dimensions are at least 600 points. The game resolution is fitted to the current aspect ratio at launch. Playport supplies the in-game keyboard.

## Install and run an IPA on iPhone or iPad

**The first installable iOS IPA is pending.** Once it is available, download **WoW-Forever-iOS.ipa**, open it in AltStore Classic and follow the setup prompts in the app. The source build route is available for developers with the Playport toolchain. [iOS releases](https://github.com/bthginfo/wow-forever-ios/releases) · [Build a device IPA](docs/INSTALL.md#build-an-unsigned-device-ipa)

### 1. Prepare the device and install the app

The Playport-based device build targets **iOS or iPadOS 26.0 and later**. Working JIT depends on the exact OS version and device. Check the pinned runtime's tested combinations before building or signing. You also need an Apple Account for signing and enough storage for the app and the game. [Playport device compatibility](https://github.com/playportdev/playport/blob/06e83ca597b6383e5c5fc60f627892edb560251c/docs/DEVICE.md#known-good-ios-versions)

Pair or connect the device to the computer used for setup. On the device, open **Settings → Privacy & Security → Developer Mode**, turn it on, restart and confirm. The menu appears after the device has been paired for development. [Apple's Developer Mode instructions](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)

| Route | Steps |
| --- | --- |
| Sideload an existing IPA with AltStore Classic on macOS or Windows | Use AltServer to install AltStore Classic on your device. Save the IPA to Files, open **My Apps → +** in AltStore, and select the file. Keep the app extensions if prompted. Playport documents support for **Increased Memory Limit** with AltStore Classic 2.2 or later. [AltStore Classic setup](https://faq.altstore.io/altstore-classic) · [Playport signing tools](https://github.com/playportdev/playport/blob/06e83ca597b6383e5c5fc60f627892edb560251c/docs/DISTRIBUTION.md#6-signing-tools-and-the-memory-limit) |
| Sign an existing IPA with the patched `xtool` on Linux | Set up the Playport signing tools and pair the phone. Use the patched signer to provision the app ID and helper extension, then install the IPA. [Re-sign and install an IPA](docs/INSTALL.md#re-sign-and-install-an-existing-ipa) |
| Try SideStore, Sideloadly or PlumeImpactor with an existing IPA | Follow the sideloader's setup guide and retain the app extensions. Open **Runtime setup** afterward and check that **Memory** is on. The pinned Playport docs cover a SideStore 0.7.0 entitlement issue and its remedy. These routes still need a WoW Forever device test. [SideStore setup](https://docs.sidestore.io/docs/installation/install.html) · [Sideloadly](https://sideloadly.io/) · [PlumeImpactor](https://github.com/khcrysalis/PlumeImpactor) · [Playport memory instructions](https://github.com/playportdev/playport/blob/06e83ca597b6383e5c5fc60f627892edb560251c/README.md#sidestore-when-memory-has-no-tick) |
| Build and install from source on x86-64 Linux | Set up the pinned Playport toolchain and build the device IPA. Sign with your Apple Account and install on the paired device. [Source build commands](docs/INSTALL.md#physical-iphone-or-ipad) |

A free Apple Personal Team can provision up to three apps at a time. Its profiles expire after seven days. Refresh the app with your sideloader or sign and install it again under the same team and bundle ID. With the current Playport app ID, installing over an existing Playport build under the same team upgrades that installation. [Apple's Personal Team limits](https://developer.apple.com/help/account/basics/about-your-developer-account/) · [Playport first-install and refresh guide](https://github.com/playportdev/playport/blob/06e83ca597b6383e5c5fc60f627892edb560251c/docs/DEVICE.md#free-team-limits)

### 2. Set up JIT before pressing Play

The runtime needs JIT to translate the Windows game. After the game download, the main button opens the relevant **Runtime setup** step if a requirement is missing. You can revisit the checklist through **Settings → Setup check**. Verify that **Increased Memory Limit** is enabled. If it is off, re-sign the IPA with a compatible tool and check again. [Playport JIT and setup checks](https://github.com/playportdev/playport/blob/06e83ca597b6383e5c5fc60f627892edb560251c/docs/DEVICE.md#jit-activation)

| JIT method | Setup |
| --- | --- |
| **Built-in** | Install [LocalDevVPN](https://apps.apple.com/app/localdevvpn/id6755608044), open it once and allow its VPN configuration. Keep the IPA's JIT helper extension when signing. On iOS 27, follow the setup screen's pairing-code instructions. On iOS 26, import a device-specific RP pairing file through **Setup check → Import pairing file**. [Playport pairing instructions](https://github.com/playportdev/playport/blob/06e83ca597b6383e5c5fc60f627892edb560251c/docs/DEVICE.md#jit-activation) |
| **StikDebug** | Install and pair StikDebug using its device guide. Select **StikDebug** under **Setup check → JIT method**. Playport requests the `universal.js` script when you start the game. Return to WoW Forever iOS after StikDebug attaches. [StikDebug installation](https://github.com/StikDebug/StikDebug) · [Pairing](https://github.com/StikDebug/StikDebug/blob/main/PAIRING.md) · [Playport JIT methods](https://github.com/playportdev/playport/blob/06e83ca597b6383e5c5fc60f627892edb560251c/docs/ARCHITECTURE.md#jit-methods) |
| **Another app / LiveContainer** | Import the IPA into LiveContainer and choose **Another app** for Playport's JIT method. In StikDebug, assign `universal.js` to **LiveContainer**. Start the game container with **Launch with JIT**. Relaunch it with JIT before the next game session. [LiveContainer](https://github.com/LiveContainer/LiveContainer) · [Playport's LiveContainer setup](https://github.com/playportdev/playport/blob/06e83ca597b6383e5c5fc60f627892edb560251c/docs/DEVICE.md#jit-activation) · [StikDebug scripts](https://github.com/StikDebug/StikDebug/blob/main/SUPPORTED_APPS.md) |

Keep device pairing files and Apple signing credentials private. StikDebug and LiveContainer still need a physical-device test with this port.

### 3. Download WoW Forever and launch it

Choose your region, tap **Download and install**, and leave the app open while it downloads the Windows client from Blizzard. The launcher shows progress and offers **Resume download** if the download is paused. Follow any setup prompt, then tap **Play World of Warcraft** and sign in inside the game using a Battle.net account with WoW Forever access. Use the on-screen toolbar for chat, bags, maps and control editing. The automatic browser sign-in used by the Android release is pending on iOS.

## Tests

GitHub Actions tests the launcher and touch controls on a simulated iPhone 16 Pro and iPad Pro. The first-launch test uses simulated download progress, device and JIT setup, and sign-in. The same workflow checks the Playport input library and the Forever Touch mobile profile logic. Installation, JIT, a real Battle.net sign-in and gameplay on physical devices are pending. [Interaction test reports](https://github.com/bthginfo/wow-forever-ios/actions/workflows/ios-interactions.yml) · [Run the preview locally](docs/INSTALL.md#iphone-simulator)

The iPhoneOS workflow compiles the Playport app target with Xcode and the iPhoneOS SDK. That check covers source compilation before runtime linking, IPA packaging and signing. [iPhoneOS compile reports](https://github.com/bthginfo/wow-forever-ios/actions/workflows/ios-runtime-compile.yml)

## Source, credits and use at your own risk

This is an unofficial community project. Use it at your own risk. World of Warcraft, Battle.net and the associated game content and marks belong to Blizzard Entertainment and the respective rights holders. Blizzard neither sponsors nor supports this port.

The frontend and shared add-on are GPL-3.0. The device recipe uses [Playport](https://github.com/playportdev/playport) at `06e83ca597b6383e5c5fc60f627892edb560251c` and retains its source, license and third-party notices. Playport builds on Madeira, Wine, FEX and Metal graphics projects. The shared add-on and design come from [WoW Forever Mobile](https://github.com/bthginfo/wow-forever-mobile).
