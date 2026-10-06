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
    private(set) var requestedProcesses: [pid_t] = []

    func windowSpaces(ownedBy processID: pid_t) -> [SpaceID] {
        requestedProcesses.append(processID)
        return spaces
    }
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

    @Test func previousReturnsToSpaceSettledAfterChange() async throws {
        let repository = StubRepository(makeDisplay([.desktop, .desktop, .desktop], current: 0))
        let emitter = RecordingEmitter()
        let service = SpaceSwitchService(repository: repository, emitter: emitter, predictionWindow: 0, sleep: { _ in })
        service.recordSettledSpaces()
        repository.display = makeDisplay([.desktop, .desktop, .desktop], current: 2)
        await service.spaceDidChange().value

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

    @Test func landingWaitStopsAsSoonAsTargetIsShown() async throws {
        let repository = StubRepository(makeDisplay([.desktop, .desktop], current: 0))
        var polls = 0
        let service = SpaceSwitchService(
            repository: repository,
            emitter: RecordingEmitter(),
            predictionWindow: 0,
            sleep: { _ in
                polls += 1
                if polls == 3 { repository.display = makeDisplay([.desktop, .desktop], current: 1) }
            }
        )
        let landing = try #require(service.perform(.neighbor(.right)))

        #expect(await service.waitForLanding(on: landing))
        #expect(polls == 3)
    }

    @Test func landingWaitGivesUpAfterTimeout() async throws {
        let repository = StubRepository(makeDisplay([.desktop, .desktop], current: 0))
        var polls = 0
        let timing = SwitchTiming(settleDelay: .zero, landingTimeout: .milliseconds(10), landingPollInterval: .milliseconds(4))
        let service = SpaceSwitchService(
            repository: repository,
            emitter: RecordingEmitter(),
            predictionWindow: 0,
            timing: timing,
            sleep: { _ in polls += 1 }
        )
        let landing = try #require(service.perform(.neighbor(.right)))

        #expect(await service.waitForLanding(on: landing) == false)
        #expect(polls == 3)
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
    private let ownProcessID: pid_t = 42

    @MainActor
    private final class FollowLog {
        var currentTime = Date(timeIntervalSinceReferenceDate: 0)
        var landings: [DisplaySpaces] = []
    }

    @MainActor
    private struct Fixture {
        let emitter = RecordingEmitter()
        let locator = StubWindowLocator()
        let log = FollowLog()
        let follower: ActivationFollowService

        init(ownProcessID: pid_t) {
            let repository = StubRepository(makeDisplay([.desktop, .fullscreen, .desktop], current: 0, displayID: "A"))
            repository.otherDisplays = [
                DisplaySpaces(displayID: "B", spaces: [Space(id: 10, kind: .desktop), Space(id: 11, kind: .desktop)], currentSpaceID: 10)!,
            ]
            let log = log
            let now = { log.currentTime }
            let switcher = SpaceSwitchService(repository: repository, emitter: emitter, predictionWindow: 0, now: now)
            follower = ActivationFollowService(
                locator: locator,
                switcher: switcher,
                ownProcessID: ownProcessID,
                landingQuietPeriod: 0.5,
                activationDelay: .zero,
                now: now,
                sleep: { _ in }
            ) { landing in
                log.landings.append(landing)
            }
        }

        func activate(_ processID: pid_t) async {
            await follower.appDidActivate(processID: processID)?.value
        }
    }

    @Test func switchesOnTheDisplayOwningTheFrontmostWindowSpace() async throws {
        let fixture = Fixture(ownProcessID: ownProcessID)
        fixture.locator.spaces = [11, 3]

        await fixture.activate(1)

        let landing = try #require(fixture.log.landings.first)
        #expect(landing.displayID == "B")
        #expect(landing.currentSpace.id == 11)
        #expect(fixture.emitter.displays == ["B"])
    }

    @Test func staysWhenAppAlreadyHasWindowOnAVisibleSpace() async {
        let fixture = Fixture(ownProcessID: ownProcessID)
        fixture.locator.spaces = [3, 10]

        await fixture.activate(1)

        #expect(fixture.log.landings.isEmpty)
        #expect(fixture.emitter.emitted.isEmpty)
    }

    @Test func windowListedOnSeveralHiddenSpacesIsChasedToItsFirstSpace() async {
        let fixture = Fixture(ownProcessID: ownProcessID)
        fixture.locator.spaces = [11, 2]

        await fixture.activate(1)

        #expect(fixture.log.landings.map(\.currentSpace.id) == [11])
    }

    @Test func ignoresActivationsRightAfterLandingAndUnknownSpaces() async {
        let fixture = Fixture(ownProcessID: ownProcessID)
        fixture.locator.spaces = [3]

        fixture.follower.spaceDidChange()
        fixture.log.currentTime.addTimeInterval(0.3)
        await fixture.activate(1)
        #expect(fixture.log.landings.isEmpty)

        fixture.locator.spaces = [999]
        fixture.log.currentTime.addTimeInterval(0.7)
        await fixture.activate(1)
        #expect(fixture.log.landings.isEmpty)

        fixture.locator.spaces = [3]
        await fixture.activate(1)
        #expect(fixture.log.landings.map(\.currentSpace.id) == [3])
        #expect(fixture.emitter.emitted.count == 1)
    }

    @Test func spaceChangeDuringActivationDelayCancelsFollow() async {
        let fixture = Fixture(ownProcessID: ownProcessID)
        fixture.locator.spaces = [3]

        let pending = fixture.follower.appDidActivate(processID: 1)
        fixture.follower.spaceDidChange()
        fixture.log.currentTime.addTimeInterval(10)
        await pending?.value

        #expect(fixture.log.landings.isEmpty)
        #expect(fixture.locator.requestedProcesses.isEmpty)
    }

    @Test func laterActivationReplacesPendingFollow() async {
        let fixture = Fixture(ownProcessID: ownProcessID)
        fixture.locator.spaces = [3]

        let first = fixture.follower.appDidActivate(processID: 1)
        await fixture.activate(2)
        await first?.value

        #expect(fixture.locator.requestedProcesses == [2])
        #expect(fixture.log.landings.count == 1)
    }

    @Test func ownActivationNeverFollows() async {
        let fixture = Fixture(ownProcessID: ownProcessID)
        fixture.locator.spaces = [3]

        await fixture.activate(ownProcessID)

        #expect(fixture.locator.requestedProcesses.isEmpty)
        #expect(fixture.log.landings.isEmpty)
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

@MainActor
private final class FakeHotkeyRegistry: HotkeyRegistry {
    var occupied: Set<KeyCombo> = []
    private(set) var registered: [KeyCombo: SwitchTarget] = [:]

    func register(_ actions: [KeyCombo: SwitchTarget]) -> Set<KeyCombo> {
        registered = actions.filter { !occupied.contains($0.key) }
        return Set(actions.keys).intersection(occupied)
    }

    func unregisterAll() {
        registered = [:]
    }
}

@MainActor
@Suite struct HotkeyServiceTests {
    private let controlLeft = KeyCombo(keyCode: KeyCode.leftArrow, modifiers: .control)
    private let controlRight = KeyCombo(keyCode: KeyCode.rightArrow, modifiers: .control)
    private let optionLeft = KeyCombo(keyCode: KeyCode.leftArrow, modifiers: .option)

    private func bindings(left: KeyCombo?) -> HotkeyBindings {
        HotkeyBindings(left: left, right: controlRight, previous: nil, desktopModifiers: nil)
    }

    private func makeService() -> (FakeHotkeyRegistry, FakeShortcutController, HotkeyService) {
        let registry = FakeHotkeyRegistry()
        let controller = FakeShortcutController([
            SystemShortcut(id: 79, combo: controlLeft, isEnabled: true),
            SystemShortcut(id: 81, combo: controlRight, isEnabled: true),
        ])
        let service = HotkeyService(registry: registry, systemShortcuts: SystemShortcutCoordinator(controller: controller))
        return (registry, controller, service)
    }

    @Test func comboTakenByAnotherAppKeepsItsSystemShortcut() {
        let (registry, controller, service) = makeService()
        registry.occupied = [controlLeft]

        service.apply(bindings(left: controlLeft))

        #expect(service.unavailableCombos == [controlLeft])
        #expect(controller.shortcuts[79]?.isEnabled == true)
        #expect(controller.shortcuts[81]?.isEnabled == false)
    }

    @Test func recordingSuspendsHotkeysUntilLastRecorderStops() {
        let (registry, controller, service) = makeService()
        service.apply(bindings(left: controlLeft))

        service.suspend()
        service.suspend()
        service.apply(bindings(left: optionLeft))
        #expect(registry.registered.isEmpty)
        #expect(controller.shortcuts[79]?.isEnabled == false)

        service.resume()
        #expect(registry.registered.isEmpty)

        service.resume()
        #expect(registry.registered[optionLeft] == .neighbor(.left))
        #expect(registry.registered[controlLeft] == nil)
        #expect(controller.shortcuts[79]?.isEnabled == true)
    }

    @Test func unbalancedResumeDoesNotReregisterWhileSuspended() {
        let (registry, _, service) = makeService()
        service.apply(bindings(left: controlLeft))

        service.resume()
        service.suspend()

        #expect(registry.registered.isEmpty)
    }
}
