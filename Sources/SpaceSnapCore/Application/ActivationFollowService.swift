import Foundation

@MainActor
public final class ActivationFollowService {
    private let locator: AppWindowLocator
    private let switcher: SpaceSwitchService
    private let landingQuietPeriod: TimeInterval
    private let now: () -> Date
    private var lastSpaceChange: Date = .distantPast

    public init(
        locator: AppWindowLocator,
        switcher: SpaceSwitchService,
        landingQuietPeriod: TimeInterval,
        now: @escaping () -> Date = Date.init
    ) {
        self.locator = locator
        self.switcher = switcher
        self.landingQuietPeriod = landingQuietPeriod
        self.now = now
    }

    public func spaceDidChange() {
        lastSpaceChange = now()
    }

    public func appDidActivate(processID: pid_t) -> DisplaySpaces? {
        guard now().timeIntervalSince(lastSpaceChange) >= landingQuietPeriod else { return nil }
        return switcher.followWindows(in: locator.windowSpaces(ownedBy: processID))
    }
}
