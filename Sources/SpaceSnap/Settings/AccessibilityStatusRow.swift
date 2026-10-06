import SwiftUI
import SpaceSnapCore

struct AccessibilityStatusRow: View {
    let isGranted: Bool

    var body: some View {
        HStack {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isGranted ? .green : .orange)
            Text(isGranted ? "Accessibility access granted" : "No Accessibility access")
            Spacer()
            if !isGranted {
                Button("Open System Settings…") {
                    AccessibilityPermission.openSystemSettings()
                }
            }
        }
    }
}
