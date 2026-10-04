import CoreGraphics
import Foundation

enum DockSwipeEvent {
    static let eventType = field(55)
    static let hidType = field(110)
    static let swipeMask = field(115)
    static let swipeMotion = field(123)
    static let swipeProgress = field(124)
    static let swipePositionX = field(125)
    static let swipePositionY = field(126)
    static let swipeVelocityX = field(129)
    static let swipeVelocityY = field(130)
    static let phase = field(132)

    static let gestureEventType: Int64 = 29
    static let dockControlEventType: Int64 = 30
    static let dockSwipeHIDType: Int64 = 23
    static let horizontalMotion: Int64 = 1

    static let appTag: Int64 = 0x5350_534E

    static let tapMask: CGEventMask = (1 << CGEventMask(gestureEventType)) | (1 << CGEventMask(dockControlEventType))

    static let requiresIOHIDPayload = ProcessInfo.processInfo.isOperatingSystemAtLeast(
        OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0)
    )

    enum Phase: Int64 {
        case began = 1
        case changed = 2
        case ended = 4
        case cancelled = 8
    }

    private static func field(_ rawValue: UInt32) -> CGEventField {
        unsafeBitCast(rawValue, to: CGEventField.self)
    }
}
