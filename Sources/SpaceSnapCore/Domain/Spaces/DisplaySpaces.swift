public typealias SpaceID = UInt64

public struct Space: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case desktop
        case fullscreen
    }

    public let id: SpaceID
    public let kind: Kind

    public init(id: SpaceID, kind: Kind) {
        self.id = id
        self.kind = kind
    }
}

public struct DisplaySpaces: Sendable, Equatable {
    public let displayID: String
    public let spaces: [Space]
    public let currentIndex: Int

    public init?(displayID: String, spaces: [Space], currentSpaceID: SpaceID) {
        guard let index = spaces.firstIndex(where: { $0.id == currentSpaceID }) else { return nil }
        self.init(displayID: displayID, spaces: spaces, currentIndex: index)
    }

    private init(displayID: String, spaces: [Space], currentIndex: Int) {
        self.displayID = displayID
        self.spaces = spaces
        self.currentIndex = currentIndex
    }

    public var currentSpace: Space {
        spaces[currentIndex]
    }

    public var currentDesktopNumber: Int? {
        desktopNumber(at: currentIndex)
    }

    public var desktopCount: Int {
        spaces.lazy.filter { $0.kind == .desktop }.count
    }

    public func index(of spaceID: SpaceID) -> Int? {
        spaces.firstIndex { $0.id == spaceID }
    }

    public func indexOfDesktop(number: Int) -> Int? {
        guard number >= 1 else { return nil }
        return spaces.indices.filter { spaces[$0].kind == .desktop }.dropFirst(number - 1).first
    }

    public func desktopNumber(at index: Int) -> Int? {
        guard spaces.indices.contains(index), spaces[index].kind == .desktop else { return nil }
        return spaces[...index].lazy.filter { $0.kind == .desktop }.count
    }

    public func moved(to index: Int) -> DisplaySpaces? {
        guard spaces.indices.contains(index) else { return nil }
        return DisplaySpaces(displayID: displayID, spaces: spaces, currentIndex: index)
    }
}
