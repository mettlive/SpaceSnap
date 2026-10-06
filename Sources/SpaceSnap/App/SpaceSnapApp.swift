import SwiftUI

@main
struct SpaceSnapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(model: appDelegate.model, openSettings: openSettingsWindow)
        } label: {
            MenuBarLabelView(model: appDelegate.model)
        }
        .menuBarExtraStyle(.menu)

        Window("SpaceSnap Settings", id: "settings") {
            SettingsView(model: appDelegate.model)
        }
        .defaultLaunchBehavior(.suppressed)
        .windowResizability(.contentSize)
    }

    private func openSettingsWindow() {
        openWindow(id: "settings")
        NSApp.activate()
    }
}
