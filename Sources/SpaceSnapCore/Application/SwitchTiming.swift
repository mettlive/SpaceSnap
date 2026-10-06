public struct SwitchTiming: Sendable {
    public let settleDelay: Duration
    public let landingTimeout: Duration
    public let landingPollInterval: Duration

    public init(settleDelay: Duration, landingTimeout: Duration, landingPollInterval: Duration) {
        self.settleDelay = settleDelay
        self.landingTimeout = landingTimeout
        self.landingPollInterval = landingPollInterval
    }

    public static let standard = SwitchTiming(
        settleDelay: .milliseconds(200),
        landingTimeout: .seconds(1),
        landingPollInterval: .milliseconds(4)
    )

    var landingPollCount: Int {
        Int((landingTimeout / landingPollInterval).rounded(.up))
    }
}
