public struct SpaceHistory: Sendable {
    private var current: [String: SpaceID] = [:]
    private var previous: [String: SpaceID] = [:]

    public init() {}

    public mutating func observe(_ displays: [DisplaySpaces]) {
        for display in displays {
            let spaceID = display.currentSpace.id
            if let known = current[display.displayID], known != spaceID {
                previous[display.displayID] = known
            }
            current[display.displayID] = spaceID
        }
    }

    public func previousSpace(on displayID: String) -> SpaceID? {
        previous[displayID]
    }
}
