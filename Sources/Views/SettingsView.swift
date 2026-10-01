import KeyboardShortcuts
import SwiftUI

/// All tabs share one fixed size so switching tabs doesn't resize the window.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("一般", systemImage: "gearshape") }
            SysExTab()
                .tabItem { Label("SysEx", systemImage: "pianokeys") }
            ShortcutTab()
                .tabItem { Label("ショートカット", systemImage: "keyboard") }
        }
        .frame(width: 420, height: 300)
    }
}

private struct GeneralTab: View {
    @EnvironmentObject private var controller: TransposeController

    var body: some View {
        Form {
            Picker("基準キー", selection: $controller.settings.baseKey) {
                ForEach(0..<12, id: \.self) { key in
                    Text(KeyName.name(base: key, offset: 0, preferFlats: controller.settings.preferFlats))
                        .tag(key)
                }
            }
            .fixedSize()
            Picker("表記", selection: $controller.settings.preferFlats) {
                Text("♯").tag(false)
                Text("♭").tag(true)
            }
            .pickerStyle(.segmented)
            .fixedSize()
            boundStepper("下限", value: $controller.settings.lowerBound, in: -64...0)
            boundStepper("上限", value: $controller.settings.upperBound, in: 0...63)
            Picker("範囲端", selection: $controller.settings.rangeBehavior) {
                Text("止める").tag(RangeBehavior.clamp)
                Text("反対側へ").tag(RangeBehavior.wrap)
            }
            .pickerStyle(.segmented)
            .fixedSize()
            Picker("起動時", selection: $controller.settings.launchBehavior) {
                Text("0 にリセット").tag(LaunchBehavior.resetToZero)
                Text("前回値を復元").tag(LaunchBehavior.restoreLast)
            }
            .fixedSize()
            Toggle("再接続時に再送", isOn: $controller.settings.resendOnReconnect)
            Toggle("キーリピートを許可", isOn: $controller.settings.allowKeyRepeat)
            Toggle("常に手前に表示", isOn: $controller.settings.alwaysOnTop)
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func boundStepper(_ title: String, value: Binding<Int>, in range: ClosedRange<Int>) -> some View {
        LabeledContent(title) {
            HStack {
                Text(KeyName.offsetLabel(value.wrappedValue)).monospacedDigit()
                Stepper(title, value: value, in: range).labelsHidden()
            }
        }
    }
}

private struct SysExTab: View {
    @EnvironmentObject private var controller: TransposeController
    @State private var draft = ""

    var body: some View {
        Form {
            LabeledContent("テンプレート") {
                TextField("テンプレート", text: $draft)
                    .font(.body.monospaced())
                    .labelsHidden()
                    .onChange(of: draft) { _, newValue in commitIfValid(newValue) }
            }
            LabeledContent("送信内容") {
                templateStatus
            }
            LabeledContent("書式") {
                VStack(alignment: .leading, spacing: 3) {
                    Text("16進数2桁のバイトを空白区切り")
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 3) {
                        GridRow {
                            Text("{v:offset64}")
                            Text("64 + 値")
                        }
                        GridRow {
                            Text("{v:signed7}")
                            Text("7bitの2の補数")
                        }
                        GridRow {
                            Text("{v:nibble}")
                            Text("8bitの2の補数を上位・下位4bitに分割")
                        }
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            LabeledContent("") {
                Button("初期値に戻す") {
                    controller.loadPreset(.masterCoarseTuning)
                    draft = controller.settings.sysexTemplate
                }
            }
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear { draft = controller.settings.sysexTemplate }
    }

    @ViewBuilder
    private var templateStatus: some View {
        switch validate(draft) {
        case .success(let bytes):
            Text(SysExBuilder.hexString(bytes))
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        case .failure(let error):
            Text(error.localizedDescription)
                .font(.callout)
                .foregroundStyle(.red)
        }
    }

    /// The template must also encode both range bounds.
    private func validate(_ template: String) -> Result<[UInt8], Error> {
        Result {
            let settings = controller.settings
            _ = try SysExBuilder.build(template, value: settings.lowerBound)
            _ = try SysExBuilder.build(template, value: settings.upperBound)
            return try SysExBuilder.build(template, value: controller.offset)
        }
    }

    private func commitIfValid(_ template: String) {
        guard template != controller.settings.sysexTemplate,
              case .success = validate(template) else { return }
        controller.settings.sysexTemplate = template
    }
}

private struct ShortcutTab: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("+1", name: .transposeUp)
            KeyboardShortcuts.Recorder("\u{2212}1", name: .transposeDown)
            KeyboardShortcuts.Recorder("リセット", name: .transposeReset)
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
