import Testing
@testable import SpaceSnapCore

func makeDisplay(_ kinds: [Space.Kind], current: Int, displayID: String = "A") -> DisplaySpaces {
    let spaces = kinds.enumerated().map { Space(id: SpaceID($0.offset + 1), kind: $0.element) }
    return DisplaySpaces(displayID: displayID, spaces: spaces, currentSpaceID: SpaceID(current + 1))!
}

@Suite struct DisplaySpacesTests {
    @Test func desktopNumberingSkipsFullscreenSpaces() {
        let display = makeDisplay([.desktop, .fullscreen, .desktop, .desktop], current: 2)

        #expect(display.currentDesktopNumber == 2)
        #expect(display.desktopNumber(at: 1) == nil)
        #expect(display.indexOfDesktop(number: 3) == 3)
        #expect(display.indexOfDesktop(number: 4) == nil)
        #expect(display.indexOfDesktop(number: 0) == nil)
    }

    @Test func rejectsCurrentSpaceOutsideList() {
        #expect(DisplaySpaces(displayID: "A", spaces: [Space(id: 1, kind: .desktop)], currentSpaceID: 9) == nil)
    }
}

@Suite struct SwitchPlannerTests {
    @Test func neighborIsClampedAtEdges() {
        let first = makeDisplay([.desktop, .desktop], current: 0)
        let last = makeDisplay([.desktop, .desktop], current: 1)

        #expect(SwitchPlanner.plan(.neighbor(.left), from: first, previousSpaceID: nil) == nil)
        #expect(SwitchPlanner.plan(.neighbor(.right), from: last, previousSpaceID: nil) == nil)
    }

    @Test func neighborTraversesFullscreenSpaces() throws {
        let display = makeDisplay([.desktop, .fullscreen, .desktop], current: 0)

        let plan = try #require(SwitchPlanner.plan(.neighbor(.right), from: display, previousSpaceID: nil))

        #expect(plan.direction == .right)
        #expect(plan.steps == 1)
        #expect(plan.landing.currentSpace.kind == .fullscreen)
    }

    @Test func desktopJumpCountsStepsAcrossFullscreenSpaces() throws {
        let display = makeDisplay([.desktop, .fullscreen, .desktop, .desktop], current: 3)

        let plan = try #require(SwitchPlanner.plan(.desktop(1), from: display, previousSpaceID: nil))

        #expect(plan.direction == .left)
        #expect(plan.steps == 3)
        #expect(plan.landing.currentIndex == 0)
    }

    @Test func jumpToCurrentOrMissingDesktopDoesNothing() {
        let display = makeDisplay([.desktop, .desktop], current: 1)

        #expect(SwitchPlanner.plan(.desktop(2), from: display, previousSpaceID: nil) == nil)
        #expect(SwitchPlanner.plan(.desktop(5), from: display, previousSpaceID: nil) == nil)
    }

    @Test func previousTargetsRememberedSpaceOrNothingWhenGone() throws {
        let display = makeDisplay([.desktop, .desktop, .desktop], current: 0)

        let plan = try #require(SwitchPlanner.plan(.previous, from: display, previousSpaceID: 3))

        #expect(plan.steps == 2)
        #expect(plan.direction == .right)
        #expect(SwitchPlanner.plan(.previous, from: display, previousSpaceID: 42) == nil)
        #expect(SwitchPlanner.plan(.previous, from: display, previousSpaceID: nil) == nil)
    }
}
