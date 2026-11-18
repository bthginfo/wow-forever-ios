# WoW Forever iOS

**Experimental source port for iPhone and iPad.** A signed device IPA and an end-to-end WoW Forever play test are pending. [Android release](https://github.com/bthginfo/wow-forever-mobile/releases/tag/v2.4.4-mobile.15)

The project brings the Android launcher's gold-and-navy interface, German and English controls, and Forever Touch add-on to SwiftUI. The device build integrates with a pinned Playport runtime for Wine, FEX and Metal-based graphics. It targets Blizzard's `wowf` product and delegates account sign-in to the game client.

## Features in the port

| Area | Implementation |
| --- | --- |
| Launcher | Status panel, Battle.net region, 720p/900p/1080p render presets and English/German interface |
| Touch controls | Movement stick, right-drag camera, Jump, Target and Interact, with a compact phone layout and tablet layout |
| In-game toolbar | Chat, Bags, Map, Character, Talents, Quests, Spellbook, collapsible toolbar, text input and fullscreen controls |
| Editing | Move and save touch-control positions. The shared Forever Touch Lua add-on provides the two skill arcs and per-character spell and item editing. |
| Runtime | Playport supplies the download, update check, Windows guest and input. The Android browser-first Battle.net handoff is pending. |

The app selects the tablet HUD when both window dimensions are at least 600 points. The game resolution is fitted to the current aspect ratio at launch. Playport supplies the in-game keyboard.

## Installation and testing

- [Run the SwiftUI app in an iPhone Simulator](docs/INSTALL.md#iphone-simulator). The simulator target starts the launcher and controls against a preview surface.
- [Build and install a device development build](docs/INSTALL.md#physical-iphone-or-ipad). Device builds require the pinned Playport toolchain, Apple provisioning and working JIT on the device.

Use a Blizzard account with access to WoW Forever. The repository contains the launcher and add-on source. The game client and assets are delivered by Blizzard.

## Source, credits and use at your own risk

This is an unofficial community project. Use it at your own risk. World of Warcraft, Battle.net and the associated game content and marks belong to Blizzard Entertainment and the respective rights holders. Blizzard neither sponsors nor supports this port.

The frontend and shared add-on are GPL-3.0. The device recipe uses [Playport](https://github.com/playportdev/playport) at `06e83ca597b6383e5c5fc60f627892edb560251c` and retains its source, license and third-party notices. Playport builds on Madeira, Wine, FEX and Metal graphics projects. The shared add-on and design come from [WoW Forever Mobile](https://github.com/bthginfo/wow-forever-mobile).
