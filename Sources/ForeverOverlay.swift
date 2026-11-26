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
    // Each control's drag in the layout editor, keyed by where that drag started.
    @State private var editDrags: [ForeverControl: (start: CGPoint, origin: CGPoint)] = [:]
    // Bumped to make the play controls release every key and button they hold.
    @State private var releaseRequest = 0

    @State private var positions: [String: CGPoint] = [:]

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let layout = ForeverLayout(size: size, positions: editMode == .controls ? draft : positions)
            ZStack {
                if chatFullscreen {
                    VStack {
                        HStack(spacing: 12) {
                            Button {
                                setChatFullscreen(false)
                            } label: {
                                Text(language.text("Back to game", "Zurück zum Spiel"))
                                    .frame(minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            composer
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 48)
                        .background(ForeverPalette.overlay, in: RoundedRectangle(cornerRadius: 15))
                        .padding(.top, 5)
                        Spacer().allowsHitTesting(false)
                    }
                    .font(.system(size: 13, weight: .medium))
                    .buttonStyle(.plain)
                } else if editMode != .skills {
                    // Later controls sit above the stick's wider touch zone and keep their own touches.
                    ForEach(ForeverControl.allCases) { control in
                        if let rect = layout.bounds[control], rect.width > 0, rect.height > 0 {
                            let frame = control == .movement && editMode == nil ? layout.stickZone(in: size) : rect
                            controlView(control, rect: rect, zone: frame, size: size)
                                .frame(width: frame.width, height: frame.height)
                                .position(x: frame.midX, y: frame.midY)
                        }
                    }
                    toolbarAt(size: size)
                }
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
            // Save while the game still has focus: by .background the runtime has paused the game.
            if state != .active && editMode == .skills {
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
    private func controlView(_ control: ForeverControl, rect: CGRect, zone: CGRect, size: CGSize) -> some View {
        if editMode == .controls {
            ForeverControlFace(control: control, label: control.label(language), active: false)
                .gesture(positionGesture(control, rect: rect, size: size))
        } else {
            switch control {
            case .movement:
                ForeverStick(stick: rect, zone: zone, label: control.label(language),
                             releaseRequest: releaseRequest, input: input)
            case .camera:
                ForeverCameraArea(label: control.label(language), sensitivity: sensitivity,
                                  releaseRequest: releaseRequest, input: input)
            case .jump:
                // Held like a key, so the character keeps rising while it swims or flies.
                ForeverPressControl(control: control, label: control.label(language), releaseRequest: releaseRequest,
                                    press: { input(.key(ForeverKeys.jump, down: true)) },
                                    release: { input(.key(ForeverKeys.jump, down: false)) })
            case .target, .interact:
                let key = control == .target ? ForeverKeys.target : ForeverKeys.interact
                ForeverPressControl(control: control, label: control.label(language), releaseRequest: releaseRequest,
                                    press: { tap(key, modified: true) }, release: nil)
            case .toolbar:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func toolbarAt(size: CGSize) -> some View {
        let compact = toolbarMinimized && editMode == nil
        let width = compact ? min(210, size.width - 12) : min(700, max(48, size.width - 12))
        let defaultRect = CGRect(x: (size.width - width) / 2, y: 5, width: width, height: 48)
        let placement = editMode == .controls ? draft : positions
        let rect = placement[ForeverControl.toolbar.rawValue]
            .map { ForeverLayout.place(defaultRect, at: $0, in: size) } ?? defaultRect
        Group {
            if editMode == .controls {
                ForeverControlFace(control: .toolbar, label: ForeverControl.toolbar.label(language), active: false)
                    .gesture(positionGesture(.toolbar, rect: rect, size: size))
            } else if compact {
                HStack(spacing: 4) {
                    composer
                    chatFullscreenButton
                    iconButton("chevron.down", language.text("Show toolbar", "Menüleiste ausklappen")) {
                        toolbarMinimized = false
                    }
                }
                .font(.system(size: 13, weight: .medium))
            } else {
                HStack(spacing: 0) {
                    ScrollView(.horizontal) {
                        HStack(spacing: 16) {
                            ForEach(ForeverShortcut.toolbar) { action in
                                if action == .chat {
                                    composer
                                    chatFullscreenButton
                                } else {
                                    Button {
                                        tap(action.key, modified: true)
                                    } label: {
                                        Text(action.label(language)).frame(minHeight: 44).contentShape(Rectangle())
                                    }
                                    .accessibilityIdentifier("forever.shortcut.\(action)")
                                }
                                if action == .character {
                                    Menu {
                                        ForEach(ForeverShortcut.social) { shortcut in
                                            Button(shortcut.label(language)) { tap(shortcut.key, modified: true) }
                                        }
                                    } label: {
                                        Text(language.text("Social", "Kontakte"))
                                            .frame(minHeight: 44)
                                            .contentShape(Rectangle())
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

    private var composer: some View {
        Button {
            releaseAll()
            tap(ForeverShortcut.chat.key, modified: true)
            input(.chatInput)
        } label: {
            Text(ForeverShortcut.chat.label(language))
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(ForeverPalette.text.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("forever.shortcut.chat")
    }

    private var chatFullscreenButton: some View {
        iconButton("arrow.up.left.and.arrow.down.right", language.text("Full chat", "Chat-Vollbild")) {
            setChatFullscreen(true)
        }
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
            Image(systemName: "ellipsis").frame(width: 44, height: 44).contentShape(Rectangle())
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
        HStack(spacing: 6) {
            editButton(language.text("Default", "Standard")) {
                if mode == .controls { draft = [:] }
                else { tap(ForeverKeys.resetSkills, modified: true) }
            }
            editButton(mode == .skills ? language.text("Discard", "Verwerfen") : language.text("Cancel", "Abbrechen")) {
                if mode == .skills { tap(ForeverKeys.cancelSkills, modified: true) }
                editMode = nil
            }
            editButton(mode == .skills ? language.text("Done", "Fertig") : language.text("Save", "Speichern")) {
                if mode == .controls { savedPositions = (try? JSONEncoder().encode(draft)) ?? savedPositions }
                else { tap(ForeverKeys.saveSkills, modified: true) }
                editMode = nil
            }
            .foregroundStyle(ForeverPalette.gold)
        }
        .font(.system(size: 13, weight: .semibold))
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .background(ForeverPalette.overlay, in: RoundedRectangle(cornerRadius: 14))
    }

    private func editButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).padding(.horizontal, 10).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }
    }

    private func positionGesture(_ control: ForeverControl, rect: CGRect, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { value in
                // A new start point means a new drag, even if the previous one was cancelled without an end.
                let current: (start: CGPoint, origin: CGPoint)? = editDrags[control]
                let drag: (start: CGPoint, origin: CGPoint)
                if let current, current.start == value.startLocation {
                    drag = current
                } else {
                    drag = (start: value.startLocation, origin: CGPoint(x: rect.midX, y: rect.midY))
                }
                editDrags[control] = drag
                let center = CGPoint(x: drag.origin.x + value.translation.width,
                                     y: drag.origin.y + value.translation.height)
                draft[control.rawValue] = ForeverLayout.position(rect: rect, center: center, size: size)
            }
            .onEnded { _ in editDrags[control] = nil }
    }

    private func tap(_ key: UInt8, modified: Bool = false) {
        ForeverKeys.press(key, modified: modified).forEach(input)
    }

    private func releaseAll() {
        releaseRequest &+= 1
    }
}

/// The shared look of a touch control.
struct ForeverControlFace: View {
    let control: ForeverControl
    let label: String
    let active: Bool

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let round = RoundedRectangle(cornerRadius: control == .camera ? height * 0.36 : height / 2)
            ZStack {
                round.fill(active ? ForeverPalette.gold.opacity(0.36)
                                  : ForeverPalette.overlay.opacity(control == .camera ? 0.42 : 0.82))
                round.strokeBorder(ForeverPalette.gold.opacity(active ? 0.95 : 0.5), lineWidth: 1)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                    .padding(.horizontal, 4)
            }
            .contentShape(round)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityIdentifier("forever.control." + control.rawValue)
    }
}

/// The movement stick. A touch anywhere in its zone starts it there, and the base follows the thumb.
/// Its touch state resets when the system cancels the touch, which releases the movement keys.
struct ForeverStick: View {
    let stick: CGRect
    let zone: CGRect
    let label: String
    let releaseRequest: Int
    let input: (ForeverInput) -> Void

    private struct Touch: Equatable {
        var start: CGPoint
        var translation: CGSize
    }

    @GestureState private var touch: Touch?
    @State private var held: Set<UInt8> = []

    var body: some View {
        let radius = stick.width / 2
        let travel = stick.width * 0.37
        let resting = CGPoint(x: stick.midX - zone.minX, y: stick.midY - zone.minY)
        let base = touch.map { touch in
            let inset = radius * 0.7
            return CGPoint(x: min(max(touch.start.x, inset), max(inset, zone.width - inset)),
                           y: min(max(touch.start.y, inset), max(inset, zone.height - inset)))
        } ?? resting
        let knob = touch.map { touch -> CGSize in
            let length = hypot(touch.translation.width, touch.translation.height)
            let scale = length > travel ? travel / length : 1
            return CGSize(width: touch.translation.width * scale * 0.65, height: touch.translation.height * scale * 0.65)
        } ?? .zero

        ZStack {
            Color.clear.contentShape(Rectangle())
            ZStack {
                Circle().fill(ForeverPalette.overlay.opacity(touch == nil ? 0.72 : 0.86))
                Circle().strokeBorder(ForeverPalette.gold.opacity(touch == nil ? 0.5 : 0.9), lineWidth: 1)
                Circle()
                    .fill(ForeverPalette.gold.opacity(0.80))
                    .frame(width: stick.width * 0.36)
                    .offset(knob)
            }
            .frame(width: stick.width, height: stick.height)
            .position(base)
            .allowsHitTesting(false)
        }
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .updating($touch) { value, state, _ in
                    state = Touch(start: value.startLocation, translation: value.translation)
                }
        )
        .onChange(of: touch) { _, touch in
            setMovement(touch.map { ForeverKeys.movement($0.translation, radius: travel, held: held) } ?? [])
        }
        .onChange(of: releaseRequest) { _, _ in setMovement([]) }
        .onDisappear { setMovement([]) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityIdentifier("forever.control.movement")
    }

    private func setMovement(_ keys: Set<UInt8>) {
        guard keys != held else { return }
        for key in held.subtracting(keys).sorted() { input(.key(key, down: false)) }
        for key in keys.subtracting(held).sorted() { input(.key(key, down: true)) }
        held = keys
    }
}

/// Drag to turn the camera with the right mouse button. Motion is tracked outside view state, so a drag only
/// redraws this control when it starts and ends.
struct ForeverCameraArea: View {
    let label: String
    let sensitivity: Double
    let releaseRequest: Int
    let input: (ForeverInput) -> Void

    private final class Tracker {
        var last = CGSize.zero
    }

    @GestureState private var translation: CGSize?
    @State private var held = false
    @State private var tracker = Tracker()

    var body: some View {
        ForeverControlFace(control: .camera, label: label, active: held)
            .gesture(
                DragGesture(minimumDistance: 3, coordinateSpace: .global)
                    .updating($translation) { value, state, _ in state = value.translation }
            )
            .onChange(of: translation) { _, translation in
                guard let translation else { return stop() }
                if !held {
                    input(.cameraButton(true))
                    held = true
                }
                let dx = Double(translation.width - tracker.last.width) * sensitivity
                let dy = Double(translation.height - tracker.last.height) * sensitivity
                tracker.last = translation
                input(.cameraMotion(dx: dx, dy: dy))
            }
            .onChange(of: releaseRequest) { _, _ in stop() }
            .onDisappear { stop() }
    }

    private func stop() {
        if held { input(.cameraButton(false)) }
        held = false
        tracker.last = .zero
    }
}

/// A button that acts on touch-down like a game pad and gives a light haptic tick.
struct ForeverPressControl: View {
    let control: ForeverControl
    let label: String
    let releaseRequest: Int
    let press: () -> Void
    let release: (() -> Void)?

    @GestureState private var touching = false
    @State private var down = false
    @State private var presses = 0

    var body: some View {
        ForeverControlFace(control: control, label: label, active: down)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .updating($touching) { _, state, _ in state = true }
            )
            .onChange(of: touching) { _, touching in
                if touching { begin() } else { end() }
            }
            .onChange(of: releaseRequest) { _, _ in end() }
            .onDisappear { end() }
            .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: presses)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                begin()
                end()
            }
    }

    private func begin() {
        guard !down else { return }
        down = true
        presses &+= 1
        press()
    }

    private func end() {
        guard down else { return }
        down = false
        release?()
    }
}
