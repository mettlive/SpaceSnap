import Foundation

public struct LandingPrediction: Sendable {
    private let window: TimeInterval
    private var landing: DisplaySpaces?
    private var recordedAt: Date = .distantPast

    public init(window: TimeInterval) {
        self.window = window
    }

    public mutating func record(_ landing: DisplaySpaces, at date: Date) {
        self.landing = landing
        recordedAt = date
    }

    public func resolve(_ observed: DisplaySpaces, at date: Date) -> DisplaySpaces {
        guard let landing,
              landing.displayID == observed.displayID,
              landing.spaces == observed.spaces,
              date.timeIntervalSince(recordedAt) < window
        else { return observed }
        return landing
    }
}
