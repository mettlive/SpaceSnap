import SwiftUI

struct GeneralSettingsTab: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Toggle("Мгновенный свайп трекпадом", isOn: $model.settings.interceptsTrackpadSwipes)
            Toggle("Показывать индикатор при переключении", isOn: $model.settings.showsOverlay)

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Не перебрасывать с пустого рабочего стола", isOn: $model.settings.preventsEmptyDesktopYank)
                Text("macOS автоматически возвращает вас с пустого рабочего стола примерно через 0.4 секунды — эта опция это предотвращает.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Мгновенный переход к приложению (Dock, ⌘Tab)", isOn: $model.settings.followsAppActivationInstantly)
                Text("Заменяет анимированный переход Dock на стол с окном приложения. При включении и выключении Dock перезапускается; при выходе из SpaceSnap стандартное поведение возвращается.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("Показывать номер рабочего стола в строке меню", isOn: $model.settings.showsSpaceNumberInMenuBar)

            Divider()

            LaunchAtLoginToggle()

            Divider()

            AccessibilityStatusRow(isGranted: model.isAccessibilityGranted)
        }
        .padding()
    }
}
