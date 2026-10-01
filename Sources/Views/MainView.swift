import AppKit
import SwiftUI

struct MainView: View {
    static let windowID = "main"

    @EnvironmentObject private var controller: TransposeController
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                DestinationPicker()
                    .frame(maxWidth: 280, alignment: .leading)
                Spacer()
                SettingsLink {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help("設定")
            }

            Spacer(minLength: 0)

            HStack(spacing: 20) {
                StepButton(systemImage: "minus", help: "−1 (↓ / ←)") { controller.perform(.down) }
                TransposeDisplayView()
                StepButton(systemImage: "plus", help: "+1 (↑ / →)") { controller.perform(.up) }
            }

            Button {
                controller.perform(.reset)
            } label: {
                Text("0")
                    .font(.title3.monospacedDigit())
                    .frame(width: 44)
            }
            .controlSize(.large)
            .focusable(false)
            .help("リセット (0)")

            Spacer(minLength: 0)

            StatusBarView()
        }
        .padding()
        .frame(minWidth: 360, minHeight: 300)
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onKeyPress(keys: [.upArrow, .rightArrow], phases: [.down, .repeat]) { press in
            controller.handleKeyPress(.up, isRepeat: press.phase == .repeat)
            return .handled
        }
        .onKeyPress(keys: [.downArrow, .leftArrow], phases: [.down, .repeat]) { press in
            controller.handleKeyPress(.down, isRepeat: press.phase == .repeat)
            return .handled
        }
        .onKeyPress(keys: ["0"], phases: [.down, .repeat]) { press in
            controller.handleKeyPress(.reset, isRepeat: press.phase == .repeat)
            return .handled
        }
        .onAppear { focused = true }
        .background(WindowLevelSetter(floating: controller.settings.alwaysOnTop))
    }
}

private struct StepButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .frame(width: 44, height: 44)
        }
        .controlSize(.large)
        .focusable(false)
        .help(help)
    }
}

private struct DestinationPicker: View {
    @EnvironmentObject private var controller: TransposeController

    var body: some View {
        Picker("Output:", selection: Binding(
            get: { controller.settings.destinationUniqueID },
            set: { controller.selectDestination($0) }
        )) {
            Text("なし").tag(Int32?.none)
            ForEach(controller.destinations) { destination in
                Text(destination.name).tag(Int32?.some(destination.uniqueID))
            }
            if let uid = controller.settings.destinationUniqueID, !controller.isDestinationConnected {
                Text("未接続のデバイス").tag(Int32?.some(uid))
            }
        }
    }
}

struct WindowLevelSetter: NSViewRepresentable {
    let floating: Bool

    func makeNSView(context: Context) -> LevelView {
        let view = LevelView()
        view.floating = floating
        return view
    }

    func updateNSView(_ view: LevelView, context: Context) {
        view.floating = floating
    }

    final class LevelView: NSView {
        var floating = false {
            didSet { if floating != oldValue { apply() } }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
        }

        private func apply() {
            window?.level = floating ? .floating : .normal
        }
    }
}
