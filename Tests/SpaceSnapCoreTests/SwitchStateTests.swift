import Foundation
import Testing
@testable import SpaceSnapCore

@Suite struct LandingPredictionTests {
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    @Test func predictedLandingOverridesStaleObservationWithinWindow() {
        var prediction = LandingPrediction(window: 0.25)
        let observed = makeDisplay([.desktop, .desktop, .desktop], current: 0)
        prediction.record(observed.moved(to: 1)!, at: start)

        #expect(prediction.resolve(observed, at: start.addingTimeInterval(0.1)).currentIndex == 1)
        #expect(prediction.resolve(observed, at: start.addingTimeInterval(0.25)).currentIndex == 0)
    }

    @Test func predictionIgnoredForOtherDisplayOrChangedSpaceList() {
        var prediction = LandingPrediction(window: 1)
        let observed = makeDisplay([.desktop, .desktop, .desktop], current: 0)
        prediction.record(observed.moved(to: 2)!, at: start)

        let otherDisplay = makeDisplay([.desktop, .desktop, .desktop], current: 0, displayID: "B")
        let reshaped = makeDisplay([.desktop, .desktop, .desktop, .desktop], current: 0)

        #expect(prediction.resolve(otherDisplay, at: start) == otherDisplay)
        #expect(prediction.resolve(reshaped, at: start) == reshaped)
    }
}

@Suite struct SpaceHistoryTests {
    @Test func remembersPreviousSpacePerDisplay() {
        var history = SpaceHistory()
        history.observe([makeDisplay([.desktop, .desktop, .desktop], current: 0)])
        #expect(history.previousSpace(on: "A") == nil)

        history.observe([makeDisplay([.desktop, .desktop, .desktop], current: 2)])
        history.observe([makeDisplay([.desktop, .desktop, .desktop], current: 2)])

        #expect(history.previousSpace(on: "A") == 1)
        #expect(history.previousSpace(on: "B") == nil)
    }
}

@Suite struct HotkeyBindingsTests {
    @Test func explicitBindingsWinOverDesktopDigitsAndEarlierWinsOnDuplicates() {
        let digitOne = KeyCombo(keyCode: KeyCode.desktopDigits[0], modifiers: .control)
        let bindings = HotkeyBindings(left: digitOne, right: digitOne, previous: nil, desktopModifiers: .control)

        let actions = bindings.actions()

        #expect(actions[digitOne] == .neighbor(.left))
        #expect(actions[KeyCombo(keyCode: KeyCode.desktopDigits[9], modifiers: .control)] == .desktop(10))
        #expect(actions.count == 10)
    }

    @Test func emptyDesktopModifiersDisableDigitBindings() {
        let bindings = HotkeyBindings(left: nil, right: nil, previous: nil, desktopModifiers: [])

        #expect(bindings.actions().isEmpty)
    }
}

@Suite struct AppSettingsTests {
    @Test func decodingSettingsSavedBeforeANewOptionKeepsStoredValues() throws {
        let legacy = #"{"showsOverlay":false,"interceptsTrackpadSwipes":false}"#

        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(legacy.utf8))

        #expect(settings.showsOverlay == false)
        #expect(settings.interceptsTrackpadSwipes == false)
        #expect(settings.followsAppActivationInstantly == AppSettings.default.followsAppActivationInstantly)
        #expect(settings.hotkeys == .default)
    }
}
