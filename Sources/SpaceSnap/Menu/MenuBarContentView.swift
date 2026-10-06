import SwiftUI
import SpaceSnapCore

struct MenuBarContentView: View {
    let model: AppModel
    let openSettings: () -> Void

    var body: some View {
        if let spaces = model.activeSpaces {
            ForEach(Array(spaces.spaces.enumerated()), id: \.element.id) { index, space in
                desktopRow(for: space, at: index, in: spaces)
            }
            Divider()
        }

        if model.needsRelaunch {
            Button("Relaunch SpaceSnap") {
                model.relaunch()
            }
            Divider()
        }

        if !model.isAccessibilityGranted {
            Text("No Accessibility access")
            Button("Grant Accessibility Access…") {
                AccessibilityPermission.openSystemSettings()
            }
            Divider()
        }

        Button("Settings…") {
            openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        Button("Quit SpaceSnap") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    @ViewBuilder
    private func desktopRow(for space: Space, at index: Int, in spaces: DisplaySpaces) -> some View {
        switch space.kind {
        case .desktop:
            let number = spaces.desktopNumber(at: index) ?? 0
            Button {
                model.handle(.space(space.id))
            } label: {
                HStack {
                    if index == spaces.currentIndex {
                        Image(systemName: "checkmark")
                    }
                    Text("Desktop \(number)")
                }
            }
        case .fullscreen:
            Button("Fullscreen App") {}
                .disabled(true)
        }
    }
}
