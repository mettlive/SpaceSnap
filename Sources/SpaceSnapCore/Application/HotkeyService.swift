@MainActor
public final class HotkeyService {
    private let registry: HotkeyRegistry
    private let systemShortcuts: SystemShortcutCoordinator
    private var bindings: HotkeyBindings?
    private var suspensionCount = 0
    public private(set) var unavailableCombos: Set<KeyCombo> = []

    public init(registry: HotkeyRegistry, systemShortcuts: SystemShortcutCoordinator) {
        self.registry = registry
        self.systemShortcuts = systemShortcuts
    }

    public func apply(_ bindings: HotkeyBindings) {
        self.bindings = bindings
        guard suspensionCount == 0 else { return }
        register(bindings)
    }

    public func suspend() {
        suspensionCount += 1
        guard suspensionCount == 1 else { return }
        registry.unregisterAll()
    }

    public func resume() {
        guard suspensionCount > 0 else { return }
        suspensionCount -= 1
        guard suspensionCount == 0, let bindings else { return }
        register(bindings)
    }

    public func restore() {
        registry.unregisterAll()
        systemShortcuts.restore()
        bindings = nil
        unavailableCombos = []
    }

    private func register(_ bindings: HotkeyBindings) {
        let actions = bindings.actions()
        unavailableCombos = registry.register(actions)
        systemShortcuts.reconcile(with: Set(actions.keys).subtracting(unavailableCombos))
    }
}
