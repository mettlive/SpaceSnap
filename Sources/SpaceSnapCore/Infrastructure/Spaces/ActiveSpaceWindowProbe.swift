@MainActor
public final class ActiveSpaceWindowProbe {
    public init() {}

    public func activeSpaceHasWindows() -> Bool {
        let activeSpaceID = SLSGetActiveSpace(SLSMainConnectionID())
        let windowIDs = SkyLightWindowSpaces.windows(options: [.excludeDesktopElements])
            .filter { $0.layer == 0 }
            .map(\.id)
        return SkyLightWindowSpaces.spaces(of: windowIDs).contains(activeSpaceID)
    }
}
