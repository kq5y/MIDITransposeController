import AppKit
import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject var controller: TransposeController

    var body: some View {
        Text(controller.menuBarTitle)
    }
}

struct MenuBarContentView: View {
    @EnvironmentObject private var controller: TransposeController
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("+1") { controller.perform(.up) }
        Button("\u{2212}1") { controller.perform(.down) }
        Button("リセット") { controller.perform(.reset) }
        Divider()
        Button("ウィンドウを表示") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: MainView.windowID)
        }
        Button("設定…") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        .keyboardShortcut(",")
        Divider()
        Button("終了") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
