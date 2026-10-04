import Foundation
import Testing
@testable import SpaceSnapCore

@MainActor
private final class StubRepository: SpaceRepository {
    var display: DisplaySpaces?
    var otherDisplays: [DisplaySpaces] = []

    init(_ display: DisplaySpaces?) {
        self.display = display
    }

    func allDisplays() -> [DisplaySpaces] { (display.map { [$0] } ?? []) + otherDisplays }
    func spacesUnderCursor() -> DisplaySpaces? { display }
    func spacesOfActiveDisplay() -> DisplaySpaces? { display }
}

@MainActor
private final class RecordingEmitter: SpaceGestureEmitter {
    private(set) var emitted: [(SwitchDirection, Int)] = []
    private(set) var displays: [String?] = []

    func emit(_ direction: SwitchDirection, steps: Int, onDisplay displayID: String?) {
        emitted.append((direction, steps))
        displays.append(displayID)
    }
}

@MainActor
private final class StubWindowLocator: AppWindowLocator {
    var spaces: [SpaceID] = []

    func windowSpaces(ownedBy processID: pid_t) -> [SpaceID] { spaces }
}

@MainActor
@Suite struct SpaceSwitchServiceTests {
    @Test func rapidPressesAdvanceFromPredictionInsteadOfStaleState() {
        let repository = StubRepository(makeDisplay([.desktop, .desktop, .desktop], current: 0))
        let emitter = RecordingEmitter()
        let service = SpaceSwitchService(repository: repository, emitter: emitter, predictionWindow: 1, now: { .distantPast })

        service.perform(.neighbor(.right))
        service.perform(.neighbor(.right))
        let third = service.perform(.neighbor(.right))

        #expect(emitter.emitted.count == 2)
        #expect(third == nil)
    }

    @Test func previousReturnsToLastSettledSpace() throws {
        let repository = StubRepository(makeDisplay([.desktop, .desktop, .desktop], current: 0))
        let emitter = RecordingEmitter()
        let service = SpaceSwitchService(repository: repository, emitter: emitter, predictionWindow: 0)
        service.recordSettledSpaces()
        repository.display = makeDisplay([.desktop, .desktop, .desktop], current: 2)
        service.recordSettledSpaces()

        let landing = try #require(service.perform(.previous))

        #expect(landing.currentIndex == 0)
        #expect(emitter.emitted.first?.0 == .left)
        #expect(emitter.emitted.first?.1 == 2)
    }

    @Test func rapidPreviousTogglesBackBeforeSpacesSettle() throws {
        let repository = StubRepository(makeDisplay([.desktop, .desktop, .desktop], current: 0))
        let emitter = RecordingEmitter()
        let service = SpaceSwitchService(repository: repository, emitter: emitter, predictionWindow: 1, now: { .distantPast })
        service.recordSettledSpaces()
        repository.display = makeDisplay([.desktop, .desktop, .desktop], current: 2)
        service.recordSettledSpaces()

        let first = try #require(service.perform(.previous))
        let second = try #require(service.perform(.previous))

        #expect(first.currentIndex == 0)
        #expect(second.currentIndex == 2)
    }

    @Test func landingIsReachedOnlyWhenTargetDisplayShowsTargetSpace() throws {
        let repository = StubRepository(makeDisplay([.desktop, .fullscreen, .desktop], current: 1))
        let service = SpaceSwitchService(repository: repository, emitter: RecordingEmitter(), predictionWindow: 0)
        let landing = try #require(service.perform(.neighbor(.left)))

        #expect(!service.hasLanded(on: landing))
        repository.display = makeDisplay([.desktop, .fullscreen, .desktop], current: 0, displayID: "B")
        #expect(!service.hasLanded(on: landing))
        repository.display = makeDisplay([.desktop, .fullscreen, .desktop], current: 0)
        #expect(service.hasLanded(on: landing))
    }

    @Test func unknownSpacesStillSwitchNeighborButNotJumps() {
        let emitter = RecordingEmitter()
        let service = SpaceSwitchService(repository: StubRepository(nil), emitter: emitter, predictionWindow: 0)

        service.perform(.desktop(2))
        service.perform(.neighbor(.left))

        #expect(emitter.emitted.count == 1)
        #expect(emitter.emitted.first?.0 == .left)
    }
}

@MainActor
@Suite struct ActivationFollowServiceTests {
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    private func makeFixture(now: @escaping () -> Date) -> (StubRepository, RecordingEmitter, StubWindowLocator, ActivationFollowService) {
        let repository = StubRepository(makeDisplay([.desktop, .fullscreen, .desktop], current: 0, displayID: "A"))
        repository.otherDisplays = [
            DisplaySpaces(displayID: "B", spaces: [Space(id: 10, kind: .desktop), Space(id: 11, kind: .desktop)], currentSpaceID: 10)!,
        ]
        let emitter = RecordingEmitter()
        let locator = StubWindowLocator()
        let switcher = SpaceSwitchService(repository: repository, emitter: emitter, predictionWindow: 0, now: now)
        let follower = ActivationFollowService(locator: locator, switcher: switcher, landingQuietPeriod: 0.5, now: now)
        return (repository, emitter, locator, follower)
    }

    @Test func switchesOnTheDisplayOwningTheFrontmostWindowSpace() throws {
        let (_, emitter, locator, follower) = makeFixture { .distantFuture }
        locator.spaces = [11, 3]

        let landing = try #require(follower.appDidActivate(processID: 1))

        #expect(landing.displayID == "B")
        #expect(landing.currentSpace.id == 11)
        #expect(emitter.displays == ["B"])
    }

    @Test func staysWhenAppAlreadyHasWindowOnAVisibleSpace() {
        let (_, emitter, locator, follower) = makeFixture { .distantFuture }
        locator.spaces = [3, 10]

        #expect(follower.appDidActivate(processID: 1) == nil)
        #expect(emitter.emitted.isEmpty)
    }

    @Test func ignoresActivationsRightAfterLandingAndUnknownSpaces() {
        var current = start
        let (_, emitter, locator, follower) = makeFixture { current }
        locator.spaces = [3]

        follower.spaceDidChange()
        current = start.addingTimeInterval(0.3)
        #expect(follower.appDidActivate(processID: 1) == nil)

        locator.spaces = [999]
        current = start.addingTimeInterval(1)
        #expect(follower.appDidActivate(processID: 1) == nil)

        locator.spaces = [3]
        #expect(follower.appDidActivate(processID: 1)?.currentSpace.id == 3)
        #expect(emitter.emitted.count == 1)
    }
}

@MainActor
private final class FakeShortcutController: SystemShortcutController {
    var shortcuts: [Int32: SystemShortcut]

    init(_ shortcuts: [SystemShortcut]) {
        self.shortcuts = Dictionary(uniqueKeysWithValues: shortcuts.map { ($0.id, $0) })
    }

    func spaceShortcuts() -> [SystemShortcut] { Array(shortcuts.values) }

    func setEnabled(_ enabled: Bool, shortcutID: Int32) {
        guard let shortcut = shortcuts[shortcutID] else { return }
        shortcuts[shortcutID] = SystemShortcut(id: shortcutID, combo: shortcut.combo, isEnabled: enabled)
    }
}

@MainActor
@Suite struct SystemShortcutCoordinatorTests {
    private let controlLeft = KeyCombo(keyCode: KeyCode.leftArrow, modifiers: .control)
    private let controlRight = KeyCombo(keyCode: KeyCode.rightArrow, modifiers: .control)
    private let controlOne = KeyCombo(keyCode: KeyCode.desktopDigits[0], modifiers: .control)

    private func makeController() -> FakeShortcutController {
        FakeShortcutController([
            SystemShortcut(id: 79, combo: controlLeft, isEnabled: true),
            SystemShortcut(id: 81, combo: controlRight, isEnabled: true),
            SystemShortcut(id: 118, combo: controlOne, isEnabled: false),
        ])
    }

    @Test func disablesOnlyEnabledConflictsAndRestoresWhenBindingMovesAway() {
        let controller = makeController()
        let coordinator = SystemShortcutCoordinator(controller: controller)

        coordinator.reconcile(with: [controlLeft, controlOne])
        #expect(controller.shortcuts[79]?.isEnabled == false)
        #expect(controller.shortcuts[81]?.isEnabled == true)

        coordinator.reconcile(with: [controlOne])
        #expect(controller.shortcuts[79]?.isEnabled == true)
        #expect(controller.shortcuts[118]?.isEnabled == false)
    }

    @Test func restoreReenablesOnlyWhatAppDisabled() {
        let controller = makeController()
        let coordinator = SystemShortcutCoordinator(controller: controller)
        coordinator.reconcile(with: [controlLeft, controlRight, controlOne])

        coordinator.restore()

        #expect(controller.shortcuts[79]?.isEnabled == true)
        #expect(controller.shortcuts[81]?.isEnabled == true)
        #expect(controller.shortcuts[118]?.isEnabled == false)
    }
}
