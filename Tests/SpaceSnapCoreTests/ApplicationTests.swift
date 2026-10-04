import Foundation
import Testing
@testable import SpaceSnapCore

@MainActor
private final class StubRepository: SpaceRepository {
    var display: DisplaySpaces?

    init(_ display: DisplaySpaces?) {
        self.display = display
    }

    func allDisplays() -> [DisplaySpaces] { display.map { [$0] } ?? [] }
    func spacesUnderCursor() -> DisplaySpaces? { display }
    func spacesOfActiveDisplay() -> DisplaySpaces? { display }
}

@MainActor
private final class RecordingEmitter: SpaceGestureEmitter {
    private(set) var emitted: [(SwitchDirection, Int)] = []

    func emit(_ direction: SwitchDirection, steps: Int) {
        emitted.append((direction, steps))
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
