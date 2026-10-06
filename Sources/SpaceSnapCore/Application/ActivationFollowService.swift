import Foundation

@MainActor
public final class ActivationFollowService {
    private let locator: AppWindowLocator
    private let switcher: SpaceSwitchService
    private let ownProcessID: pid_t
    private let landingQuietPeriod: TimeInterval
    private let activationDelay: Duration
    private let now: () -> Date
    private let sleep: Sleep
    private let onLanding: @MainActor (DisplaySpaces) -> Void
    private var lastSpaceChange: Date = .distantPast
    private var pendingFollow: Task<Void, Never>?

    public init(
        locator: AppWindowLocator,
        switcher: SpaceSwitchService,
        ownProcessID: pid_t,
        landingQuietPeriod: TimeInterval,
        activationDelay: Duration,
        now: @escaping () -> Date = Date.init,
        sleep: @escaping Sleep = { try await Task.sleep(for: $0) },
        onLanding: @escaping @MainActor (DisplaySpaces) -> Void
    ) {
        self.locator = locator
        self.switcher = switcher
        self.ownProcessID = ownProcessID
        self.landingQuietPeriod = landingQuietPeriod
        self.activationDelay = activationDelay
        self.now = now
        self.sleep = sleep
        self.onLanding = onLanding
    }

    public func spaceDidChange() {
        lastSpaceChange = now()
        cancelPendingFollow()
    }

    @discardableResult
    public func appDidActivate(processID: pid_t) -> Task<Void, Never>? {
        cancelPendingFollow()
        guard processID != ownProcessID else { return nil }
        let follow = Task { [weak self, sleep, activationDelay] in
            guard (try? await sleep(activationDelay)) != nil, !Task.isCancelled,
                  let landing = self?.follow(processID)
            else { return }
            self?.onLanding(landing)
        }
        pendingFollow = follow
        return follow
    }

    public func cancelPendingFollow() {
        pendingFollow?.cancel()
        pendingFollow = nil
    }

    private func follow(_ processID: pid_t) -> DisplaySpaces? {
        guard now().timeIntervalSince(lastSpaceChange) >= landingQuietPeriod else { return nil }
        return switcher.followWindows(in: locator.windowSpaces(ownedBy: processID))
    }
}
