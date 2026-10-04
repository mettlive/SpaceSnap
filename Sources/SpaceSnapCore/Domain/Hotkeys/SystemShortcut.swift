public struct SystemShortcut: Sendable, Equatable {
    public let id: Int32
    public let combo: KeyCombo
    public let isEnabled: Bool

    public init(id: Int32, combo: KeyCombo, isEnabled: Bool) {
        self.id = id
        self.combo = combo
        self.isEnabled = isEnabled
    }

    public static func conflicting(_ shortcuts: [SystemShortcut], with combos: Set<KeyCombo>) -> Set<Int32> {
        Set(shortcuts.lazy.filter { $0.isEnabled && combos.contains($0.combo) }.map(\.id))
    }
}

@MainActor
public protocol SystemShortcutController: AnyObject {
    func spaceShortcuts() -> [SystemShortcut]
    func setEnabled(_ enabled: Bool, shortcutID: Int32)
}
