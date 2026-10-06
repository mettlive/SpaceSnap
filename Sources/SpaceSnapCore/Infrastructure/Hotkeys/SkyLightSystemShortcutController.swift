import CoreGraphics

@MainActor
public final class SkyLightSystemShortcutController: SystemShortcutController {
    private static let moveBetweenSpaces: ClosedRange<Int32> = 79...82
    private static let switchToDesktop: ClosedRange<Int32> = 118...133
    private static let unassignedKeyCode: UInt16 = 0xFFFF

    public init() {}

    public func spaceShortcuts() -> [SystemShortcut] {
        (Array(Self.moveBetweenSpaces) + Array(Self.switchToDesktop)).compactMap(shortcut)
    }

    public func setEnabled(_ enabled: Bool, shortcutID: Int32) {
        _ = SLSSetSymbolicHotKeyEnabled(shortcutID, enabled)
    }

    private func shortcut(_ id: Int32) -> SystemShortcut? {
        var character: UInt16 = 0
        var keyCode: UInt16 = 0
        var flags: UInt32 = 0
        guard SLSGetSymbolicHotKeyValue(id, &character, &keyCode, &flags) == 0,
              keyCode != Self.unassignedKeyCode
        else { return nil }
        let combo = KeyCombo(keyCode: keyCode, modifiers: Self.modifiers(CGEventFlags(rawValue: UInt64(flags))))
        return SystemShortcut(id: id, combo: combo, isEnabled: SLSIsSymbolicHotKeyEnabled(id))
    }

    private static func modifiers(_ flags: CGEventFlags) -> KeyModifiers {
        KeyModifiers.displayOrder.reduce(into: KeyModifiers()) { result, modifier in
            if flags.contains(cgEventFlag(for: modifier)) { result.insert(modifier) }
        }
    }

    private static func cgEventFlag(for modifier: KeyModifiers) -> CGEventFlags {
        switch modifier {
        case .control: .maskControl
        case .option: .maskAlternate
        case .shift: .maskShift
        case .command: .maskCommand
        default: []
        }
    }
}
