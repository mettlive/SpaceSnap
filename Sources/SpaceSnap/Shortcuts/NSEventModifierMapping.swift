import AppKit
import SpaceSnapCore

enum NSEventModifierMapping {
    static let relevantFlags: NSEvent.ModifierFlags = [.control, .option, .shift, .command]

    static func keyModifiers(from flags: NSEvent.ModifierFlags) -> KeyModifiers {
        KeyModifiers.displayOrder.reduce(into: KeyModifiers()) { result, modifier in
            if flags.contains(nsEventFlag(for: modifier)) { result.insert(modifier) }
        }
    }

    private static func nsEventFlag(for modifier: KeyModifiers) -> NSEvent.ModifierFlags {
        switch modifier {
        case .control: .control
        case .option: .option
        case .shift: .shift
        case .command: .command
        default: []
        }
    }
}
