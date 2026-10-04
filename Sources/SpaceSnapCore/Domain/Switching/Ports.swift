@MainActor
public protocol SpaceRepository: AnyObject {
    func allDisplays() -> [DisplaySpaces]
    func spacesUnderCursor() -> DisplaySpaces?
    func spacesOfActiveDisplay() -> DisplaySpaces?
}

@MainActor
public protocol SpaceGestureEmitter: AnyObject {
    func emit(_ direction: SwitchDirection, steps: Int)
}
