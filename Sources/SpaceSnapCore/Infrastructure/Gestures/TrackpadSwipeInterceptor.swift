import CoreGraphics
import Foundation

@MainActor
public final class TrackpadSwipeInterceptor {
    private let onSwipe: @MainActor (SwitchDirection) -> Void
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var watchdog: Timer?
    private var tracker = SwipeTracker()

    public init(onSwipe: @escaping @MainActor (SwitchDirection) -> Void) {
        self.onSwipe = onSwipe
    }

    isolated deinit {
        uninstall()
    }

    public func setEnabled(_ enabled: Bool) -> Bool {
        guard enabled else {
            uninstall()
            return true
        }
        return tap != nil || install()
    }

    private func install() -> Bool {
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let interceptor = Unmanaged<TrackpadSwipeInterceptor>.fromOpaque(userInfo).takeUnretainedValue()
            let passes = MainActor.assumeIsolated { interceptor.shouldPass(type: type, event: event) }
            return passes ? Unmanaged.passUnretained(event) : nil
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: DockSwipeEvent.tapMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        watchdog = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reenableIfDisabled() }
        }
        return true
    }

    private func uninstall() {
        watchdog?.invalidate()
        watchdog = nil
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        source = nil
        tracker.reset()
    }

    private func reenableIfDisabled() {
        guard let tap, !CGEvent.tapIsEnabled(tap: tap) else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func shouldPass(type: CGEventType, event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            tracker.reset()
            reenableIfDisabled()
            return true
        }
        if event.getIntegerValueField(.eventSourceUserData) == DockSwipeEvent.appTag {
            return true
        }
        let eventType = event.getIntegerValueField(DockSwipeEvent.eventType)
        if eventType == DockSwipeEvent.dockControlEventType, isHorizontalDockSwipe(event) {
            return applySwipePhase(event)
        }
        return !(eventType == DockSwipeEvent.gestureEventType && tracker.isTracking)
    }

    private func isHorizontalDockSwipe(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(DockSwipeEvent.hidType) == DockSwipeEvent.dockSwipeHIDType
            && event.getIntegerValueField(DockSwipeEvent.swipeMotion) == DockSwipeEvent.horizontalMotion
    }

    private func applySwipePhase(_ event: CGEvent) -> Bool {
        let phase = DockSwipeEvent.Phase(rawValue: event.getIntegerValueField(DockSwipeEvent.phase))
        let magnitudeField = phase == .ended ? DockSwipeEvent.swipeVelocityX : DockSwipeEvent.swipeProgress
        let decision = tracker.handle(
            phase: Self.trackerPhase(phase),
            magnitude: event.getDoubleValueField(magnitudeField),
            neutralizesOnEnded: DockSwipeEvent.requiresIOHIDPayload
        )
        if let direction = decision.firedDirection {
            onSwipe(direction)
        }
        if decision.neutralizeEvent {
            event.setDoubleValueField(DockSwipeEvent.swipeVelocityX, value: 0)
            event.setDoubleValueField(DockSwipeEvent.swipeVelocityY, value: 0)
            event.setDoubleValueField(DockSwipeEvent.swipeProgress, value: 0)
        }
        return decision.shouldPass
    }

    private static func trackerPhase(_ phase: DockSwipeEvent.Phase?) -> SwipeTracker.Phase? {
        switch phase {
        case .began: .began
        case .changed: .changed
        case .ended: .ended
        case .cancelled: .cancelled
        case nil: nil
        }
    }
}
