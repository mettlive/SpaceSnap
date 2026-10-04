public enum SwitchDirection: Sendable, Equatable, Codable {
    case left
    case right

    var offset: Int {
        switch self {
        case .left: -1
        case .right: 1
        }
    }
}

public enum SwitchTarget: Sendable, Hashable {
    case neighbor(SwitchDirection)
    case desktop(Int)
    case previous
}

public struct SwitchPlan: Sendable, Equatable {
    public let direction: SwitchDirection
    public let steps: Int
    public let landing: DisplaySpaces
}

public enum SwitchPlanner {
    public static func plan(
        _ target: SwitchTarget,
        from origin: DisplaySpaces,
        previousSpaceID: SpaceID?
    ) -> SwitchPlan? {
        guard let destination = destinationIndex(of: target, from: origin, previousSpaceID: previousSpaceID),
              destination != origin.currentIndex,
              let landing = origin.moved(to: destination)
        else { return nil }

        let delta = destination - origin.currentIndex
        return SwitchPlan(direction: delta > 0 ? .right : .left, steps: abs(delta), landing: landing)
    }

    private static func destinationIndex(
        of target: SwitchTarget,
        from origin: DisplaySpaces,
        previousSpaceID: SpaceID?
    ) -> Int? {
        switch target {
        case .neighbor(let direction):
            origin.currentIndex + direction.offset
        case .desktop(let number):
            origin.indexOfDesktop(number: number)
        case .previous:
            previousSpaceID.flatMap(origin.index(of:))
        }
    }
}
