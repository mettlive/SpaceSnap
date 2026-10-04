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
            Button("Перезапустить SpaceSnap") {
                model.relaunch()
            }
            Divider()
        }

        if !model.isAccessibilityGranted {
            Text("Нет доступа к Универсальному доступу")
            Button("Выдать доступ к Универсальному доступу…") {
                AccessibilityPermission.openSystemSettings()
            }
            Divider()
        }

        Button("Настройки…") {
            openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        Button("Выйти") {
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
                model.handle(.desktop(number))
            } label: {
                HStack {
                    if index == spaces.currentIndex {
                        Image(systemName: "checkmark")
                    }
                    Text("Рабочий стол \(number)")
                }
            }
        case .fullscreen:
            Button("Полноэкранное приложение") {}
                .disabled(true)
        }
    }
}
