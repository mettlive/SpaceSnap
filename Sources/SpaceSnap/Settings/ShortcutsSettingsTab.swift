import SwiftUI
import SpaceSnapCore

struct ShortcutsSettingsTab: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            HStack {
                Text("Desktop on the left")
                Spacer()
                ShortcutRecorder(combo: $model.settings.hotkeys.left)
            }
            HStack {
                Text("Desktop on the right")
                Spacer()
                ShortcutRecorder(combo: $model.settings.hotkeys.right)
            }
            HStack {
                Text("Back to previous desktop")
                Spacer()
                ShortcutRecorder(combo: $model.settings.hotkeys.previous)
            }

            Divider()

            DesktopDirectShortcutSection(modifiers: $model.settings.hotkeys.desktopModifiers)

            Text("Conflicting Mission Control shortcuts are turned off while SpaceSnap runs and restored when it quits.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
