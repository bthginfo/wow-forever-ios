// SPDX-License-Identifier: GPL-3.0-or-later
// Compiled as part of the pinned Playport app by tools/prepare_runtime.py.
import BattleNetClientKit
import Combine
import Foundation
import GameController
import HostIOKit
import PlayportKit
import SwiftUI
import UIKit

@MainActor
enum ForeverRuntime {
    static let product = BattleNetProduct.wowForever
    static let key = BattleNet.key(product)
    static let titleID = key.titleID
    private static var motion = RelativeMotion()
    private static var addonDirectory: URL?
    private static let inputModeFile = "ForeverTouchInputMode.lua"

    static var hasDesktopInput: Bool { GCKeyboard.coalesced != nil && !GCMouse.mice().isEmpty }

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
        let language = UserDefaults.standard.string(forKey: "forever.language") ?? ForeverLanguage.preferred.rawValue
        let manifest = Data(("## X-ForeverTouch-Language: \(language)\n" + toc).utf8)
        assets += [(inputModeFile, inputModeData(desktop: hasDesktopInput)),
                   ("ForeverTouch.toc", manifest), ("ForeverTouch_Camelot.toc", manifest)]
        try FileManager.default.createDirectory(at: directories, withIntermediateDirectories: true)
        for (name, data) in assets {
            let destination = directories.appendingPathComponent(name)
            if (try? Data(contentsOf: destination)) != data {
                try data.write(to: destination, options: .atomic)
            }
        }
        addonDirectory = directories
    }

    private static func inputModeData(desktop: Bool) -> Data {
        Data("local _, addon = ...\naddon.desktopInput = \(desktop)\n".utf8)
    }

    static func saveInputMode(desktop: Bool) {
        guard let addonDirectory else { return }
        let destination = addonDirectory.appendingPathComponent(inputModeFile)
        let data = inputModeData(desktop: desktop)
        do {
            if (try? Data(contentsOf: destination)) != data {
                try data.write(to: destination, options: .atomic)
            }
        } catch {
            NSLog("Could not save the current Forever Touch input mode: %@", error.localizedDescription)
        }
    }

    static func sendInputMode(desktop: Bool) {
        let keyboard = GCKeyboard.coalesced?.keyboardInput
        func pressed(_ left: GCKeyCode, _ right: GCKeyCode) -> Bool {
            keyboard?.button(forKeyCode: left)?.isPressed == true ||
                keyboard?.button(forKeyCode: right)?.isPressed == true
        }
        var held: Set<UInt8> = []
        if pressed(.leftControl, .rightControl) { held.insert(ForeverKeys.control) }
        if pressed(.leftAlt, .rightAlt) { held.insert(ForeverKeys.alt) }
        if pressed(.leftShift, .rightShift) { held.insert(ForeverKeys.shift) }
        ForeverKeys.inputMode(desktop: desktop, heldModifiers: held).forEach(deliver)
    }
}

@MainActor
struct ForeverGameControls: View {
    var inputReady: Bool
    @Environment(\.scenePhase) private var scenePhase
    @State private var hardwareDesktop = ForeverRuntime.hasDesktopInput
    @State private var editingTouchLayout = false

    private var desktopInput: Bool { hardwareDesktop && !editingTouchLayout }
    private var readyMode: Bool? { inputReady && scenePhase == .active ? desktopInput : nil }

    private static let accessoryChanges = Publishers.MergeMany([
        Notification.Name.GCKeyboardDidConnect, .GCKeyboardDidDisconnect, .GCMouseDidConnect, .GCMouseDidDisconnect,
    ].map { NotificationCenter.default.publisher(for: $0) })

    var body: some View {
        ZStack {
            Color.clear.allowsHitTesting(false)
            if inputReady && !desktopInput {
                ForeverOverlay(input: ForeverRuntime.deliver, onEditingChange: { editingTouchLayout = $0 })
            }
        }
        .allowsHitTesting(inputReady && !desktopInput)
        .onReceive(Self.accessoryChanges) { _ in hardwareDesktop = ForeverRuntime.hasDesktopInput }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { hardwareDesktop = ForeverRuntime.hasDesktopInput }
        }
        .onChange(of: desktopInput, initial: true) { _, desktop in
            ForeverRuntime.saveInputMode(desktop: desktop)
        }
        .task(id: readyMode) {
            guard let desktop = readyMode else { return }
            // Let the touch controls release their held inputs before the guest changes mode.
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            ForeverRuntime.sendInputMode(desktop: desktop)
            try? await Task.sleep(for: .milliseconds(750))
            guard !Task.isCancelled else { return }
            ForeverRuntime.sendInputMode(desktop: desktop)
        }
    }
}

struct ForeverError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

struct ForeverRuntimeHome: View {
    @ObservedObject var installs: Downloads
    @ObservedObject private var library = LibraryModel.shared
    @ObservedObject private var store = BattleNetStore.shared
    @ObservedObject private var setup = SetupState.shared
    @Environment(\.scenePhase) private var scenePhase

    private var title: InstalledTitle? { library.title(ForeverRuntime.titleID) }

    private var listing: BattleNetListing? {
        let product = ForeverRuntime.product
        guard let listing = store.listing(product), listing.region == store.region(product) else { return nil }
        return listing
    }

    private var runtime: ForeverRuntimeReadiness {
        let facts = setup.facts
        switch SetupChecklist.beforeLaunch(facts) {
        case .needs: return .setupRequired
        case .fixesItself: return .startsWithGame
        case .go: return facts.jit.usesPairing ? .configured : .startsWithGame
        }
    }

    private var transfer: ForeverTransfer? {
        guard let job = installs.jobs[ForeverRuntime.key] else { return nil }
        if case let .paused(reason) = job.phase { return .paused(reason: reason) }
        return .active(progress: job.fraction, message: job.status)
    }

    var body: some View {
        ForeverLauncher(
            installed: title?.canPlay == true,
            runtime: runtime,
            canInstall: listing?.offered == true,
            checking: library.scanning || store.sizing.contains(ForeverRuntime.product),
            transfer: transfer,
            clientBuild: listing?.version,
            status: library.preparing[ForeverRuntime.titleID] ?? setup.message ?? store.sizeErrors[ForeverRuntime.product],
            play: play,
            install: install,
            refresh: refresh,
            setup: openSetup,
            details: {
                if title != nil { AppNavigation.shared.openTitle(ForeverRuntime.titleID) }
                else { AppNavigation.shared.show(.library) }
            },
            showDownload: { AppNavigation.shared.show(.downloads) },
            resumeDownload: { installs.resume(ForeverRuntime.key) }
        )
        .onChange(of: scenePhase, initial: true) {
            if scenePhase == .active { setup.readTunnel() }
        }
    }

    private func openSetup() {
        if case let .needs(step, _) = SetupChecklist.beforeLaunch(setup.facts) {
            AppNavigation.shared.openSetup(on: step)
        } else {
            AppNavigation.shared.openSetup()
        }
    }

    private func refresh(_ options: ForeverOptions) async {
        applyRegion(options)
        library.refresh()
        await store.loadSizes(ForeverRuntime.product, force: true)
    }

    private func install(_ options: ForeverOptions) async throws {
        applyRegion(options)
        await store.loadSizes(ForeverRuntime.product)
        guard listing?.offered == true, listing?.region.rawValue == options.region.rawValue else {
            throw ForeverError(options.language.text("WoW Forever is unavailable in this region.",
                                                     "WoW Forever ist in dieser Region nicht verfügbar."))
        }
        if let refusal = store.install(ForeverRuntime.product) { throw ForeverError(refusal) }
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
