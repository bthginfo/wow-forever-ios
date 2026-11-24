// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

struct ForeverOverlay: View {
    @Binding var chatFullscreen: Bool
    private enum EditMode { case controls, skills }

    var input: (ForeverInput) -> Void

    @Environment(\.scenePhase) private var phase
    @AppStorage("forever.language") private var language = ForeverLanguage.en
    @AppStorage("forever.fullscreen") private var fullscreen = true
    @AppStorage("forever.toolbarMinimized") private var toolbarMinimized = false
    @AppStorage("forever.positions") private var savedPositions = Data()
    @AppStorage("forever.cameraSensitivity") private var sensitivity = 1.0
    @State private var editMode: EditMode?
    @State private var draft: [String: CGPoint] = [:]
    @State private var dragOrigin: CGPoint?
    @State private var held: Set<UInt8> = []
    @State private var stickDelta = CGSize.zero
    @State private var cameraDelta = CGSize.zero
    @State private var cameraHeld = false

    @State private var positions: [String: CGPoint] = [:]

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let layout = ForeverLayout(size: size, positions: editMode == .controls ? draft : positions)
            ZStack {
                if !chatFullscreen && editMode != .skills {
                    ForEach(ForeverControl.allCases) { control in
                        if let rect = layout.bounds[control], rect.width > 0, rect.height > 0 {
                            controlView(control, rect: rect, size: size)
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)
                        }
                    }
                    toolbarAt(size: size)
                }
                if editMode == nil { chatControlsAt(size: size) }
                if let editMode {
                    VStack {
                        Spacer()
                        editBar(editMode).padding(.bottom, 4)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: size) { _, _ in releaseAll() }
        }
        .onChange(of: savedPositions, initial: true) { _, data in
            positions = (try? JSONDecoder().decode([String: CGPoint].self, from: data)) ?? [:]
        }
        .onChange(of: phase) { _, state in
            if state == .background && editMode == .skills {
                tap(ForeverKeys.saveSkills, modified: true)
                editMode = nil
            }
            if state != .active { releaseAll() }
        }
        .onDisappear {
            if editMode == .skills {
                tap(ForeverKeys.saveSkills, modified: true)
                editMode = nil
            }
            releaseAll()
        }
        .foregroundStyle(ForeverPalette.text)
        .tint(ForeverPalette.gold)
    }

    @ViewBuilder
    private func controlView(_ control: ForeverControl, rect: CGRect, size: CGSize) -> some View {
        if editMode == .controls {
            controlShape(control, rect: rect)
                .gesture(positionGesture(control, rect: rect, size: size))
        } else {
            switch control {
            case .movement:
                controlShape(control, rect: rect)
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
                        .onChanged { value in
                            let radius = rect.width * 0.37
                            stickDelta = CGSize(width: min(radius, max(-radius, value.translation.width)),
                                                height: min(radius, max(-radius, value.translation.height)))
                            setMovement(ForeverKeys.movement(value.translation, radius: radius, held: held))
                        }
                        .onEnded { _ in stopStick() })
            case .camera:
                controlShape(control, rect: rect)
                    .gesture(DragGesture(minimumDistance: 3, coordinateSpace: .global)
                        .onChanged { value in
                            if !cameraHeld { input(.cameraButton(true)); cameraHeld = true }
                            let dx = Double(value.translation.width - cameraDelta.width) * sensitivity
                            let dy = Double(value.translation.height - cameraDelta.height) * sensitivity
                            input(.cameraMotion(dx: dx, dy: dy))
                            cameraDelta = value.translation
                        }
                        .onEnded { _ in stopCamera() })
            case .jump, .target, .interact:
                Button {
                    switch control {
                    case .jump: tap(0x20)
                    case .target: tap(0x7b, modified: true)
                    case .interact: tap(0x79, modified: true)
                    default: break
                    }
                } label: { controlShape(control, rect: rect) }
                .buttonStyle(.plain)
            case .toolbar:
                EmptyView()
            }
        }
    }

    private func controlShape(_ control: ForeverControl, rect: CGRect) -> some View {
        let round = RoundedRectangle(cornerRadius: control == .camera ? rect.height * 0.36 : rect.height / 2)
        return ZStack {
            round.fill(control == .camera ? ForeverPalette.overlay.opacity(0.42) : ForeverPalette.overlay.opacity(0.82))
            round.strokeBorder(ForeverPalette.gold.opacity(cameraHeld && control == .camera ? 0.9 : 0.5), lineWidth: 1)
            if control == .movement && editMode == nil {
                Circle()
                    .fill(ForeverPalette.gold.opacity(0.80))
                    .frame(width: rect.width * 0.36)
                    .offset(x: stickDelta.width * 0.65, y: stickDelta.height * 0.65)
            } else {
                Text(control.label(language))
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                    .padding(.horizontal, 4)
            }
        }
        .contentShape(round)
        .accessibilityLabel(control.label(language))
        .accessibilityIdentifier("forever.control." + control.rawValue)
    }

    @ViewBuilder
    private func toolbarAt(size: CGSize) -> some View {
        let compact = toolbarMinimized && editMode == nil
        let width = compact ? 48 : min(700, max(48, size.width - 12))
        let defaultRect = CGRect(x: (size.width - width) / 2, y: 5, width: width, height: 48)
        let placement = editMode == .controls ? draft : positions
        let rect = placement[ForeverControl.toolbar.rawValue]
            .map { ForeverLayout.place(defaultRect, at: $0, in: size) } ?? defaultRect
        Group {
            if editMode == .controls {
                controlShape(.toolbar, rect: rect)
                    .gesture(positionGesture(.toolbar, rect: rect, size: size))
            } else if compact {
                iconButton("chevron.down", language.text("Show toolbar", "Menüleiste ausklappen")) {
                    toolbarMinimized = false
                }
            } else {
                HStack(spacing: 0) {
                    ScrollView(.horizontal) {
                        HStack(spacing: 16) {
                            ForEach(ForeverShortcut.toolbar) { action in
                                Button {
                                    tap(action.key, modified: true)
                                } label: {
                                    Text(action.label(language)).frame(minHeight: 44).contentShape(Rectangle())
                                }
                                .accessibilityIdentifier("forever.shortcut.\(action)")
                                if action == .character {
                                    Menu(language.text("Social", "Kontakte")) {
                                        ForEach(ForeverShortcut.social) { shortcut in
                                            Button(shortcut.label(language)) { tap(shortcut.key, modified: true) }
                                        }
                                    }
                                    .accessibilityIdentifier("forever.social")
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                    }
                    .scrollIndicators(.hidden)
                    iconButton("chevron.up", language.text("Minimize toolbar", "Menüleiste einklappen")) {
                        toolbarMinimized = true
                    }
                    more
                }
                .font(.system(size: 13, weight: .medium))
                .buttonStyle(.plain)
            }
        }
        .frame(width: width, height: 48)
        .background(ForeverPalette.overlay, in: RoundedRectangle(cornerRadius: 15))
        .overlay { RoundedRectangle(cornerRadius: 15).strokeBorder(ForeverPalette.gold.opacity(0.48)).allowsHitTesting(false) }
        .position(x: rect.midX, y: rect.midY)
    }

    private func chatControlsAt(size: CGSize) -> some View {
        // The compact dock shares its anchor with ForeverTouchChat.lua.
        let end = chatFullscreen ? size.width * 0.05 :
            min(size.width * 0.28, size.height * 0.34) +
            max(size.width * 0.045, size.height * 0.14) + size.height * 0.01
        let buttonSize: CGFloat = chatFullscreen ? 44 : 35
        let center = max(buttonSize / 2, size.height * (chatFullscreen ? 0.073 : 0.191))
        return HStack(spacing: 0) {
            chatButton("square.and.pencil", ForeverShortcut.chat.label(language), size: buttonSize) {
                releaseAll()
                tap(ForeverShortcut.chat.key, modified: true)
                input(.chatInput)
            }
            .accessibilityIdentifier("forever.shortcut.chat")
            chatButton(chatFullscreen ? "xmark" : "arrow.up.left.and.arrow.down.right",
                       chatFullscreen ? language.text("Back to game", "Zurück zum Spiel") :
                       language.text("Full chat", "Chat-Vollbild"), size: buttonSize) {
                setChatFullscreen(!chatFullscreen)
            }
            .accessibilityIdentifier("forever.chat.fullscreen")
        }
        .background(Color(red: 0.08, green: 0.12, blue: 0.17).opacity(chatFullscreen ? 0.85 : 0.45), in: Capsule())
        .position(x: max(buttonSize, size.width - end - buttonSize), y: center)
    }

    private func chatButton(_ icon: String, _ title: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: size, height: size)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func setChatFullscreen(_ expanded: Bool) {
        releaseAll()
        tap(expanded ? ForeverKeys.openChatFullscreen : ForeverKeys.closeChatFullscreen, modified: true)
        chatFullscreen = expanded
    }

    private var more: some View {
        Menu {
            Button(language.text("Edit controls", "Steuerung anpassen")) {
                releaseAll()
                draft = positions
                editMode = .controls
            }
            Button(language.text("Edit skills", "Skills anpassen")) {
                releaseAll()
                tap(ForeverKeys.editSkills, modified: true)
                editMode = .skills
            }
            ForEach([ForeverShortcut.collections, .frameLimit]) { action in
                Button(action.label(language)) { tap(action.key, modified: true) }
                    .accessibilityIdentifier("forever.shortcut.\(action)")
            }
            Button(language.text("Text input", "Texteingabe")) { input(.textInput) }
            Menu(language.text("Camera sensitivity", "Kameraempfindlichkeit")) {
                ForEach([0.75, 1.0, 1.25, 1.5], id: \.self) { value in
                    Button("\(Int(value * 100))%") { sensitivity = value }
                }
            }
            Button(fullscreen ? language.text("Exit fullscreen", "Vollbild verlassen")
                              : language.text("Enter fullscreen", "Vollbild aktivieren")) { fullscreen.toggle() }
            Button(language.text("Game menu", "Spielmenü")) { input(.gameMenu) }
            Button(language.text("Startup and connection", "Start und Verbindung")) { input(.diagnostics) }
        } label: {
            Image(systemName: "ellipsis").frame(width: 42, height: 44)
        }
        .accessibilityLabel(language.text("More controls", "Weitere Funktionen"))
        .accessibilityIdentifier("forever.more")
    }

    private func iconButton(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(ForeverPalette.gold)
        .accessibilityLabel(title)
    }

    private func editBar(_ mode: EditMode) -> some View {
        HStack(spacing: 17) {
            Button(language.text("Default", "Standard")) {
                if mode == .controls { draft = [:] }
                else { tap(ForeverKeys.resetSkills, modified: true) }
            }
            Button(mode == .skills ? language.text("Discard", "Verwerfen") : language.text("Cancel", "Abbrechen")) {
                if mode == .skills { tap(ForeverKeys.cancelSkills, modified: true) }
                editMode = nil
            }
            Button(mode == .skills ? language.text("Done", "Fertig") : language.text("Save", "Speichern")) {
                if mode == .controls { savedPositions = (try? JSONEncoder().encode(draft)) ?? savedPositions }
                else { tap(ForeverKeys.saveSkills, modified: true) }
                editMode = nil
            }
            .foregroundStyle(ForeverPalette.gold)
        }
        .font(.system(size: 13, weight: .semibold))
        .buttonStyle(.plain)
        .padding(12)
        .background(ForeverPalette.overlay, in: RoundedRectangle(cornerRadius: 14))
    }

    private func positionGesture(_ control: ForeverControl, rect: CGRect, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { value in
                if dragOrigin == nil { dragOrigin = CGPoint(x: rect.midX, y: rect.midY) }
                guard let origin = dragOrigin else { return }
                let center = CGPoint(x: origin.x + value.translation.width, y: origin.y + value.translation.height)
                draft[control.rawValue] = ForeverLayout.position(rect: rect, center: center, size: size)
            }
            .onEnded { _ in dragOrigin = nil }
    }

    private func tap(_ key: UInt8, modified: Bool = false) {
        ForeverKeys.press(key, modified: modified).forEach(input)
    }

    private func setMovement(_ keys: Set<UInt8>) {
        for key in held.subtracting(keys).sorted() { input(.key(key, down: false)) }
        for key in keys.subtracting(held).sorted() { input(.key(key, down: true)) }
        held = keys
    }

    private func stopStick() {
        setMovement([])
        stickDelta = .zero
    }

    private func stopCamera() {
        if cameraHeld { input(.cameraButton(false)) }
        cameraHeld = false
        cameraDelta = .zero
    }

    private func releaseAll() {
        stopStick()
        stopCamera()
    }
}
