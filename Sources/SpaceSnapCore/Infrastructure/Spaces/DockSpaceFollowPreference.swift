import Foundation

@MainActor
public final class DockSpaceFollowPreference {
    private enum OriginalValue: String {
        case absent
        case enabled
    }

    private static let dockDomain = "com.apple.dock" as CFString
    private static let followKey = "workspaces-auto-swoosh" as CFString
    private static let switchOnActivateKey = "AppleSpacesSwitchOnActivate" as CFString
    private static let originalValueKey = "suppressedDockSpaceFollowOriginal"

    private let store: UserDefaults

    public init(store: UserDefaults = .standard) {
        self.store = store
    }

    public static var switchesToAppSpaceOnActivation: Bool {
        CFPreferencesCopyAppValue(switchOnActivateKey, kCFPreferencesAnyApplication) as? Bool ?? true
    }

    public func suppress() {
        guard originalValue == nil else { return }
        CFPreferencesAppSynchronize(Self.dockDomain)
        let current = CFPreferencesCopyAppValue(Self.followKey, Self.dockDomain) as? Bool
        guard current != false else { return }
        originalValue = current == nil ? .absent : .enabled
        writeFollow(false)
    }

    public func restore() {
        guard let originalValue else { return }
        writeFollow(originalValue == .enabled ? true : nil)
        self.originalValue = nil
    }

    private var originalValue: OriginalValue? {
        get { store.string(forKey: Self.originalValueKey).flatMap(OriginalValue.init(rawValue:)) }
        set { store.set(newValue?.rawValue, forKey: Self.originalValueKey) }
    }

    private func writeFollow(_ value: Bool?) {
        CFPreferencesSetValue(
            Self.followKey,
            value as CFPropertyList?,
            Self.dockDomain,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        CFPreferencesSynchronize(Self.dockDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        relaunchDock()
    }

    private func relaunchDock() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Dock"]
        try? process.run()
    }
}
