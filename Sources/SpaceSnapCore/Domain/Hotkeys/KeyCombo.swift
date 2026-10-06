public struct KeyModifiers: OptionSet, Sendable, Hashable, Codable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let control = KeyModifiers(rawValue: 1 << 0)
    public static let option = KeyModifiers(rawValue: 1 << 1)
    public static let shift = KeyModifiers(rawValue: 1 << 2)
    public static let command = KeyModifiers(rawValue: 1 << 3)

    public static let displayOrder: [KeyModifiers] = [.control, .option, .shift, .command]
}

public struct KeyCombo: Sendable, Hashable, Codable {
    public let keyCode: UInt16
    public let modifiers: KeyModifiers

    public init(keyCode: UInt16, modifiers: KeyModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

public enum KeyCode {
    public static let leftArrow: UInt16 = 123
    public static let rightArrow: UInt16 = 124
    public static let grave: UInt16 = 50
    public static let desktopDigits: [UInt16] = [18, 19, 20, 21, 23, 22, 26, 28, 25, 29]
}
