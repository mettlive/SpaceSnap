public struct SwipeTracker: Sendable {
    public enum Phase: Sendable, Equatable {
        case began
        case changed
        case ended
        case cancelled
    }

    public struct Decision: Sendable, Equatable {
        public let shouldPass: Bool
        public let firedDirection: SwitchDirection?
        public let neutralizeEvent: Bool

        public init(shouldPass: Bool, firedDirection: SwitchDirection? = nil, neutralizeEvent: Bool = false) {
            self.shouldPass = shouldPass
            self.firedDirection = firedDirection
            self.neutralizeEvent = neutralizeEvent
        }
    }

    public private(set) var isTracking = false
    private var hasFired = false

    public init() {}

    public mutating func handle(phase: Phase?, magnitude: Double, neutralizesOnEnded: Bool) -> Decision {
        switch phase {
        case .began:
            isTracking = true
            hasFired = false
            return Decision(shouldPass: false)
        case .changed:
            let direction = fireIfPending(magnitude: magnitude)
            return Decision(shouldPass: !isTracking, firedDirection: direction)
        case .ended:
            let wasTracking = isTracking
            let direction = fireIfPending(magnitude: magnitude)
            reset()
            guard wasTracking else {
                return Decision(shouldPass: true, firedDirection: direction)
            }
            guard neutralizesOnEnded else {
                return Decision(shouldPass: false, firedDirection: direction)
            }
            return Decision(shouldPass: true, firedDirection: direction, neutralizeEvent: true)
        case .cancelled:
            reset()
            return Decision(shouldPass: false)
        case nil:
            return Decision(shouldPass: !isTracking)
        }
    }

    public mutating func reset() {
        isTracking = false
        hasFired = false
    }

    private mutating func fireIfPending(magnitude: Double) -> SwitchDirection? {
        guard isTracking, !hasFired, magnitude != 0 else { return nil }
        hasFired = true
        return magnitude > 0 ? .right : .left
    }
}
