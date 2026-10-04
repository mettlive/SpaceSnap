import SwiftUI

struct SettingsView: View {
    let model: AppModel

    var body: some View {
        TabView {
            GeneralSettingsTab(model: model)
                .tabItem { Label("Основные", systemImage: "gearshape") }
            ShortcutsSettingsTab(model: model)
                .tabItem { Label("Сочетания клавиш", systemImage: "keyboard") }
        }
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
