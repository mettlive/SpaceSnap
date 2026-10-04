import AppKit

@MainActor
public final class EmptyDesktopGuard {
    private static let allSpacesMask: Int32 = 0x7
    private let connection = SLSMainConnectionID()

    public init() {}

    public func handleSpaceChange() {
        guard !activeSpaceHasWindows() else { return }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func activeSpaceHasWindows() -> Bool {
        let activeSpaceID = SLSGetActiveSpace(connection)
        let windows = CGWindowListCopyWindowInfo([.excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let windowIDs = windows.compactMap { window -> UInt32? in
            guard (window[kCGWindowLayer as String] as? Int) == 0 else { return nil }
            return window[kCGWindowNumber as String] as? UInt32
        }
        guard !windowIDs.isEmpty,
              let spaces = SLSCopySpacesForWindows(connection, Self.allSpacesMask, windowIDs as CFArray)?
                .takeRetainedValue() as? [NSNumber]
        else { return false }
        return spaces.contains { $0.uint64Value == activeSpaceID }
    }
}
