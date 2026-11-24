// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

@main
struct ForeverSimulator: App {
    @AppStorage("forever.fullscreen") private var fullscreen = true
    @State private var playing = ProcessInfo.processInfo.arguments.contains("--hud")
    @State private var textBar = false
    @State private var chatFullscreen = false
    @State private var status: String?

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
                    }
                    .foregroundStyle(ForeverPalette.muted)
                    .allowsHitTesting(false)
                    ForeverOverlay(chatFullscreen: $chatFullscreen, input: handle)
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
        case .textInput, .chatInput: textBar = true
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
