// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

enum ForeverPalette {
    static let navy = Color(red: 0.043, green: 0.06, blue: 0.096)
    static let panel = Color(red: 0.075, green: 0.112, blue: 0.177)
    static let border = Color(red: 0.16, green: 0.23, blue: 0.33)
    static let muted = Color(red: 0.57, green: 0.65, blue: 0.76)
    static let gold = Color(red: 0.918, green: 0.78, blue: 0.514)
    static let bronze = Color(red: 0.61, green: 0.43, blue: 0.22)
    static let text = Color(red: 0.96, green: 0.90, blue: 0.79)
    static let overlay = Color(red: 0.10, green: 0.085, blue: 0.063).opacity(0.92)
}

struct ForeverLauncher: View {
    var installed: Bool
    var runtime: ForeverRuntimeReadiness
    var canInstall: Bool
    var checking: Bool = false
    var transfer: ForeverTransfer?
    var clientBuild: String?
    var status: String?
    var simulator: Bool = false
    var play: (ForeverOptions) async throws -> Void
    var install: (ForeverOptions) async throws -> Void
    var refresh: (ForeverOptions) async -> Void
    var setup: () -> Void
    var details: () -> Void
    var showDownload: () -> Void
    var resumeDownload: () -> Void

    @AppStorage("forever.language") private var language = ForeverLanguage.preferred
    @AppStorage("forever.region") private var region = ForeverRegion.suggested(for: Locale.current.region?.identifier)
    @AppStorage("forever.resolution") private var resolution = ForeverResolution.hdPlus
    @State private var busy = false
    @State private var failure: String?

    private var options: ForeverOptions { .init(language: language, region: region, resolution: resolution) }
    private var primary: ForeverLaunchAction {
        .next(installed: installed, runtime: runtime, transfer: transfer, checking: checking, canInstall: canInstall)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                readiness
                VStack(spacing: 10) {
                    Button(action: performPrimary) {
                        Label(primary.label(language), systemImage: primary.icon)
                        .font(.system(size: 15, weight: .bold))
                        .textCase(.uppercase)
                        .padding(.vertical, 15)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white)
                        .background(ForeverPalette.bronze, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(busy || primary == .check)
                    .opacity(busy || primary == .check ? 0.5 : 1)
                    .accessibilityIdentifier("forever.primary")

                    if primary == .play {
                        Text(language.text("Sign in with Battle.net when the game opens.",
                                           "Melde dich bei Battle.net an, sobald sich das Spiel öffnet."))
                            .font(.footnote)
                            .foregroundStyle(ForeverPalette.muted)
                    }
                    tools
                }
                .frame(maxWidth: 540)
            }
            .frame(maxWidth: 680)
            .padding(.horizontal, 24)
            .padding(.vertical, 26)
            .frame(maxWidth: .infinity)
        }
        .background(ForeverPalette.navy.ignoresSafeArea())
        .foregroundStyle(ForeverPalette.text)
        .preferredColorScheme(.dark)
        .tint(ForeverPalette.gold)
        .task(id: region) { await refresh(options) }
    }

    private var header: some View {
        VStack(spacing: 5) {
            Text("WORLD OF WARCRAFT")
                .font(.system(size: 28, weight: .black, design: .serif))
                .tracking(2)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text("FOREVER MOBILE")
                .font(.system(size: 12, weight: .bold))
                .tracking(2.5)
                .foregroundStyle(ForeverPalette.gold)
            Text(simulator ? language.text("Simulator · interface preview", "Simulator · Oberflächenvorschau")
                           : "iPhone · iPad")
                .font(.footnote)
                .foregroundStyle(ForeverPalette.muted)
        }
        .accessibilityElement(children: .combine)
    }

    private var readiness: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(language.text("Environment readiness", "Startbereitschaft"))
                .font(.system(size: 13, weight: .bold)).textCase(.uppercase)
                .foregroundStyle(ForeverPalette.gold)
            requirement(language.text("WoW Forever client", "WoW-Forever-Client"), installed)
            switch runtime {
            case .setupRequired:
                requirement(language.text("Runtime setup required", "Laufzeit muss eingerichtet werden"), false)
            case .startsWithGame:
                Label(language.text("Runtime setup continues with Play", "Laufzeit wird beim Spielen eingerichtet"),
                      systemImage: "arrow.right.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(ForeverPalette.muted)
            case .configured:
                requirement(language.text("Runtime configured", "Laufzeit eingerichtet"), true)
            }
            if let clientBuild {
                Label(clientBuild, systemImage: "shippingbox").font(.footnote)
            }
            Divider().overlay(ForeverPalette.border)
            ViewThatFits(in: .horizontal) {
                HStack { regionPicker; resolutionPicker; languagePicker }
                VStack(alignment: .leading) { regionPicker; resolutionPicker; languagePicker }
            }
            .font(.footnote)
            .foregroundStyle(ForeverPalette.muted)
            if busy { ProgressView() }
            if let transfer {
                switch transfer {
                case let .active(progress, message):
                    if let progress, progress.isFinite {
                        ProgressView(value: min(1, max(0, progress)))
                    } else {
                        ProgressView()
                    }
                    Text(message).font(.footnote)
                        .accessibilityIdentifier("forever.download.status")
                case let .paused(reason):
                    Text(reason ?? language.text("Download paused", "Download pausiert"))
                        .font(.footnote)
                        .accessibilityIdentifier("forever.download.status")
                }
            }
            if let message = failure ?? status {
                Text(message).font(.footnote).foregroundStyle(failure == nil ? ForeverPalette.muted : .orange)
                    .accessibilityIdentifier("forever.status")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForeverPalette.panel, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(ForeverPalette.border) }
    }

    private func requirement(_ label: String, _ ready: Bool) -> some View {
        Label(label, systemImage: ready ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 14))
            .foregroundStyle(ready ? Color(red: 0.51, green: 0.83, blue: 0.65) : ForeverPalette.muted)
    }

    private var regionPicker: some View {
        Picker(selection: $region) {
            ForEach(ForeverRegion.allCases) { Text($0.label(language)).tag($0) }
        } label: { Text(language.text("Region", "Region")) }
        .disabled(transfer != nil || busy)
        .accessibilityIdentifier("forever.region")
    }

    private var resolutionPicker: some View {
        Picker(selection: $resolution) {
            ForEach(ForeverResolution.allCases) { Text($0.label).tag($0) }
        } label: { Text(language.text("Resolution", "Auflösung")) }
        .accessibilityIdentifier("forever.resolution")
    }

    private var languagePicker: some View {
        Picker(selection: $language) {
            ForEach(ForeverLanguage.allCases) { Text($0.label).tag($0) }
        } label: { Text(language.text("Language", "Sprache")) }
        .accessibilityIdentifier("forever.language")
    }

    private var tools: some View {
        HStack(spacing: 16) {
            Button { run(refresh) } label: {
                Label(language.text("Refresh", "Aktualisieren"), systemImage: "arrow.clockwise")
            }
            Button(action: setup) {
                Label(language.text("Runtime setup", "Laufzeit einrichten"), systemImage: "gearshape")
            }
            Button(action: details) {
                Label(language.text("Game files", "Spieldateien"), systemImage: "folder")
            }
        }
        .font(.footnote)
        .buttonStyle(.plain)
        .foregroundStyle(ForeverPalette.muted)
    }

    private func performPrimary() {
        switch primary {
        case .check: break
        case .refresh: run(refresh)
        case .install: run(install)
        case .downloads: showDownload()
        case .resume: resumeDownload()
        case .setup: setup()
        case .play: run(play)
        }
    }

    private func run(_ action: @escaping (ForeverOptions) async throws -> Void) {
        guard !busy else { return }
        failure = nil
        busy = true
        let selected = options
        Task { @MainActor in
            defer { busy = false }
            do { try await action(selected) }
            catch { failure = error.localizedDescription }
        }
    }
}
