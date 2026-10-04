public struct AppSettings: Sendable, Equatable, Codable {
    public var hotkeys: HotkeyBindings
    public var interceptsTrackpadSwipes: Bool
    public var showsOverlay: Bool
    public var preventsEmptyDesktopYank: Bool
    public var showsSpaceNumberInMenuBar: Bool
    public var followsAppActivationInstantly: Bool

    public init(
        hotkeys: HotkeyBindings,
        interceptsTrackpadSwipes: Bool,
        showsOverlay: Bool,
        preventsEmptyDesktopYank: Bool,
        showsSpaceNumberInMenuBar: Bool,
        followsAppActivationInstantly: Bool
    ) {
        self.hotkeys = hotkeys
        self.interceptsTrackpadSwipes = interceptsTrackpadSwipes
        self.showsOverlay = showsOverlay
        self.preventsEmptyDesktopYank = preventsEmptyDesktopYank
        self.showsSpaceNumberInMenuBar = showsSpaceNumberInMenuBar
        self.followsAppActivationInstantly = followsAppActivationInstantly
    }

    public static let `default` = AppSettings(
        hotkeys: .default,
        interceptsTrackpadSwipes: true,
        showsOverlay: true,
        preventsEmptyDesktopYank: true,
        showsSpaceNumberInMenuBar: true,
        followsAppActivationInstantly: false
    )

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = AppSettings.default
        hotkeys = try container.decodeIfPresent(HotkeyBindings.self, forKey: .hotkeys) ?? fallback.hotkeys
        interceptsTrackpadSwipes = try container.decodeIfPresent(Bool.self, forKey: .interceptsTrackpadSwipes)
            ?? fallback.interceptsTrackpadSwipes
        showsOverlay = try container.decodeIfPresent(Bool.self, forKey: .showsOverlay) ?? fallback.showsOverlay
        preventsEmptyDesktopYank = try container.decodeIfPresent(Bool.self, forKey: .preventsEmptyDesktopYank)
            ?? fallback.preventsEmptyDesktopYank
        showsSpaceNumberInMenuBar = try container.decodeIfPresent(Bool.self, forKey: .showsSpaceNumberInMenuBar)
            ?? fallback.showsSpaceNumberInMenuBar
        followsAppActivationInstantly = try container.decodeIfPresent(Bool.self, forKey: .followsAppActivationInstantly)
            ?? fallback.followsAppActivationInstantly
    }
}
