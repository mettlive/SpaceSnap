import SwiftUI
import SpaceSnapCore

struct ShortcutsSettingsTab: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            HStack {
                Text("Desktop on the left")
                Spacer()
                ShortcutRecorder(combo: $model.settings.hotkeys.left, onRecordingChange: model.setHotkeysSuspended)
            }
            HStack {
                Text("Desktop on the right")
                Spacer()
                ShortcutRecorder(combo: $model.settings.hotkeys.right, onRecordingChange: model.setHotkeysSuspended)
            }
            HStack {
                Text("Back to previous desktop")
                Spacer()
                ShortcutRecorder(combo: $model.settings.hotkeys.previous, onRecordingChange: model.setHotkeysSuspended)
            }

            Divider()

            DesktopDirectShortcutSection(modifiers: $model.settings.hotkeys.desktopModifiers)

            if !model.unavailableCombos.isEmpty {
                Label("Used by another app: \(unavailableShortcuts)", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Text("Conflicting Mission Control shortcuts are turned off while SpaceSnap runs and restored when it quits.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var unavailableShortcuts: String {
        model.unavailableCombos
            .map(KeyComboFormatter.string(for:))
            .sorted()
            .joined(separator: ", ")
    }
}
