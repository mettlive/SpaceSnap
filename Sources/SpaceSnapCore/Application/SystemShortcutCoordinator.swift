@MainActor
public final class SystemShortcutCoordinator {
    private let controller: SystemShortcutController
    private var disabledByApp: Set<Int32> = []

    public init(controller: SystemShortcutController) {
        self.controller = controller
    }

    public func reconcile(with combos: Set<KeyCombo>) {
        let shortcuts = controller.spaceShortcuts().map { shortcut in
            disabledByApp.contains(shortcut.id)
                ? SystemShortcut(id: shortcut.id, combo: shortcut.combo, isEnabled: true)
                : shortcut
        }
        let conflicting = SystemShortcut.conflicting(shortcuts, with: combos)
        for id in disabledByApp.subtracting(conflicting) {
            controller.setEnabled(true, shortcutID: id)
        }
        for id in conflicting.subtracting(disabledByApp) {
            controller.setEnabled(false, shortcutID: id)
        }
        disabledByApp = conflicting
    }

    public func restore() {
        reconcile(with: [])
    }
}
