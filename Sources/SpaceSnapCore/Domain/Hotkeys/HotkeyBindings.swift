public struct HotkeyBindings: Sendable, Equatable, Codable {
    public var left: KeyCombo?
    public var right: KeyCombo?
    public var previous: KeyCombo?
    public var desktopModifiers: KeyModifiers?

    public init(left: KeyCombo?, right: KeyCombo?, previous: KeyCombo?, desktopModifiers: KeyModifiers?) {
        self.left = left
        self.right = right
        self.previous = previous
        self.desktopModifiers = desktopModifiers
    }

    public static let `default` = HotkeyBindings(
        left: KeyCombo(keyCode: KeyCode.leftArrow, modifiers: .control),
        right: KeyCombo(keyCode: KeyCode.rightArrow, modifiers: .control),
        previous: KeyCombo(keyCode: KeyCode.grave, modifiers: .control),
        desktopModifiers: .control
    )

    public func actions() -> [KeyCombo: SwitchTarget] {
        var actions: [KeyCombo: SwitchTarget] = [:]
        let explicit: [(KeyCombo?, SwitchTarget)] = [
            (left, .neighbor(.left)),
            (right, .neighbor(.right)),
            (previous, .previous),
        ]
        for case let (combo?, target) in explicit where actions[combo] == nil {
            actions[combo] = target
        }
        if let desktopModifiers, !desktopModifiers.isEmpty {
            for (offset, keyCode) in KeyCode.desktopDigits.enumerated() {
                let combo = KeyCombo(keyCode: keyCode, modifiers: desktopModifiers)
                if actions[combo] == nil {
                    actions[combo] = .desktop(offset + 1)
                }
            }
        }
        return actions
    }
}
