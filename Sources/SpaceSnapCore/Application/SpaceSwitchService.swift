import Foundation

@MainActor
public final class SpaceSwitchService {
    private let repository: SpaceRepository
    private let emitter: SpaceGestureEmitter
    private let now: () -> Date
    private let timing: SwitchTiming
    private let sleep: Sleep
    private var prediction: LandingPrediction
    private var history = SpaceHistory()
    private var pendingSettle: Task<Void, Never>?

    public init(
        repository: SpaceRepository,
        emitter: SpaceGestureEmitter,
        predictionWindow: TimeInterval,
        timing: SwitchTiming = .standard,
        now: @escaping () -> Date = Date.init,
        sleep: @escaping Sleep = { try await Task.sleep(for: $0) }
    ) {
        self.repository = repository
        self.emitter = emitter
        self.prediction = LandingPrediction(window: predictionWindow)
        self.timing = timing
        self.now = now
        self.sleep = sleep
    }

    @discardableResult
    public func perform(_ target: SwitchTarget) -> DisplaySpaces? {
        guard let observed = observedOrigin(for: target) else {
            if case .neighbor(let direction) = target {
                emitter.emit(direction, steps: 1, onDisplay: nil)
            }
            return nil
        }
        let origin = prediction.resolve(observed, at: now())
        guard let plan = SwitchPlanner.plan(
            target,
            from: origin,
            previousSpaceID: history.previousSpace(on: origin.displayID)
        ) else { return nil }

        emitter.emit(plan.direction, steps: plan.steps, onDisplay: origin.displayID)
        prediction.record(plan.landing, at: now())
        history.observe([origin, plan.landing])
        return plan.landing
    }

    public func followWindows(in windowSpaces: [SpaceID]) -> DisplaySpaces? {
        guard let spaceID = ActivationFollow.targetSpace(
            windowSpaces: windowSpaces,
            displays: repository.allDisplays()
        ) else { return nil }
        return perform(.space(spaceID))
    }

    public func hasLanded(on landing: DisplaySpaces) -> Bool {
        repository.allDisplays().contains {
            $0.displayID == landing.displayID && $0.currentSpace.id == landing.currentSpace.id
        }
    }

    public func waitForLanding(on landing: DisplaySpaces) async -> Bool {
        for _ in 0..<timing.landingPollCount {
            guard !Task.isCancelled else { return false }
            if hasLanded(on: landing) { return true }
            guard (try? await sleep(timing.landingPollInterval)) != nil else { return false }
        }
        return false
    }

    public func recordSettledSpaces() {
        history.observe(repository.allDisplays())
    }

    @discardableResult
    public func spaceDidChange() -> Task<Void, Never> {
        pendingSettle?.cancel()
        let settle = Task { [weak self, sleep, timing] in
            guard (try? await sleep(timing.settleDelay)) != nil, !Task.isCancelled else { return }
            self?.recordSettledSpaces()
        }
        pendingSettle = settle
        return settle
    }

    public func activeDisplaySpaces() -> DisplaySpaces? {
        repository.spacesOfActiveDisplay()
    }

    private func observedOrigin(for target: SwitchTarget) -> DisplaySpaces? {
        guard case .space(let spaceID) = target else { return repository.spacesUnderCursor() }
        return repository.allDisplays().first { $0.index(of: spaceID) != nil }
    }
}
