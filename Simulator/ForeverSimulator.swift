// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

@main
struct ForeverSimulator: App {
    private enum Installation: Equatable { case available, downloading, paused, installed }
    private enum Sheet: String, Identifiable {
        case download, setup, signIn, chat
        var id: Self { self }
    }

    private static let arguments = ProcessInfo.processInfo.arguments
    private static let onboarding = !arguments.contains("--hud") && !arguments.contains("--check-input")
    @AppStorage("forever.fullscreen") private var fullscreen = true
    @State private var playing = ForeverSimulator.arguments.contains("--hud")
    @State private var installation: Installation = ForeverSimulator.onboarding ? .available : .installed
    @State private var runtime: ForeverRuntimeReadiness = ForeverSimulator.onboarding ? .setupRequired : .configured
    @State private var sheet: Sheet?
    @State private var inputEvents: Set<String> = []
    private let checkInput = ForeverSimulator.arguments.contains("--check-input")

    private var transfer: ForeverTransfer? {
        switch installation {
        case .downloading: .active(progress: 0.4, message: "Simulated download · 40%")
        case .paused: .paused(reason: "Simulated download paused")
        case .available, .installed: nil
        }
    }

    var body: some Scene {
        WindowGroup {
            content.sheet(item: $sheet, content: preview)
        }
    }

    @ViewBuilder private var content: some View {
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
        } else {
            ForeverLauncher(
                installed: installation == .installed,
                runtime: runtime,
                canInstall: installation == .available,
                transfer: transfer,
                clientBuild: Self.onboarding ? "Sample game build" : nil,
                status: nil,
                simulator: true,
                play: { _ in
                    if Self.onboarding { sheet = .signIn }
                    else { playing = true }
                },
                install: { _ in installation = .downloading },
                refresh: { _ in },
                setup: { sheet = .setup },
                details: { if transfer != nil { sheet = .download } },
                showDownload: { sheet = .download },
                resumeDownload: { installation = .downloading }
            )
        }
    }

    @ViewBuilder private func preview(_ panel: Sheet) -> some View {
        if panel == .chat {
            PreviewTextBar()
        } else {
            VStack(spacing: 18) {
                switch panel {
                case .download:
                    Text("Simulated download").font(.title2)
                    Button("Complete download") {
                        installation = .installed
                        sheet = nil
                    }
                    .accessibilityIdentifier("forever.preview.download.complete")
                    Button("Pause download") {
                        installation = .paused
                        sheet = nil
                    }
                    .accessibilityIdentifier("forever.preview.download.pause")
                case .setup:
                    Text("Simulated device and JIT setup").font(.title2)
                    Button("Complete setup") {
                        runtime = .configured
                        sheet = nil
                    }
                    .accessibilityIdentifier("forever.preview.setup.complete")
                case .signIn:
                    Text("Simulated Battle.net sign-in").font(.title2)
                    Button("Continue with test account") {
                        sheet = nil
                        playing = true
                    }
                    .accessibilityIdentifier("forever.preview.signin.continue")
                case .chat: EmptyView()
                }
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }

    private func handle(_ input: ForeverInput) {
        switch input {
        case .gameMenu: playing = false
        case .textInput: sheet = .chat
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
