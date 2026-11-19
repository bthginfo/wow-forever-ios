#!/usr/bin/env python3
"""Stage the iOS launcher and add-on in a separate, pinned Playport checkout."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]
PIN = "06e83ca597b6383e5c5fc60f627892edb560251c"


def git(checkout: Path, *arguments: str) -> str:
    return subprocess.check_output(("git", "-C", str(checkout), *arguments), text=True).rstrip("\n")


def applied(source: str, old: str, new: str, path: str) -> str:
    if source.count(old) != 1:
        raise ValueError(f"Unexpected {path} at the pinned commit")
    return source.replace(old, new, 1)


def port_changes(checkout: Path) -> dict[str, tuple[bytes | None, bytes]]:
    changes: dict[str, tuple[bytes | None, bytes]] = {}

    def edit(path: str, *edits: tuple[str, str]) -> None:
        original = subprocess.check_output(("git", "-C", str(checkout), "show", f"{PIN}:{path}"))
        updated = original.decode("utf-8")
        for old, new in edits:
            updated = applied(updated, old, new, path)
        changes[path] = (original, updated.encode("utf-8"))

    edit(
        "app/ContentKit/Sources/ContentKit/Hashes.swift",
        (
            """                    c = t[7 * 256 + Int(lo & 0xFF)] ^ t[6 * 256 + Int((lo >> 8) & 0xFF)]
                        ^ t[5 * 256 + Int((lo >> 16) & 0xFF)] ^ t[4 * 256 + Int(lo >> 24)]
                        ^ t[3 * 256 + Int(hi & 0xFF)] ^ t[2 * 256 + Int((hi >> 8) & 0xFF)]
                        ^ t[256 + Int((hi >> 16) & 0xFF)] ^ t[Int(hi >> 24)]""",
            """                    let lo0 = t[7 * 256 + Int(lo & 0xFF)]
                    let lo1 = t[6 * 256 + Int((lo >> 8) & 0xFF)]
                    let lo2 = t[5 * 256 + Int((lo >> 16) & 0xFF)]
                    let lo3 = t[4 * 256 + Int(lo >> 24)]
                    let hi0 = t[3 * 256 + Int(hi & 0xFF)]
                    let hi1 = t[2 * 256 + Int((hi >> 8) & 0xFF)]
                    let hi2 = t[256 + Int((hi >> 16) & 0xFF)]
                    let hi3 = t[Int(hi >> 24)]
                    let low = (lo0 ^ lo1) ^ (lo2 ^ lo3)
                    let high = (hi0 ^ hi1) ^ (hi2 ^ hi3)
                    c = low ^ high""",
        ),
    )
    edit(
        "app/GOGClient/Sources/GOGClientKit/GalaxyListener.swift",
        ("            let fds = [listenFD] + Array(connections)",
         "            let fds = [listenFD] + Array(self.connections)"),
    )
    edit(
        "app/PlayportKit/Sources/PlayportKit/Catalog.swift",
        ("    private var storeRaw: Store? = nil", "    var storeRaw: Store? = nil"),
    )
    edit(
        "app/PlayportKit/Sources/PlayportKit/ActionPicker.swift",
        (
            r"""    static let keyboard: [[(UInt8, String, Double)]] = [
        [(0x1B, "Esc", 1.2)] + (0..<12).map { (UInt8(0x70 + $0), "F\($0 + 1)", 1) },
        [(0xC0, "`", 1)] + Array("1234567890").map { (UInt8($0.asciiValue!), String($0), 1) }
            + [(0xBD, "-", 1), (0xBB, "=", 1), (0x08, "⌫", 1.4)],
        [(0x09, "Tab", 1.4)] + Array("QWERTYUIOP").map { (UInt8($0.asciiValue!), String($0), 1) }
            + [(0xDB, "[", 1), (0xDD, "]", 1), (0xDC, "\\", 1)],
        [(0x14, "Caps", 1.6)] + Array("ASDFGHJKL").map { (UInt8($0.asciiValue!), String($0), 1) }
            + [(0xBA, ";", 1), (0xDE, "'", 1), (0x0D, "Enter", 1.6)],
        [(0xA0, "Shift", 2)] + Array("ZXCVBNM").map { (UInt8($0.asciiValue!), String($0), 1) }
            + [(0xBC, ",", 1), (0xBE, ".", 1), (0xBF, "/", 1), (0xA1, "Shift", 1.6)],
        [(0xA2, "Ctrl", 1.3), (0xA4, "Alt", 1.2), (0x20, "Space", 6), (0xA5, "Alt", 1.2),
         (0x25, "←", 1), (0x26, "↑", 1), (0x28, "↓", 1), (0x27, "→", 1)],
    ]""",
            r"""    static let keyboard: [[(UInt8, String, Double)]] = {
        typealias Key = (UInt8, String, Double)
        func characters(_ value: String) -> [Key] {
            value.map { ($0.asciiValue!, String($0), 1) }
        }
        let functionKeys: [Key] = (0..<12).map { (UInt8(0x70 + $0), "F\($0 + 1)", 1) }
        let functionRow: [Key] = [(0x1B, "Esc", 1.2)] + functionKeys
        let numberRow: [Key] = [(0xC0, "`", 1)] + characters("1234567890")
            + [(0xBD, "-", 1), (0xBB, "=", 1), (0x08, "⌫", 1.4)]
        let topRow: [Key] = [(0x09, "Tab", 1.4)] + characters("QWERTYUIOP")
            + [(0xDB, "[", 1), (0xDD, "]", 1), (0xDC, "\\", 1)]
        let homeRow: [Key] = [(0x14, "Caps", 1.6)] + characters("ASDFGHJKL")
            + [(0xBA, ";", 1), (0xDE, "'", 1), (0x0D, "Enter", 1.6)]
        let bottomRow: [Key] = [(0xA0, "Shift", 2)] + characters("ZXCVBNM")
            + [(0xBC, ",", 1), (0xBE, ".", 1), (0xBF, "/", 1), (0xA1, "Shift", 1.6)]
        let modifierRow: [Key] = [(0xA2, "Ctrl", 1.3), (0xA4, "Alt", 1.2), (0x20, "Space", 6), (0xA5, "Alt", 1.2),
                                 (0x25, "←", 1), (0x26, "↑", 1), (0x28, "↓", 1), (0x27, "→", 1)]
        return [functionRow, numberRow, topRow, homeRow, bottomRow, modifierRow]
    }()""",
        ),
    )
    edit(
        "app/BattleNetClient/Sources/BattleNetClientKit/BattleNetProducts.swift",
        ('    case wowAnniversary = "wow_anniversary"', '    case wowAnniversary = "wow_anniversary"\n    case wowForever = "wowf"'),
        ('        case .wow: return "World of Warcraft"', '        case .wow: return "World of Warcraft"\n        case .wowForever: return "World of Warcraft Forever"'),
    )
    edit(
        "app/BattleNetClient/Sources/BattleNetClientKit/BattleNetArt.swift",
        ("        switch p {",
         '        switch p {\n        case .wowForever: return ("blt766f7698aedb7b7f/6a9bc5882437ed5612d4878f/Open_Graph_-_Camelot.jpg", nil)'),
    )
    edit(
        "app/Sources/S1Probe/UI/AppShell.swift",
        ("            case .home: HomeView(installs: model.installs)",
         "            case .home: ForeverRuntimeHome(installs: model.installs)"),
    )
    edit(
        "app/Sources/S1Probe/UI/SetupView.swift",
        ('        firstRun = true\n        Self.log("first run: the checklist")',
         '        firstRun = true\n        skip(.steam)\n        Self.log("first run: the checklist")'),
    )
    edit(
        "app/Sources/S1Probe/UI/BattleNetStore.swift",
        ("    func loadSizes(_ p: BattleNetProduct) async {",
         "    func loadSizes(_ p: BattleNetProduct, force: Bool = false) async {"),
        (r'            if listings.first(where: { $0.product == p && $0.region == r }) == nil || offers["\(p.code)/\(r.rawValue)"] == nil {',
         r'            if force || listings.first(where: { $0.product == p && $0.region == r }) == nil || offers["\(p.code)/\(r.rawValue)"] == nil {'),
        ("            let locale = self.locale(p)\n            guard let i",
         "            if region(p) == r { sizeErrors[p] = nil }\n            let locale = self.locale(p)\n            guard let i"),
    )
    edit(
        "app/Sources/S1Probe/UI/LibraryModel.swift",
        (
            "            settings.graphics = bnet.graphics",
            """            if t.key == BattleNet.key(ForeverRuntime.product) {
                try ForeverRuntime.installAddon(in: Self.paths.games.appendingPathComponent(t.installDir, isDirectory: true))
                var controls = ControlsStore.shared.game(id)
                controls.layout = .off
                ControlsStore.shared.setGame(id, controls)
            }
            settings.graphics = bnet.graphics""",
        ),
    )
    edit(
        "app/Sources/S1Probe/UI/Pad/PadTheme.swift",
        ("            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { MainActor.assumeIsolated { WindowInsets.shared.read() } }",
         "            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {\n"
         "                MainActor.assumeIsolated { _ = WindowInsets.shared.read() }\n"
         "            }"),
    )
    edit(
        "app/Sources/S1Probe/HostIO.swift",
        ("    private func send(_ o: MixerOutput) {",
         "    func sendForeverInput(_ output: MixerOutput) { send(output) }\n\n    private func send(_ o: MixerOutput) {"),
    )
    edit(
        "app/Sources/S1Probe/PlayportApp.swift",
        ("    @State private var pageGone = false", '    @State private var pageGone = false\n    @AppStorage("forever.fullscreen") private var foreverFullscreen = true'),
        (
            "                    // The text bar over the running game",
            """                    .overlay {
                        if launch.titleID == ForeverRuntime.titleID && !launch.showsSheet &&
                            !textBar.isOpen && !menu.isOpen && !menu.quitting && !web.isUp {
                            ForeverOverlay(input: ForeverRuntime.deliver)
                        }
                    }
                    // The text bar over the running game""",
        ),
        (
            "                    .statusBarHidden().persistentSystemOverlays(.hidden)\n                    // A swipe",
            """                    .statusBarHidden(launch.titleID != ForeverRuntime.titleID || foreverFullscreen)
                    .persistentSystemOverlays(launch.titleID != ForeverRuntime.titleID || foreverFullscreen ? .hidden : .automatic)
                    // A swipe""",
        ),
    )
    edit("app/Info.plist", ("<string>Playport</string>", "<string>WoW Forever iOS</string>"))
    edit("app/xtool.yml", ("\nresources:\n", "\nresources:\n  - ForeverTouch\n"))
    edit(
        "build/stages/stage-artifacts.py",
        ('"PlayportJIT-Info.plist", "S1Probe.entitlements"]',
         '"PlayportJIT-Info.plist", "S1Probe.entitlements", "ForeverTouch"]'),
    )
    # The release staging directory symlinks the named top-level package resources.
    for path in sorted((ROOT / "Sources").glob("*.swift")):
        changes[f"app/Sources/S1Probe/Forever/{path.name}"] = (None, path.read_bytes())
    for path in sorted((ROOT / "ForeverTouch").iterdir()):
        if path.is_file():
            changes[f"app/ForeverTouch/{path.name}"] = (None, path.read_bytes())
    return changes


def prepare(checkout: Path) -> None:
    if git(checkout, "rev-parse", "HEAD") != PIN:
        raise ValueError(f"Expected Playport {PIN}; use a separate checkout")
    changes = port_changes(checkout)
    marker = Path(git(checkout, "rev-parse", "--absolute-git-dir")) / "forever-port-files.json"
    previous = json.loads(marker.read_text()) if marker.is_file() else {}
    # Validate the whole set before writing, so an unrelated edit never leaves a partial port.
    for name, (original, prepared) in changes.items():
        target = checkout / name
        current = target.read_bytes() if target.is_file() else None
        digest = hashlib.sha256(current).hexdigest() if current is not None else None
        if current not in (original, prepared) and digest != previous.get(name):
            raise ValueError(f"Local changes in {name}; use a separate runtime checkout")
    for name, (_, prepared) in changes.items():
        target = checkout / name
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.is_file() or target.read_bytes() != prepared:
            target.write_bytes(prepared)
    marker.write_text(json.dumps({name: hashlib.sha256(contents).hexdigest()
                                  for name, (_, contents) in changes.items()}, indent=2) + "\n")
    print(f"Prepared {len(changes)} files in the Playport checkout.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("checkout", type=Path)
    args = parser.parse_args()
    prepare(args.checkout.resolve())
