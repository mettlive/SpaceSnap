import SwiftUI
import SpaceSnapCore

struct ShortcutsSettingsTab: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            HStack {
                Text("Влево")
                Spacer()
                ShortcutRecorder(combo: $model.settings.hotkeys.left)
            }
            HStack {
                Text("Вправо")
                Spacer()
                ShortcutRecorder(combo: $model.settings.hotkeys.right)
            }
            HStack {
                Text("Предыдущий рабочий стол")
                Spacer()
                ShortcutRecorder(combo: $model.settings.hotkeys.previous)
            }

            Divider()

            DesktopDirectShortcutSection(modifiers: $model.settings.hotkeys.desktopModifiers)

            Text("Конфликтующие системные сочетания Mission Control отключаются на время работы SpaceSnap и восстанавливаются при выходе.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
