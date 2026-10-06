import AppKit
import Observation
import SpaceSnapCore

@MainActor
@Observable
final class AppModel {
    var settings: AppSettings {
        didSet { settingsDidChange(from: oldValue) }
    }

    private(set) var activeSpaces: DisplaySpaces?
    private(set) var isAccessibilityGranted: Bool
    private(set) var needsRelaunch = false
    private(set) var unavailableCombos: Set<KeyCombo> = []

    private let settingsStore: SettingsStore
    private let service: SpaceSwitchService
    private let dockFollowPreference = DockSpaceFollowPreference()
    private let windowProbe = ActiveSpaceWindowProbe()
    private let overlay = SpaceOverlayController()

    @ObservationIgnored
    private var overlayTask: Task<Void, Never>?

    @ObservationIgnored
    private var workspaceObserver: WorkspaceEventObserver?

    @ObservationIgnored
    private lazy var interceptor = TrackpadSwipeInterceptor { [weak self] direction in
        self?.handle(.neighbor(direction))
    }

    @ObservationIgnored
    private lazy var hotkeys = HotkeyService(
        registry: CarbonHotkeyRegistry { [weak self] target in
            self?.handle(target)
        },
        systemShortcuts: SystemShortcutCoordinator(controller: SkyLightSystemShortcutController())
    )

    @ObservationIgnored
    private lazy var followService = ActivationFollowService(
        locator: CGWindowAppWindowLocator(),
        switcher: service,
        ownProcessID: ProcessInfo.processInfo.processIdentifier,
        landingQuietPeriod: 0.5,
        activationDelay: .milliseconds(80)
    ) { [weak self] landing in
        self?.present(landing)
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
    }

    func start() {
        service.recordSettledSpaces()
        refreshActiveSpaces()
        workspaceObserver = WorkspaceEventObserver(
            onSpaceChange: { [weak self] in self?.spaceDidChange() },
            onAppActivation: { [weak self] processID in self?.appDidActivate(processID: processID) }
        )
        isAccessibilityGranted = AccessibilityPermission.isGranted
        applySystemIntegration()
        guard !isAccessibilityGranted else { return }
        AccessibilityPermission.requestPrompt()
        pollAccessibility()
    }

    func handle(_ target: SwitchTarget) {
        guard let landing = service.perform(target) else { return }
        present(landing)
    }

    func setHotkeysSuspended(_ suspended: Bool) {
        if suspended {
            hotkeys.suspend()
        } else {
            hotkeys.resume()
        }
        unavailableCombos = hotkeys.unavailableCombos
    }

    func restoreSystemState() {
        hotkeys.restore()
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

    private var followsAppActivation: Bool {
        settings.followsAppActivationInstantly
            && isAccessibilityGranted
            && DockSpaceFollowPreference.switchesToAppSpaceOnActivation
    }

    private func pollAccessibility() {
        Task { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                if AccessibilityPermission.isGranted {
                    self.isAccessibilityGranted = true
                    self.applySystemIntegration()
                    return
                }
            }
        }
    }

    private func settingsDidChange(from oldSettings: AppSettings) {
        guard settings != oldSettings else { return }
        settingsStore.save(settings)
        if settings.followsAppActivationInstantly != oldSettings.followsAppActivationInstantly {
            applyDockFollow()
        }
        if settings.hotkeys != oldSettings.hotkeys {
            applyHotkeys()
        }
        if settings.interceptsTrackpadSwipes != oldSettings.interceptsTrackpadSwipes {
            applyInterceptor()
        }
    }

    private func applySystemIntegration() {
        applyDockFollow()
        applyHotkeys()
        applyInterceptor()
    }

    private func applyDockFollow() {
        if settings.followsAppActivationInstantly && isAccessibilityGranted {
            dockFollowPreference.suppress()
        } else {
            dockFollowPreference.restore()
        }
    }

    private func applyHotkeys() {
        guard isAccessibilityGranted else { return }
        hotkeys.apply(settings.hotkeys)
        unavailableCombos = hotkeys.unavailableCombos
    }

    private func applyInterceptor() {
        guard isAccessibilityGranted else { return }
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
        overlayTask?.cancel()
        guard settings.showsOverlay else { return }
        overlayTask = Task { [weak self, service] in
            guard await service.waitForLanding(on: landing) else { return }
            self?.overlay.show(landing)
        }
    }

    private func appDidActivate(processID: pid_t?) {
        refreshActiveSpaces()
        guard let processID, followsAppActivation else {
            followService.cancelPendingFollow()
            return
        }
        followService.appDidActivate(processID: processID)
    }

    private func spaceDidChange() {
        if settings.preventsEmptyDesktopYank, !windowProbe.activeSpaceHasWindows() {
            NSApp.activate(ignoringOtherApps: true)
        }
        refreshActiveSpaces()
        followService.spaceDidChange()
        service.spaceDidChange()
    }
}
