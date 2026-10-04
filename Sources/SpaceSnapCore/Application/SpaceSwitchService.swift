import Foundation

@MainActor
public final class SpaceSwitchService {
    private let repository: SpaceRepository
    private let emitter: SpaceGestureEmitter
    private let now: () -> Date
    private var prediction: LandingPrediction
    private var history = SpaceHistory()

    public init(
        repository: SpaceRepository,
        emitter: SpaceGestureEmitter,
        predictionWindow: TimeInterval,
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.emitter = emitter
        self.prediction = LandingPrediction(window: predictionWindow)
        self.now = now
    }

    @discardableResult
    public func perform(_ target: SwitchTarget) -> DisplaySpaces? {
        guard let observed = repository.spacesUnderCursor() else {
            if case .neighbor(let direction) = target {
                emitter.emit(direction, steps: 1)
            }
            return nil
        }
        let origin = prediction.resolve(observed, at: now())
        guard let plan = SwitchPlanner.plan(
            target,
            from: origin,
            previousSpaceID: history.previousSpace(on: origin.displayID)
        ) else { return nil }

        emitter.emit(plan.direction, steps: plan.steps)
        prediction.record(plan.landing, at: now())
        history.observe([origin, plan.landing])
        return plan.landing
    }

    public func hasLanded(on landing: DisplaySpaces) -> Bool {
        repository.allDisplays().contains {
            $0.displayID == landing.displayID && $0.currentSpace.id == landing.currentSpace.id
        }
    }

    public func recordSettledSpaces() {
        history.observe(repository.allDisplays())
    }

    public func activeDisplaySpaces() -> DisplaySpaces? {
        repository.spacesOfActiveDisplay()
    }
}
