import AppKit

@MainActor
public final class CGWindowAppWindowLocator: AppWindowLocator {
    public init() {}

    public func windowSpaces(ownedBy processID: pid_t) -> [SpaceID] {
        SkyLightWindowSpaces.windows(options: [.optionAll, .excludeDesktopElements])
            .filter { isVisibleAppWindow($0, ownedBy: processID) }
            .flatMap { SkyLightWindowSpaces.spaces(of: [$0.id]) }
    }

    private func isVisibleAppWindow(_ window: SkyLightWindowInfo, ownedBy processID: pid_t) -> Bool {
        window.ownerPID == processID && window.layer == 0 && window.alpha > 0
    }
}
