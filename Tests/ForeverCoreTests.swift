// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

@main
enum ForeverCoreTests {
    static func main() {
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
        assert(ForeverShortcut.morePanels.map(\.key) == [0x2d, 0x23, 0x21, 0x22, 0x2e])
        print("Region, render size, layouts, saved positions, movement and add-on shortcuts passed.")
    }
}
