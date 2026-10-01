import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let transposeUp = Self("transposeUp", default: .init(.upArrow, modifiers: [.control, .option, .command]))
    static let transposeDown = Self("transposeDown", default: .init(.downArrow, modifiers: [.control, .option, .command]))
    static let transposeReset = Self("transposeReset", default: .init(.zero, modifiers: [.control, .option, .command]))
}

@MainActor
final class HotkeyService {
    private let controller: TransposeController
    /// Repeated keyDowns without a keyUp count as key repeat; times out in case a keyUp is missed.
    private var held: [KeyboardShortcuts.Name: Date] = [:]
    private let repeatWindow: TimeInterval = 1.0

    init(controller: TransposeController) {
        self.controller = controller
        register(.transposeUp, action: .up)
        register(.transposeDown, action: .down)
        register(.transposeReset, action: .reset)
    }

    private func register(_ name: KeyboardShortcuts.Name, action: TransposeAction) {
        KeyboardShortcuts.onKeyDown(for: name) { [weak self] in
            MainActor.assumeIsolated { self?.keyDown(name, action: action) }
        }
        KeyboardShortcuts.onKeyUp(for: name) { [weak self] in
            MainActor.assumeIsolated { _ = self?.held.removeValue(forKey: name) }
        }
    }

    private func keyDown(_ name: KeyboardShortcuts.Name, action: TransposeAction) {
        let now = Date()
        let isRepeat = held[name].map { now.timeIntervalSince($0) < repeatWindow } ?? false
        held[name] = now
        controller.handleKeyPress(action, isRepeat: isRepeat)
    }
}
