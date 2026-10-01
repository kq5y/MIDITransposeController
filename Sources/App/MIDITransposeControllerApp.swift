import AppKit
import SwiftUI

@main
struct MIDITransposeControllerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    /// Not observed here: observing would re-evaluate every scene on each change.
    private let controller = AppEnvironment.shared.controller

    var body: some Scene {
        Window("MIDI Transpose", id: MainView.windowID) {
            MainView()
                .environmentObject(controller)
        }
        .defaultSize(width: 420, height: 340)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
                .environmentObject(controller)
        }

        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(controller)
        } label: {
            MenuBarLabel(controller: controller)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Keep running for the menu bar after the window is closed.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
