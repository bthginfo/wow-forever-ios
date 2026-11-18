// SPDX-License-Identifier: GPL-3.0-or-later
import BattleNetClientKit
import ContentKit
import Foundation

@main
enum ForeverOfferCheck {
    static func main() async throws {
        precondition(BattleNetProduct(rawValue: "wowf") == .wowForever, "The Forever product is missing")
        try WindowsName.check(BattleNetProduct.wowForever.name)
        print("The Forever product and its Windows install folder passed.")

        guard ProcessInfo.processInfo.environment["FOREVER_LIVE_METADATA"] == "1" else {
            return
        }
        let client = BattleNetClient(transport: URLSessionTransport())
        let offer = try await client.offer(.wowForever, .eu)
        precondition(offer.build.productConfig.folder == "_forever_", "Unexpected client subfolder")
        precondition(offer.client?.name.lowercased() == "wow.exe", "The CDN does not offer the x64 client")
        let selected = try offer.install.select(.client(offer.build.productConfig, locale: "enUS", regions: [.eu]))
        let executables = selected.map { $0.name.lowercased() }.filter { $0 == "wow.exe" || $0 == "wow-arm64.exe" }
        precondition(executables == ["wow.exe"], "Unexpected Windows game executables: \(executables)")
        print("Blizzard EU build \(offer.build.version.versionsName) selects Wow.exe for the x64 install.")
    }
}
