import AppKit

struct SkyLightWindowInfo: Sendable {
    let id: UInt32
    let ownerPID: pid_t
    let alpha: Double
    let layer: Int
}

enum SkyLightWindowSpaces {
    private static let allSpacesMask: Int32 = 0x7

    static func windows(options: CGWindowListOption) -> [SkyLightWindowInfo] {
        let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        return raw.compactMap(parse)
    }

    static func spaces(of windowIDs: [UInt32]) -> [SpaceID] {
        guard !windowIDs.isEmpty,
              let spaces = SLSCopySpacesForWindows(SLSMainConnectionID(), allSpacesMask, windowIDs as CFArray)?
                  .takeRetainedValue() as? [NSNumber]
        else { return [] }
        return spaces.map(\.uint64Value)
    }

    private static func parse(_ window: [String: Any]) -> SkyLightWindowInfo? {
        guard let id = window[kCGWindowNumber as String] as? UInt32,
              let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
              let layer = window[kCGWindowLayer as String] as? Int
        else { return nil }
        let alpha = window[kCGWindowAlpha as String] as? Double ?? 0
        return SkyLightWindowInfo(id: id, ownerPID: ownerPID, alpha: alpha, layer: layer)
    }
}
