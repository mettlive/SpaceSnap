import AppKit

@MainActor
public enum DisplayLocator {
    public static func screen(forDisplayID displayID: String) -> NSScreen? {
        NSScreen.screens.first { uuid(of: $0) == displayID } ?? screenUnderCursor()
    }

    static func displayIDUnderCursor() -> String? {
        guard let location = CGEvent(source: nil)?.location else { return nil }
        var displayID = CGDirectDisplayID()
        var matched: UInt32 = 0
        guard CGGetDisplaysWithPoint(location, 1, &displayID, &matched) == .success, matched > 0 else {
            return nil
        }
        return uuid(of: displayID)
    }

    static func bounds(ofDisplayID displayID: String) -> CGRect? {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return nil }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else { return nil }
        return displays.first { uuid(of: $0) == displayID }.map(CGDisplayBounds)
    }

    private static func screenUnderCursor() -> NSScreen? {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(location, $0.frame, false) } ?? NSScreen.main
    }

    private static func uuid(of screen: NSScreen) -> String? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else { return nil }
        return uuid(of: CGDirectDisplayID(number.uint32Value))
    }

    private static func uuid(of displayID: CGDirectDisplayID) -> String? {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }
}
