import SwiftUI
import SpaceSnapCore

struct AccessibilityStatusRow: View {
    let isGranted: Bool

    var body: some View {
        HStack {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isGranted ? .green : .orange)
            Text(isGranted ? "Доступ к Универсальному доступу предоставлен" : "Нет доступа к Универсальному доступу")
            Spacer()
            if !isGranted {
                Button("Открыть настройки…") {
                    AccessibilityPermission.openSystemSettings()
                }
            }
        }
    }
}
