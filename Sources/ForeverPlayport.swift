// SPDX-License-Identifier: GPL-3.0-or-later
// Compiled as part of the pinned Playport app by tools/prepare_runtime.py.
import BattleNetClientKit
import Foundation
import HostIOKit
import PlayportKit
import SwiftUI
import UIKit

@MainActor
enum ForeverRuntime {
    static let product = BattleNetProduct.wowForever
    static let titleID = BattleNet.key(product).titleID
    private static var motion = RelativeMotion()

    static func deliver(_ event: ForeverInput) {
        switch event {
        case let .key(key, down):
            HostIO.shared.sendForeverInput(.key(key, down: down))
        case let .cameraButton(down):
            motion.reset()
            HostIO.shared.sendForeverInput(.pointer(flags: down ? Pointer.rightDown : Pointer.rightUp, data: 0))
        case let .cameraMotion(dx, dy):
            if let (x, y) = motion.add(dx: dx, dy: dy) {
                HostIO.shared.sendForeverInput(.move(dx: x, dy: y))
            }
        case .textInput:
            GameTextBar.shared.open()
        case .gameMenu:
            _ = InGameMenu.shared.open()
        case .diagnostics:
            let launch = TitleLaunch.shared
            let title = launch.title.isEmpty ? "WoW Forever" : launch.title
            let info = [
                title, "Runtime: Playport / Wine / FEX",
                "Stage: \(String(describing: launch.stage))",
                "Session: \(launch.running ? "running" : "idle")"
            ].joined(separator: "\n")
            UIPasteboard.general.string = info
            launch.message = LaunchMessage(title: "Startup and connection", text: "Copied session diagnostics.\n\n" + info)
        }
    }

    static func installAddon(in gameRoot: URL) throws {
        let directories = gameRoot.appendingPathComponent("_forever_/Interface/AddOns/ForeverTouch", isDirectory: true)
        let root = gameRoot.resolvingSymlinksInPath().standardizedFileURL
        guard directories.resolvingSymlinksInPath().standardizedFileURL.path.hasPrefix(root.path + "/") else {
            throw ForeverError("The add-on folder is outside the game installation.")
        }
        let source = Bundle.main.bundleURL.appendingPathComponent("ForeverTouch", isDirectory: true)
        let files = ["ForeverTouchActions.lua", "ForeverTouchPicker.lua", "ForeverTouchMobileLayout.lua"]
        var assets = try files.map { name in
            (name, try Data(contentsOf: source.appendingPathComponent(name)))
        }
        let toc = try String(contentsOf: source.appendingPathComponent("ForeverTouch.toc"), encoding: .utf8)
        let language = UserDefaults.standard.string(forKey: "forever.language") == "de" ? "de" : "en"
        let manifest = Data(("## X-ForeverTouch-Language: \(language)\n" + toc).utf8)
        assets += [("ForeverTouch.toc", manifest), ("ForeverTouch_Camelot.toc", manifest)]
        try FileManager.default.createDirectory(at: directories, withIntermediateDirectories: true)
        for (name, data) in assets {
            let destination = directories.appendingPathComponent(name)
            if (try? Data(contentsOf: destination)) != data {
                try data.write(to: destination, options: .atomic)
            }
        }
    }
}

struct ForeverError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

struct ForeverRuntimeHome: View {
    @ObservedObject private var library = LibraryModel.shared
    @ObservedObject private var store = BattleNetStore.shared
    @ObservedObject private var setup = SetupState.shared

    private var title: InstalledTitle? { library.title(ForeverRuntime.titleID) }

    var body: some View {
        ForeverLauncher(
            installed: title?.canPlay == true,
            runtimeReady: UserDefaults.standard.bool(forKey: SetupState.leftKey) && MemoryLimit.entitled == true,
            canInstall: store.listing(ForeverRuntime.product)?.offered == true && !store.loading,
            clientBuild: store.listing(ForeverRuntime.product)?.version,
            status: library.preparing[ForeverRuntime.titleID] ?? setup.message ?? store.error,
            play: play,
            install: install,
            refresh: refresh,
            setup: { AppNavigation.shared.openSetup() },
            details: {
                if title != nil { AppNavigation.shared.openTitle(ForeverRuntime.titleID) }
                else { AppNavigation.shared.show(.library) }
            }
        )
    }

    private func refresh(_ options: ForeverOptions) async {
        applyRegion(options)
        library.refresh()
        await store.refresh()
    }

    private func install(_ options: ForeverOptions) async throws {
        applyRegion(options)
        await store.loadSizes(ForeverRuntime.product)
        guard store.listing(ForeverRuntime.product)?.offered == true else {
            throw ForeverError(options.language.text("WoW Forever is unavailable in this region.",
                                                     "WoW Forever ist in dieser Region nicht verfügbar."))
        }
        if let refusal = store.install(ForeverRuntime.product) { throw ForeverError(refusal) }
        AppNavigation.shared.show(.downloads)
    }

    private func play(_ options: ForeverOptions) async throws {
        applyRegion(options)
        let id = ForeverRuntime.titleID
        let binding = LaunchSettingsStore.shared.binding(for: id)
        var settings = binding.wrappedValue
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let size = scene?.screen.bounds.size ?? CGSize(width: 16, height: 9)
        let (width, height) = options.resolution.renderPixels(in: size)
        settings.aspect = ScreenAspect.phone.rawValue
        settings.screen = "\(width)x\(height)"
        binding.wrappedValue = settings
        var controls = ControlsStore.shared.game(id)
        controls.layout = .off
        ControlsStore.shared.setGame(id, controls)
        _ = try await library.play(id)
    }

    private func applyRegion(_ options: ForeverOptions) {
        if let region = StoreRegion(rawValue: options.region.rawValue) {
            store.pick(ForeverRuntime.product, region: region)
        }
    }
}
