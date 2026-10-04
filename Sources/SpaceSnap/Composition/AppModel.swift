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
    private let followService: ActivationFollowService
    private let dockFollowPreference: DockSpaceFollowPreference
    private let shortcutCoordinator: SystemShortcutCoordinator
    private let emptyDesktopGuard: EmptyDesktopGuard
    private let overlay: SpaceOverlayController
    private var accessibilityPollTask: Task<Void, Never>?
    private var settleTask: Task<Void, Never>?
    private var followTask: Task<Void, Never>?
    private var workspaceObservers: [NSObjectProtocol] = []

    @ObservationIgnored
    private var pendingOverlay: PendingOverlay?

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
        let service = SpaceSwitchService(
            repository: SkyLightSpaceRepository(),
            emitter: DockSwipeGestureEmitter(),
            predictionWindow: DockSwipeGestureEmitter.predictionWindow
        )
        self.service = service
        self.followService = ActivationFollowService(
            locator: CGWindowAppWindowLocator(),
            switcher: service,
            landingQuietPeriod: 0.5
        )
        self.dockFollowPreference = DockSpaceFollowPreference()
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
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let processID = app?.processIdentifier
            MainActor.assumeIsolated {
                self?.appDidActivate(processID: processID)
            }
        }
        workspaceObservers = [spaceObserver, activationObserver]
    }

    func start() {
        service.recordSettledSpaces()
        refreshActiveSpaces()
        isAccessibilityGranted = AccessibilityPermission.isGranted
        applySettings()
        guard !isAccessibilityGranted else { return }
        AccessibilityPermission.requestPrompt()
        pollAccessibility()
    }

    func handle(_ target: SwitchTarget) {
        guard let landing = service.perform(target) else { return }
        present(landing)
    }

    func restoreSystemState() {
        shortcutCoordinator.restore()
        dockFollowPreference.restore()
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
        if settings.followsAppActivationInstantly && isAccessibilityGranted {
            dockFollowPreference.suppress()
        } else {
            dockFollowPreference.restore()
        }
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

    private func present(_ landing: DisplaySpaces) {
        pendingOverlay = settings.showsOverlay ? PendingOverlay(landing: landing, requestedAt: .now) : nil
    }

    private func appDidActivate(processID: pid_t?) {
        refreshActiveSpaces()
        followTask?.cancel()
        guard settings.followsAppActivationInstantly,
              isAccessibilityGranted,
              let processID,
              processID != ProcessInfo.processInfo.processIdentifier,
              DockSpaceFollowPreference.switchesToAppSpaceOnActivation
        else { return }
        followTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(80))
            guard let self, !Task.isCancelled,
                  let landing = self.followService.appDidActivate(processID: processID)
            else { return }
            self.present(landing)
        }
    }

    private func spaceDidChange() {
        if settings.preventsEmptyDesktopYank {
            emptyDesktopGuard.handleSpaceChange()
        }
        refreshActiveSpaces()
        followService.spaceDidChange()
        followTask?.cancel()
        showOverlayIfLanded()
        scheduleSettle()
    }

    private func showOverlayIfLanded() {
        guard let pending = pendingOverlay else { return }
        guard Date.now.timeIntervalSince(pending.requestedAt) < PendingOverlay.landingTimeout else {
            pendingOverlay = nil
            return
        }
        guard service.hasLanded(on: pending.landing) else { return }
        pendingOverlay = nil
        overlay.show(pending.landing)
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

private struct PendingOverlay {
    static let landingTimeout: TimeInterval = 1

    let landing: DisplaySpaces
    let requestedAt: Date
}
