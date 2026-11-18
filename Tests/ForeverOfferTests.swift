// SPDX-License-Identifier: GPL-3.0-or-later
import BattleNetClientKit
import ContentKit
import Foundation
import XCTest

final class ForeverOfferTests: XCTestCase {
    func testProductIsDiscoverableAndItsFolderIsValid() throws {
        let product = try XCTUnwrap(BattleNetProduct(rawValue: "wowf"))
        XCTAssertEqual(product, .wowForever)
        try WindowsName.check(product.name)
    }

    func testBlizzardOffersTheWindowsClient() async throws {
        guard ProcessInfo.processInfo.environment["FOREVER_LIVE_METADATA"] == "1" else {
            throw XCTSkip("Live metadata check is opt-in")
        }
        let client = BattleNetClient(transport: URLSessionTransport())
        let offer = try await client.offer(.wowForever, .eu)
        XCTAssertEqual(offer.build.productConfig.folder, "_forever_")
        XCTAssertEqual(offer.client?.name.lowercased(), "wow.exe")
        let selected = try offer.install.select(.client(offer.build.productConfig, locale: "enUS", regions: [.eu]))
        XCTAssertTrue(selected.contains { $0.name.caseInsensitiveCompare("Wow.exe") == .orderedSame })
        XCTAssertFalse(selected.contains { $0.name.caseInsensitiveCompare("Wow-ARM64.exe") == .orderedSame })
    }
}
