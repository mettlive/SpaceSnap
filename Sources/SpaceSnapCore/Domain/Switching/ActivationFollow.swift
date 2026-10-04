public enum ActivationFollow {
    public static func targetSpace(windowSpaces: [SpaceID], displays: [DisplaySpaces]) -> SpaceID? {
        let visibleSpaces = Set(displays.map(\.currentSpace.id))
        guard !windowSpaces.contains(where: visibleSpaces.contains) else { return nil }
        return windowSpaces.first { spaceID in displays.contains { $0.index(of: spaceID) != nil } }
    }
}
