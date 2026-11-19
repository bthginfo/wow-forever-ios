// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

@main
struct ForeverSimulator: App {
    @AppStorage("forever.fullscreen") private var fullscreen = true
    @State private var playing = ProcessInfo.processInfo.arguments.contains("--hud")
    @State private var textBar = false
    @State private var status: String?
    @State private var inputEvents: Set<String> = []
    private let checkInput = ProcessInfo.processInfo.arguments.contains("--check-input")

    var body: some Scene {
        WindowGroup {
            if playing {
                ZStack {
                    LinearGradient(colors: [ForeverPalette.panel, ForeverPalette.navy], startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                    VStack(spacing: 8) {
                        Text("Game surface preview").font(.title2)
                        Text("The iOS Simulator is displaying the launcher controls.")
                            .font(.footnote)
                        if checkInput {
                            Text(inputEvents.sorted().joined(separator: ", "))
                                .font(.caption2)
                                .accessibilityIdentifier("forever.preview.input")
                        }
                    }
                    .foregroundStyle(ForeverPalette.muted)
                    .allowsHitTesting(false)
                    ForeverOverlay(input: handle)
                }
                .statusBarHidden(fullscreen)
                .persistentSystemOverlays(fullscreen ? .hidden : .automatic)
                .sheet(isPresented: $textBar) { PreviewTextBar() }
            } else {
                ForeverLauncher(
                    installed: true,
                    runtimeReady: false,
                    canInstall: false,
                    clientBuild: nil,
                    status: status,
                    simulator: true,
                    play: { _ in playing = true },
                    install: { _ in },
                    refresh: { _ in },
                    setup: { status = "Runtime setup is performed on a physical iPhone or iPad." },
                    details: { status = "Game installation is supplied by the device runtime." }
                )
            }
        }
    }

    private func handle(_ input: ForeverInput) {
        switch input {
        case .gameMenu: playing = false
        case .textInput: textBar = true
        case let .key(key, down) where checkInput:
            inputEvents.insert("key-\(down ? "down" : "up")-\(key)")
        case let .cameraButton(down) where checkInput:
            inputEvents.insert(down ? "camera-down" : "camera-up")
        case let .cameraMotion(dx, dy) where checkInput && (dx != 0 || dy != 0):
            inputEvents.insert("camera-move")
        default: break
        }
    }
}

private struct PreviewTextBar: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    var body: some View {
        HStack {
            TextField("Chat", text: $text).textFieldStyle(.roundedBorder)
            Button("Done") { dismiss() }
        }
        .padding()
        .presentationDetents([.height(92)])
    }
}
