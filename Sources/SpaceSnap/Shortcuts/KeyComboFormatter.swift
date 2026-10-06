import Carbon.HIToolbox
import SpaceSnapCore

enum KeyComboFormatter {
    static func modifierSymbols(_ modifiers: KeyModifiers) -> String {
        KeyModifiers.displayOrder
            .filter { modifiers.contains($0) }
            .map(symbol(for:))
            .joined()
    }

    static func symbol(for modifier: KeyModifiers) -> String {
        switch modifier {
        case .control: "⌃"
        case .option: "⌥"
        case .shift: "⇧"
        case .command: "⌘"
        default: ""
        }
    }

    static func string(for combo: KeyCombo) -> String {
        modifierSymbols(combo.modifiers) + keySymbol(for: combo.keyCode)
    }

    private static func keySymbol(for keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_LeftArrow: "←"
        case kVK_RightArrow: "→"
        case kVK_UpArrow: "↑"
        case kVK_DownArrow: "↓"
        case kVK_Space: "Space"
        case kVK_Return: "↩"
        case kVK_Tab: "⇥"
        case kVK_Escape: "⎋"
        case kVK_Delete: "⌫"
        case kVK_F1: "F1"
        case kVK_F2: "F2"
        case kVK_F3: "F3"
        case kVK_F4: "F4"
        case kVK_F5: "F5"
        case kVK_F6: "F6"
        case kVK_F7: "F7"
        case kVK_F8: "F8"
        case kVK_F9: "F9"
        case kVK_F10: "F10"
        case kVK_F11: "F11"
        case kVK_F12: "F12"
        default: characterSymbol(for: keyCode)
        }
    }

    private static func characterSymbol(for keyCode: UInt16) -> String {
        guard let inputSource = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutDataPointer = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData)
        else { return "?" }

        let layoutData = Unmanaged<CFData>.fromOpaque(layoutDataPointer).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0

        let status = layoutData.withUnsafeBytes { buffer -> OSStatus in
            let layout = buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress!
            return UCKeyTranslate(
                layout,
                keyCode,
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &length,
                &chars
            )
        }

        guard status == noErr, length > 0 else { return "?" }
        return String(utf16CodeUnits: chars, count: length).uppercased()
    }
}
