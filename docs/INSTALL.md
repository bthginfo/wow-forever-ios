# Build and run WoW Forever iOS

## iPhone Simulator

Use a Mac with Xcode, the iOS 18 or newer simulator runtime and Python 3.

```sh
bash tools/simulator_smoke.sh
```

The script checks the layouts and key bindings, builds the SwiftUI app, boots an available iPhone and captures the launcher and HUD under `.build/simulator/`. The **iOS Simulator** workflow runs the same script on GitHub. The preview uses the production SwiftUI views with simulated game state. A physical device is needed to exercise Wine, JIT, Battle.net login and the in-game skill add-on.

## Physical iPhone or iPad

Use at your own risk. This experimental port uses Playport's development toolchain. Prepare a supported iPhone or iPad with Developer Mode, a compatible provisioning profile, JIT and enough storage for WoW and the runtime. Check the pinned project's requirements for your device and iOS version. [Playport device setup](https://github.com/playportdev/playport/blob/06e83ca597b6383e5c5fc60f627892edb560251c/docs/DEVICE.md)

1. Clone this repo and create its separate runtime checkout.

   ```sh
   bash tools/prepare_device.sh
   cd .build/playport
   ```

2. Configure the pinned project's build inputs on Linux. The toolchain needs a Darwin SDK from Xcode, LLVM-MinGW and the dependencies in its build guide. [Playport build inputs](https://github.com/playportdev/playport/blob/06e83ca597b6383e5c5fc60f627892edb560251c/docs/BUILDING.md)

3. Configure and compile the development build.

   ```sh
   ./pp setup
   ./pp check
   ./pp build
   ```

   Follow the development signing and installation process for your device. Keep signing credentials and pairing files local. [Playport distribution and signing](https://github.com/playportdev/playport/blob/06e83ca597b6383e5c5fc60f627892edb560251c/docs/DISTRIBUTION.md#5-installation-for-the-recipient)

4. Open **WoW Forever iOS**, complete runtime setup, select your region and use **Download and install** when Blizzard offers the product. Leave the app open for the download.
5. Tap **Play World of Warcraft** and follow the Windows client's Battle.net sign-in. Use the in-game toolbar menu to move controls or edit skills.

### What to check on the device

- Complete startup through character selection and enter the world.
- Move and turn the camera together, then cast a skill while moving.
- Edit and save the skill arcs. Restart the game and verify that the character's layout is restored.
- Open a game panel from the toolbar, paste in chat, minimize the toolbar and switch fullscreen.
- Repeat on a tablet and in a smaller window to check both touch layouts.
