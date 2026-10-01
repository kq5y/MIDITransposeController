import Foundation

/// Never talks to real MIDI devices when hosting unit tests.
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let controller: TransposeController
    private var hotkeys: HotkeyService?

    private init() {
        let store = SettingsStore()
        let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
        let output: MIDIOutput = isTesting ? NullMIDIOutput() : MIDIService()

        controller = TransposeController(settings: store.load(), output: output, store: store)

        guard !isTesting else { return }
        hotkeys = HotkeyService(controller: controller)
        controller.handleLaunch()
    }
}
