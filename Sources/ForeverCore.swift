// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

enum ForeverLanguage: String, CaseIterable, Identifiable {
    case en, de
    var id: String { rawValue }
    var label: String { self == .de ? "Deutsch" : "English" }
    func text(_ english: String, _ german: String) -> String { self == .de ? german : english }
}

enum ForeverRegion: String, CaseIterable, Identifiable {
    case us, eu, kr, tw
    var id: String { rawValue }

    func label(_ language: ForeverLanguage) -> String {
        switch self {
        case .us: language.text("Americas", "Amerika")
        case .eu: language.text("Europe", "Europa")
        case .kr: language.text("Korea", "Korea")
        case .tw: language.text("Taiwan", "Taiwan")
        }
    }

    static func suggested(for country: String?) -> Self {
        switch country?.uppercased() {
        case "KR": .kr
        case "TW", "HK": .tw
        case "AT", "BE", "CH", "CZ", "DE", "DK", "ES", "FI", "FR", "GB", "GR",
             "IE", "IT", "NL", "NO", "PL", "PT", "RO", "SE", "TR", "UA": .eu
        default: .us
        }
    }
}

enum ForeverResolution: String, CaseIterable, Identifiable {
    case hd = "720"
    case hdPlus = "900"
    case fullHD = "1080"
    var id: String { rawValue }
    var label: String { "\(rawValue)p" }

    func renderPixels(in window: CGSize) -> (Int, Int) {
        let height = Double(rawValue) ?? 900
        let shortSide = min(window.width, window.height)
        let aspect = shortSide > 0 ? Double(max(window.width, window.height) / shortSide) : 16.0 / 9
        let shortRender = sqrt(height * height * 16 / 9 / aspect)
        return (Int((shortRender * aspect / 2).rounded()) * 2, Int((shortRender / 2).rounded()) * 2)
    }
}

struct ForeverOptions: Equatable {
    var language: ForeverLanguage
    var region: ForeverRegion
    var resolution: ForeverResolution
}

enum ForeverControl: String, CaseIterable, Identifiable {
    case movement, camera, jump, target, interact, toolbar
    var id: String { rawValue }

    func label(_ language: ForeverLanguage) -> String {
        switch self {
        case .movement: language.text("Movement", "Bewegung")
        case .camera: language.text("Camera", "Kamera")
        case .jump: language.text("Jump", "Sprung")
        case .target: language.text("Target", "Ziel")
        case .interact: language.text("Interact", "Interagieren")
        case .toolbar: language.text("Toolbar", "Menüleiste")
        }
    }
}

enum ForeverShortcut: Identifiable {
    case chat, bags, map, character, talents, quests, spellbook
    case professions, friends, guild, groupFinder, collections, frameLimit

    static let toolbar: [Self] = [.character, .bags, .map, .professions, .talents, .quests, .spellbook]
    static let social: [Self] = [.friends, .guild, .groupFinder]
    var id: Self { self }

    func label(_ language: ForeverLanguage) -> String {
        switch self {
        case .chat: language.text("Message…", "Nachricht…")
        case .bags: language.text("Bags", "Taschen")
        case .map: language.text("Map", "Karte")
        case .character: language.text("Character", "Charakter")
        case .talents: language.text("Talents", "Talente")
        case .quests: "Quests"
        case .spellbook: language.text("Spellbook", "Zauberbuch")
        case .professions: language.text("Professions", "Berufe")
        case .friends: language.text("Friends", "Freunde")
        case .guild: language.text("Guild", "Gilde")
        case .groupFinder: language.text("Group Finder", "Gruppensuche")
        case .collections: language.text("Collections", "Sammlung")
        case .frameLimit: language.text("30 FPS limit / restore", "30-FPS-Limit ein/aus")
        }
    }

    // These match the secure in-game bindings in the shared Forever Touch add-on.
    var key: UInt8 {
        switch self {
        case .chat: 0x77
        case .bags: 0x78
        case .map: 0x7a
        case .character: 0x72
        case .talents: 0x73
        case .quests: 0x74
        case .spellbook: 0x75
        case .professions: 0x2d
        case .friends: 0x23
        case .guild: 0x21
        case .groupFinder: 0x22
        case .collections: 0x2e
        case .frameLimit: 0x46
        }
    }
}

enum ForeverInput: Equatable {
    case key(UInt8, down: Bool)
    case cameraButton(Bool)
    case cameraMotion(dx: Double, dy: Double)
    case textInput
    case chatInput
    case gameMenu
    case diagnostics
}

struct ForeverLayout {
    var bounds: [ForeverControl: CGRect]

    static func isTablet(_ size: CGSize) -> Bool { min(size.width, size.height) >= 600 }

    init(size: CGSize, positions: [String: CGPoint] = [:]) {
        let width = max(0, size.width)
        let height = max(0, size.height)
        let tablet = Self.isTablet(size)
        let scale = tablet ? min(1, width / 500, height / 200) : min(height, width * 0.96)
        let margin = (tablet ? 20 : 0.035) * scale
        let gap = (tablet ? 10 : 0.018) * scale
        let bottom = height - margin
        let right = width - margin
        let stick = (tablet ? 98 : 0.178) * scale
        let cameraHeight = (tablet ? 76 : 0.17) * scale
        let cameraWidth = tablet ? 148 * scale : min(0.42 * scale, width * 0.26)
        let cameraX = right - cameraWidth
        let jump = (tablet ? 64 : 0.142) * scale
        let jumpX = cameraX - gap - jump
        let auxWidth = (tablet ? 92 : 0.174) * scale
        let auxHeight = tablet ? 46 * scale : (cameraHeight - gap) / 2
        let auxX = tablet ? margin + stick + gap : jumpX - gap - auxWidth
        let interactY = bottom - auxHeight
        let targetY = tablet ? interactY - 54 * scale : bottom - cameraHeight

        bounds = [
            .movement: CGRect(x: margin, y: bottom - stick, width: stick, height: stick),
            .camera: CGRect(x: cameraX, y: bottom - cameraHeight, width: cameraWidth, height: cameraHeight),
            .jump: CGRect(x: jumpX, y: bottom - jump, width: jump, height: jump),
            .target: CGRect(x: auxX, y: targetY, width: auxWidth, height: auxHeight),
            .interact: CGRect(x: auxX, y: interactY, width: auxWidth, height: auxHeight)
        ]
        for key in ForeverControl.allCases {
            guard let rect = bounds[key], let position = positions[key.rawValue] else { continue }
            bounds[key] = Self.place(rect, at: position, in: size)
        }
    }

    static func place(_ rect: CGRect, at position: CGPoint, in size: CGSize) -> CGRect {
        CGRect(x: max(0, size.width - rect.width) * clamped(position.x),
               y: max(0, size.height - rect.height) * clamped(position.y),
               width: rect.width, height: rect.height)
    }

    static func position(rect: CGRect, center: CGPoint, size: CGSize) -> CGPoint {
        let xTravel = size.width - rect.width
        let yTravel = size.height - rect.height
        return CGPoint(x: xTravel > 0 ? clamped((center.x - rect.width / 2) / xTravel) : 0.5,
                       y: yTravel > 0 ? clamped((center.y - rect.height / 2) / yTravel) : 0.5)
    }

    private static func clamped(_ n: CGFloat) -> CGFloat { n.isFinite ? min(1, max(0, n)) : 0.5 }
}

enum ForeverKeys {
    static let control: UInt8 = 0xa2
    static let shift: UInt8 = 0xa0
    static let editSkills: UInt8 = 0x76
    static let saveSkills: UInt8 = 0x70
    static let cancelSkills: UInt8 = 0x71
    static let resetSkills: UInt8 = 0x24
    static let openChatFullscreen: UInt8 = 0x4D
    static let closeChatFullscreen: UInt8 = 0x43

    static func press(_ key: UInt8, modified: Bool = false) -> [ForeverInput] {
        let tap: [ForeverInput] = [.key(key, down: true), .key(key, down: false)]
        guard modified else { return tap }
        return [.key(control, down: true), .key(shift, down: true)] + tap +
            [.key(shift, down: false), .key(control, down: false)]
    }

    static func movement(_ delta: CGSize, radius: CGFloat, held: Set<UInt8>) -> Set<UInt8> {
        guard radius > 0 else { return [] }
        let x = min(1, max(-1, delta.width / radius))
        let y = min(1, max(-1, delta.height / radius))
        let deadZone = held.isEmpty ? 0.19 : 0.12
        if hypot(x, y) < deadZone { return [] }
        let xKey: UInt8 = x < 0 ? 0x51 : 0x45
        let yKey: UInt8 = y < 0 ? 0x57 : 0x53
        var keys: Set<UInt8> = []
        if abs(x) > abs(y) * (held.contains(xKey) ? 0.39 : 0.58) { keys.insert(xKey) }
        if abs(y) > abs(x) * (held.contains(yKey) ? 0.39 : 0.58) { keys.insert(yKey) }
        return keys
    }
}

func checkpointForeverTouchProfiles(in gameRoot: URL) throws {
    let wtf = gameRoot.appendingPathComponent("_forever_/WTF", isDirectory: true)
    let accounts = wtf.appendingPathComponent("Account", isDirectory: true)
    let checkpoints = wtf.appendingPathComponent(".forever-touch", isDirectory: true)
    let fileManager = FileManager.default

    func paths(in directory: URL) -> Set<String> {
        let properties: [URLResourceKey] = [.isSymbolicLinkKey, .isRegularFileKey]
        guard let tree = fileManager.enumerator(at: directory, includingPropertiesForKeys: properties) else { return [] }
        var paths = Set<String>()
        for case let url as URL in tree {
            let parts = url.pathComponents.dropFirst(directory.pathComponents.count)
            if tree.level >= 5 { tree.skipDescendants() }
            let info = try? url.resourceValues(forKeys: Set(properties))
            if info?.isSymbolicLink == true {
                tree.skipDescendants()
                continue
            }
            guard parts.count == 3 || parts.count == 5, url.deletingLastPathComponent().lastPathComponent == "SavedVariables",
                  info?.isRegularFile == true else { continue }
            if url.lastPathComponent == "ForeverTouch.lua" {
                paths.insert(parts.joined(separator: "/"))
            } else if url.lastPathComponent == "ForeverTouch.lua.bak" {
                paths.insert(String(parts.joined(separator: "/").dropLast(4)))
            }
        }
        return paths
    }

    func readProfile(_ url: URL) -> Data? {
        guard let bytes = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              bytes > 0 && bytes <= 8 * 1024 * 1024,
              let data = try? Data(contentsOf: url),
              let body = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{FEFF}"))),
              body.hasSuffix("}"),
              body.hasPrefix("ForeverTouchProfiles = {") || body.hasPrefix("ForeverTouchPreferences = {")
        else { return nil }
        return data
    }

    func write(_ value: Data, to url: URL) throws {
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try value.write(to: url, options: .atomic)
    }

    func modified(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    for path in paths(in: accounts).union(paths(in: checkpoints)) {
        let current = accounts.appendingPathComponent(path)
        let saved = checkpoints.appendingPathComponent(path)
        let backup = current.appendingPathExtension("bak")
        guard current.resolvingSymlinksInPath().path.hasPrefix(accounts.path + "/"),
              backup.resolvingSymlinksInPath().path.hasPrefix(accounts.path + "/"),
              saved.resolvingSymlinksInPath().path.hasPrefix(checkpoints.path + "/") else { continue }
        let data: Data?
        if let size = try? current.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 0 {
            data = readProfile(current)
        } else {
            data = [backup, saved].sorted { modified($0) > modified($1) }.lazy.compactMap(readProfile).first
            if let data { try write(data, to: current) }
        }
        if let data, readProfile(saved) != data { try write(data, to: saved) }
    }
}
