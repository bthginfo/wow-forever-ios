// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

@main
enum ForeverCoreTests {
    static func main() throws {
        assert(ForeverRegion.suggested(for: "DE") == .eu)
        assert(ForeverRegion.suggested(for: "hk") == .tw)
        assert(ForeverRegion.suggested(for: nil) == .us)

        let phone = CGSize(width: 844, height: 390)
        let tablet = CGSize(width: 1180, height: 820)
        let bigTablet = CGSize(width: 1366, height: 1024)
        let split = CGSize(width: 550, height: 820)
        assert(!ForeverLayout.isTablet(phone))
        assert(!ForeverLayout.isTablet(split))
        assert(ForeverLayout.isTablet(tablet))
        let phoneLayout = ForeverLayout(size: phone)
        let tabletLayout = ForeverLayout(size: tablet)
        assert(phoneLayout.bounds[.interact]!.midX > phone.width / 2)
        assert(tabletLayout.bounds[.interact]!.midX < tablet.width / 2)
        assert(tabletLayout.bounds[.camera]!.size == ForeverLayout(size: bigTablet).bounds[.camera]!.size)
        for size in [phone, tablet, bigTablet, split] {
            let bounds = Array(ForeverLayout(size: size).bounds.values)
            for (i, rect) in bounds.enumerated() {
                assert(CGRect(origin: .zero, size: size).contains(rect))
                assert(!bounds.dropFirst(i + 1).contains { rect.intersects($0) })
            }
        }
        let move = ForeverLayout(size: phone, positions: [ForeverControl.camera.rawValue: .zero])
        assert(move.bounds[.camera]!.origin == .zero)

        let pixels = ForeverResolution.hdPlus.renderPixels(in: CGSize(width: 2560, height: 1600))
        assert(pixels.0 == 1518 && pixels.1 == 948)
        assert(ForeverKeys.movement(CGSize(width: 0, height: -0.1), radius: 20, held: []).isEmpty)
        assert(ForeverKeys.movement(CGSize(width: 20, height: -20), radius: 20, held: []) == [0x45, 0x57])
        assert(ForeverKeys.press(ForeverShortcut.bags.key, modified: true) == [
            .key(0xa2, down: true), .key(0xa0, down: true), .key(0x78, down: true),
            .key(0x78, down: false), .key(0xa0, down: false), .key(0xa2, down: false)
        ])
        assert(ForeverShortcut.social.map(\.key) == [0x23, 0x21, 0x22])
        assert(ForeverShortcut.toolbar.contains(.professions))
        assert(ForeverShortcut.frameLimit.key == 0x46)
        try checkProfileRecovery()
        print("Region, render size, layouts, saved positions, movement, add-on shortcuts and profile recovery passed.")
    }

    private static func checkProfileRecovery() throws {
        let files = FileManager.default
        let sandbox = files.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let game = sandbox.appendingPathComponent("WoW", isDirectory: true)
        let root = sandbox.appendingPathComponent("Linked WoW", isDirectory: true)
        let wtf = root.appendingPathComponent("_forever_/WTF", isDirectory: true)
        let profilePath = "Account1/Realm/Player/SavedVariables/ForeverTouch.lua"
        let current = wtf.appendingPathComponent("Account/\(profilePath)")
        let saved = wtf.appendingPathComponent(".forever-touch/\(profilePath)")
        defer { try? files.removeItem(at: sandbox) }
        try files.createDirectory(at: game, withIntermediateDirectories: true)
        try files.createSymbolicLink(at: root, withDestinationURL: game)
        try files.createDirectory(at: current.deletingLastPathComponent(), withIntermediateDirectories: true)
        let layout = Data("ForeverTouchPreferences = { revision = 8, mobileSlots = { left = {} } }\n".utf8)
        try layout.write(to: current)
        try checkpointForeverTouchProfiles(in: root)
        let checkpoint = try Data(contentsOf: saved)
        assert(checkpoint == layout, "The checkpoint must exist before the original profile is lost")

        try files.removeItem(at: current)
        try checkpointForeverTouchProfiles(in: root)
        let restored = try Data(contentsOf: current)
        assert(restored == layout, "Recovery must use the persisted profile from the same WoW folder")

        let outside = sandbox.appendingPathComponent("Outside.lua")
        try layout.write(to: outside)
        try files.removeItem(at: current)
        try files.createSymbolicLink(at: current, withDestinationURL: outside)
        try checkpointForeverTouchProfiles(in: root)
        let attributes = try files.attributesOfItem(atPath: current.path)
        assert(attributes[.type] as? FileAttributeType == .typeSymbolicLink, "Recovery must skip linked profile files")
    }
}
