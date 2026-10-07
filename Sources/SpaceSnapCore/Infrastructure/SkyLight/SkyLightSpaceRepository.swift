import AppKit

@MainActor
public final class SkyLightSpaceRepository: SpaceRepository {
    private let connection = SLSMainConnectionID()

    public init() {}

    public func allDisplays() -> [DisplaySpaces] {
        let activeSpaceID = SLSGetActiveSpace(connection)
        return managedDisplays().compactMap { parse($0, activeSpaceID: activeSpaceID) }
    }

    public func spacesUnderCursor() -> DisplaySpaces? {
        let displays = allDisplays()
        guard displays.count > 1, let cursorDisplayID = DisplayLocator.displayIDUnderCursor() else {
            return displays.first
        }
        return displays.first { $0.displayID == cursorDisplayID } ?? displays.first
    }

    public func spacesOfActiveDisplay() -> DisplaySpaces? {
        let activeSpaceID = SLSGetActiveSpace(connection)
        let displays = allDisplays()
        return displays.first { $0.currentSpace.id == activeSpaceID } ?? displays.first
    }

    private func managedDisplays() -> [[String: Any]] {
        SLSCopyManagedDisplaySpaces(connection)?.takeRetainedValue() as? [[String: Any]] ?? []
    }

    private func parse(_ display: [String: Any], activeSpaceID: SpaceID) -> DisplaySpaces? {
        guard let displayID = display["Display Identifier"] as? String,
              let rawSpaces = display["Spaces"] as? [[String: Any]]
        else { return nil }

        let spaces = rawSpaces.compactMap(parseSpace)
        let reportedCurrent = ((display["Current Space"] as? [String: Any])?["id64"] as? NSNumber)?.uint64Value
        let currentSpaceID = spaces.contains { $0.id == activeSpaceID } ? activeSpaceID : reportedCurrent
        guard let currentSpaceID else { return nil }
        return DisplaySpaces(displayID: displayID, spaces: spaces, currentSpaceID: currentSpaceID)
    }

    private func parseSpace(_ raw: [String: Any]) -> Space? {
        guard let id = (raw["id64"] as? NSNumber)?.uint64Value else { return nil }
        guard (raw["type"] as? NSNumber)?.intValue == Self.fullscreenSpaceType else {
            return Space(id: id, kind: .desktop)
        }
        return Space(id: id, kind: .fullscreen, ownerProcessID: (raw["pid"] as? NSNumber)?.int32Value)
    }

    private static let fullscreenSpaceType = 4
}
