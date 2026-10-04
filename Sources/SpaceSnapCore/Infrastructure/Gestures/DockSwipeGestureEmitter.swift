import CoreGraphics
import Foundation

@MainActor
public final class DockSwipeGestureEmitter: SpaceGestureEmitter {
    public static let predictionWindow: TimeInterval = DockSwipeEvent.requiresIOHIDPayload ? 0.4 : 0.25

    private static let progressMagnitude = 1e-4
    private static let velocityPerStep = 2000.0
    private static let flingVelocity = 9999.0
    private static let phases: [DockSwipeEvent.Phase] = [.began, .changed, .ended]

    private let cursorRouter = CursorRouter()

    public init() {}

    public func emit(_ direction: SwitchDirection, steps: Int, onDisplay displayID: String?) {
        guard steps > 0 else { return }
        cursorRouter.route(toDisplay: displayID) {
            for _ in 0..<steps {
                if DockSwipeEvent.requiresIOHIDPayload {
                    postValidatedSwipe(direction)
                } else {
                    postBareSwipe(direction, velocity: Self.velocityPerStep * Double(steps))
                }
            }
        }
    }

    private func postBareSwipe(_ direction: SwitchDirection, velocity: Double) {
        let sign = Double(direction.offset)
        for phase in Self.phases {
            guard let event = CGEvent(source: nil) else { return }
            event.setIntegerValueField(DockSwipeEvent.eventType, value: DockSwipeEvent.dockControlEventType)
            event.setIntegerValueField(DockSwipeEvent.hidType, value: DockSwipeEvent.dockSwipeHIDType)
            event.setIntegerValueField(DockSwipeEvent.phase, value: phase.rawValue)
            event.setDoubleValueField(DockSwipeEvent.swipeProgress, value: Self.progressMagnitude * sign)
            event.setIntegerValueField(DockSwipeEvent.swipeMotion, value: DockSwipeEvent.horizontalMotion)
            event.setDoubleValueField(DockSwipeEvent.swipeVelocityX, value: velocity * sign)
            event.setDoubleValueField(DockSwipeEvent.swipeVelocityY, value: velocity * sign)
            event.setIntegerValueField(.eventSourceUserData, value: DockSwipeEvent.appTag)
            event.post(tap: .cgSessionEventTap)
        }
    }

    private func postValidatedSwipe(_ direction: SwitchDirection) {
        let sign = -Double(direction.offset) * naturalScrollingSign()
        var events: [CGEvent] = []
        for phase in Self.phases {
            guard let dockEvent = validatedDockEvent(phase, sign: sign),
                  let event = IOHIDSwipePayload.attach(to: dockEvent)
            else { return }
            event.setIntegerValueField(.eventSourceUserData, value: DockSwipeEvent.appTag)
            events.append(event)
        }
        for event in events {
            guard let companion = CGEvent(source: nil) else { return }
            companion.setIntegerValueField(.eventSourceUserData, value: DockSwipeEvent.appTag)
            companion.setIntegerValueField(DockSwipeEvent.eventType, value: DockSwipeEvent.gestureEventType)
            event.post(tap: .cgSessionEventTap)
            companion.post(tap: .cgSessionEventTap)
        }
    }

    private func validatedDockEvent(_ phase: DockSwipeEvent.Phase, sign: Double) -> CGEvent? {
        guard let event = CGEvent(source: nil) else { return nil }
        event.setIntegerValueField(DockSwipeEvent.eventType, value: DockSwipeEvent.dockControlEventType)
        event.setIntegerValueField(DockSwipeEvent.hidType, value: DockSwipeEvent.dockSwipeHIDType)
        event.setIntegerValueField(DockSwipeEvent.phase, value: phase.rawValue)
        event.setDoubleValueField(DockSwipeEvent.swipeProgress, value: Self.progressMagnitude * sign)
        event.setIntegerValueField(DockSwipeEvent.swipeMotion, value: DockSwipeEvent.horizontalMotion)
        event.setDoubleValueField(DockSwipeEvent.swipePositionX, value: 0.1)
        if phase == .ended {
            event.setDoubleValueField(DockSwipeEvent.swipeVelocityX, value: Self.flingVelocity * sign)
        }
        return event
    }

    private func naturalScrollingSign() -> Double {
        let key = "com.apple.swipescrolldirection" as CFString
        let natural = CFPreferencesCopyAppValue(key, kCFPreferencesAnyApplication) as? Bool ?? true
        return natural ? 1 : -1
    }
}
