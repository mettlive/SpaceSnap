import AppKit

@MainActor
public final class CGWindowAppWindowLocator: AppWindowLocator {
    private static let allSpacesMask: Int32 = 0x7
    private let connection = SLSMainConnectionID()

    public init() {}

    public func windowSpaces(ownedBy processID: pid_t) -> [SpaceID] {
        let windows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        return windows
            .filter { isVisibleAppWindow($0, ownedBy: processID) }
            .compactMap { $0[kCGWindowNumber as String] as? UInt32 }
            .flatMap(spaces(of:))
    }

    private func isVisibleAppWindow(_ window: [String: Any], ownedBy processID: pid_t) -> Bool {
        (window[kCGWindowOwnerPID as String] as? pid_t) == processID
            && (window[kCGWindowLayer as String] as? Int) == 0
            && (window[kCGWindowAlpha as String] as? Double ?? 0) > 0
    }

    private func spaces(of windowID: UInt32) -> [SpaceID] {
        let spaces = SLSCopySpacesForWindows(connection, Self.allSpacesMask, [windowID] as CFArray)?
            .takeRetainedValue() as? [NSNumber]
        return spaces?.map(\.uint64Value) ?? []
    }
}
