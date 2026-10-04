import Darwin

@MainActor
public protocol SpaceRepository: AnyObject {
    func allDisplays() -> [DisplaySpaces]
    func spacesUnderCursor() -> DisplaySpaces?
    func spacesOfActiveDisplay() -> DisplaySpaces?
}

@MainActor
public protocol SpaceGestureEmitter: AnyObject {
    func emit(_ direction: SwitchDirection, steps: Int, onDisplay displayID: String?)
}

@MainActor
public protocol AppWindowLocator: AnyObject {
    func windowSpaces(ownedBy processID: pid_t) -> [SpaceID]
}
