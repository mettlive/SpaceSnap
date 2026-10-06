import SwiftUI
import SpaceSnapCore

struct DesktopDirectShortcutSection: View {
    @Binding var modifiers: KeyModifiers?

    private var isEnabled: Bool {
        modifiers != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Jump directly to desktop 1–10", isOn: Binding(
                get: { isEnabled },
                set: { newValue in
                    modifiers = newValue ? (modifiers ?? .control) : nil
                }
            ))

            if let current = modifiers {
                HStack(spacing: 12) {
                    ForEach(KeyModifiers.displayOrder, id: \.rawValue) { modifier in
                        modifierToggle(modifier, current: current)
                    }
                }
                Text(previewText(for: current))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func modifierToggle(_ modifier: KeyModifiers, current: KeyModifiers) -> some View {
        Toggle(KeyComboFormatter.symbol(for: modifier), isOn: Binding(
            get: { current.contains(modifier) },
            set: { isOn in
                var updated = current
                if isOn {
                    updated.insert(modifier)
                } else {
                    updated.remove(modifier)
                }
                guard !updated.isEmpty else { return }
                modifiers = updated
            }
        ))
        .toggleStyle(.button)
    }

    private func previewText(for modifiers: KeyModifiers) -> String {
        let prefix = KeyComboFormatter.modifierSymbols(modifiers)
        return "\(prefix)1 … \(prefix)0"
    }
}
