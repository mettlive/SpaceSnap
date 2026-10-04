import AppKit
import Observation
import SpaceSnapCore

@MainActor
@Observable
final class AppModel {
    var settings: AppSettings {
        didSet { applySettings() }
    }

    private(set) var activeSpaces: DisplaySpaces?
    private(set) var isAccessibilityGranted: Bool
    private(set) var needsRelaunch = false

    private let settingsStore: SettingsStore
    private let service: SpaceSwitchService
    private let shortcutCoordinator: SystemShortcutCoordinator
    private let emptyDesktopGuard: EmptyDesktopGuard
    private let overlay: SpaceOverlayController
    private var accessibilityPollTask: Task<Void, Never>?
    private var settleTask: Task<Void, Never>?
    private var workspaceObservers: [NSObjectProtocol] = []

    @ObservationIgnored
    private lazy var interceptor = TrackpadSwipeInterceptor { [weak self] direction in
        self?.handle(.neighbor(direction))
    }

    @ObservationIgnored
    private lazy var hotkeyRegistry = CarbonHotkeyRegistry { [weak self] target in
        self?.handle(target)
    }

    init(settingsStore: SettingsStore = SettingsStore()) {
        self.settingsStore = settingsStore
        self.settings = settingsStore.load()
        self.isAccessibilityGranted = AccessibilityPermission.isGranted
        self.service = SpaceSwitchService(
            repository: SkyLightSpaceRepository(),
            emitter: DockSwipeGestureEmitter(),
            predictionWindow: DockSwipeGestureEmitter.predictionWindow
        )
        self.shortcutCoordinator = SystemShortcutCoordinator(controller: SkyLightSystemShortcutController())
        self.emptyDesktopGuard = EmptyDesktopGuard()
        self.overlay = SpaceOverlayController()

        let center = NSWorkspace.shared.notificationCenter
        let spaceObserver = center.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.spaceDidChange()
            }
        }
        let activationObserver = center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshActiveSpaces()
            }
        }
        workspaceObservers = [spaceObserver, activationObserver]
    }

    func start() {
        service.recordSettledSpaces()
        refreshActiveSpaces()
        if AccessibilityPermission.isGranted {
            isAccessibilityGranted = true
            applySettings()
        } else {
            isAccessibilityGranted = false
            AccessibilityPermission.requestPrompt()
            pollAccessibility()
        }
    }

    func handle(_ target: SwitchTarget) {
        guard let landing = service.perform(target) else { return }
        if settings.showsOverlay {
            overlay.show(landing)
        }
    }

    func restoreSystemShortcuts() {
        shortcutCoordinator.restore()
    }

    func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(
            at: Bundle.main.bundleURL,
            configuration: configuration,
            completionHandler: nil
        )
        NSApp.terminate(nil)
    }

    private func pollAccessibility() {
        accessibilityPollTask = Task { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                if AccessibilityPermission.isGranted {
                    self.isAccessibilityGranted = true
                    self.applySettings()
                    return
                }
            }
        }
    }

    private func applySettings() {
        settingsStore.save(settings)
        guard isAccessibilityGranted else { return }
        let actions = settings.hotkeys.actions()
        _ = hotkeyRegistry.register(actions)
        shortcutCoordinator.reconcile(with: Set(actions.keys))
        if settings.interceptsTrackpadSwipes {
            needsRelaunch = !interceptor.setEnabled(true)
        } else {
            _ = interceptor.setEnabled(false)
            needsRelaunch = false
        }
    }

    private func refreshActiveSpaces() {
        activeSpaces = service.activeDisplaySpaces()
    }

    private func spaceDidChange() {
        if settings.preventsEmptyDesktopYank {
            emptyDesktopGuard.handleSpaceChange()
        }
        refreshActiveSpaces()
        scheduleSettle()
    }

    private func scheduleSettle() {
        settleTask?.cancel()
        settleTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard let self, !Task.isCancelled else { return }
            self.service.recordSettledSpaces()
        }
    }
}
