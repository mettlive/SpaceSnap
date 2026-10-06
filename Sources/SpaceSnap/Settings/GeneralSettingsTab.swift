import SwiftUI

struct GeneralSettingsTab: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Toggle("Instant trackpad swipe", isOn: $model.settings.interceptsTrackpadSwipes)
            Toggle("Show overlay when switching", isOn: $model.settings.showsOverlay)

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Stay on empty desktops", isOn: $model.settings.preventsEmptyDesktopYank)
                Text("About 0.4 s after you land on an empty desktop, macOS activates another app and switches to its desktop. This option prevents that.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Instant jump to an app's desktop (Dock, ⌘Tab)", isOn: $model.settings.followsAppActivationInstantly)
                Text("Replaces the Dock's animated switch to the desktop with the app's window. The Dock restarts when this is turned on or off; the default behavior is restored when SpaceSnap quits.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("Show desktop number in the menu bar", isOn: $model.settings.showsSpaceNumberInMenuBar)

            Divider()

            LaunchAtLoginToggle()

            Divider()

            AccessibilityStatusRow(isGranted: model.isAccessibilityGranted)
        }
        .padding()
    }
}
