import Testing
@testable import SpaceSnapCore

@Suite struct SwipeTrackerTests {
    @Test func fullGestureFiresOnceInRightDirection() {
        var tracker = SwipeTracker()

        let began = tracker.handle(phase: .began, magnitude: 0, neutralizesOnEnded: false)
        #expect(began.shouldPass == false)
        #expect(began.firedDirection == nil)

        let changed = tracker.handle(phase: .changed, magnitude: 0.5, neutralizesOnEnded: false)
        #expect(changed.shouldPass == false)
        #expect(changed.firedDirection == .right)

        let repeatedChanged = tracker.handle(phase: .changed, magnitude: 0.6, neutralizesOnEnded: false)
        #expect(repeatedChanged.firedDirection == nil)

        let ended = tracker.handle(phase: .ended, magnitude: 0, neutralizesOnEnded: false)
        #expect(ended.shouldPass == false)
        #expect(ended.firedDirection == nil)
        #expect(ended.neutralizeEvent == false)
    }

    @Test func fullGestureFiresLeftOnNegativeMagnitude() {
        var tracker = SwipeTracker()
        _ = tracker.handle(phase: .began, magnitude: 0, neutralizesOnEnded: false)

        let changed = tracker.handle(phase: .changed, magnitude: -0.5, neutralizesOnEnded: false)
        #expect(changed.firedDirection == .left)
    }

    @Test func cancelledGestureNeverFires() {
        var tracker = SwipeTracker()
        _ = tracker.handle(phase: .began, magnitude: 0, neutralizesOnEnded: false)

        let cancelled = tracker.handle(phase: .cancelled, magnitude: 0.5, neutralizesOnEnded: false)
        #expect(cancelled.shouldPass == false)
        #expect(cancelled.firedDirection == nil)
        #expect(tracker.isTracking == false)
    }

    @Test func secondGestureFiresAgainAfterFirstEnds() {
        var tracker = SwipeTracker()
        _ = tracker.handle(phase: .began, magnitude: 0, neutralizesOnEnded: false)
        _ = tracker.handle(phase: .changed, magnitude: 0.5, neutralizesOnEnded: false)
        _ = tracker.handle(phase: .ended, magnitude: 0, neutralizesOnEnded: false)

        _ = tracker.handle(phase: .began, magnitude: 0, neutralizesOnEnded: false)
        let secondChanged = tracker.handle(phase: .changed, magnitude: -0.3, neutralizesOnEnded: false)

        #expect(secondChanged.firedDirection == .left)
    }

    @Test func endedPhaseIsNeutralizedWhenRequired() {
        var tracker = SwipeTracker()
        _ = tracker.handle(phase: .began, magnitude: 0, neutralizesOnEnded: true)
        _ = tracker.handle(phase: .changed, magnitude: 0.5, neutralizesOnEnded: true)

        let ended = tracker.handle(phase: .ended, magnitude: 9999, neutralizesOnEnded: true)

        #expect(ended.shouldPass == true)
        #expect(ended.neutralizeEvent == true)
        #expect(ended.firedDirection == nil)
    }

    @Test func untrackedEndedPassesWithoutNeutralizing() {
        var tracker = SwipeTracker()

        let ended = tracker.handle(phase: .ended, magnitude: 9999, neutralizesOnEnded: true)

        #expect(ended.shouldPass == true)
        #expect(ended.neutralizeEvent == false)
    }

    @Test func untrackedChangedPassesThrough() {
        var tracker = SwipeTracker()

        let changed = tracker.handle(phase: .changed, magnitude: 0.5, neutralizesOnEnded: false)

        #expect(changed.shouldPass == true)
        #expect(changed.firedDirection == nil)
    }

    @Test func nilPhasePassesWhenNotTracking() {
        var tracker = SwipeTracker()

        let decision = tracker.handle(phase: nil, magnitude: 0, neutralizesOnEnded: false)

        #expect(decision.shouldPass == true)
    }

    @Test func nilPhaseSwallowedWhileTracking() {
        var tracker = SwipeTracker()
        _ = tracker.handle(phase: .began, magnitude: 0, neutralizesOnEnded: false)

        let decision = tracker.handle(phase: nil, magnitude: 0, neutralizesOnEnded: false)

        #expect(decision.shouldPass == false)
    }
}
